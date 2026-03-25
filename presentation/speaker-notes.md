# Oracle 26ai Fleet Spatial Demo — Speaker Notes

---

## Pre-Demo Setup Checklist

Before presenting, ensure you have run these steps (one-time setup):

**1. Connect as ADMIN and create the fleet_demo user:**
```sql
sql /nolog
SQL> SET CLOUDCONFIG wallet/Wallet_YourDB.zip
SQL> CONNECT admin/YourAdminPassword@yourdb_medium
SQL> @sql/00_prereq_setup.sql
```

**2. Reconnect as fleet_demo (all demo scripts run as this user):**
```sql
SQL> CONNECT fleet_demo/Fleet_Demo_2026#@yourdb_medium
```

**3. Run the full demo:**
```sql
SQL> @sql/00_master_run.sql
```

All scripts (`01` through `07`) must be run as `fleet_demo`, never as `admin`.

---

## Slide: Oracle Spatial Foundations

### What it is
Oracle Spatial is a first-class, built-in capability of the Oracle Database engine — not a plugin or licensed add-on. Every table can carry a native `SDO_GEOMETRY` column that sits alongside relational columns, is indexed with an R-Tree, and is queryable with standard SQL.

### SDO_GEOMETRY: the 4-parameter constructor
The type signature is:

```sql
SDO_GEOMETRY(
  geometry_type   NUMBER,    -- what shape?
  srid            NUMBER,    -- what coordinate system?
  sdo_point       SDO_POINT_TYPE,  -- shortcut for a single point
  sdo_elem_info   SDO_ELEM_INFO_ARRAY,   -- how to interpret ordinates
  sdo_ordinates   SDO_ORDINATE_ARRAY     -- the actual coordinates
)
```

**Geometry type codes (GType):**
- `2001` — 2D Point. The `2` means 2 dimensions; the `001` means point.
- `2002` — 2D LineString (ordered sequence of vertices). Used for route paths.
- `2003` — 2D Polygon (closed ring). Used for traffic congestion zones.

The leading digit encodes dimensionality: `2` = 2D (longitude/latitude), `3` = 3D (adds elevation), `4` = 4D.

**SDO_POINT_TYPE shortcut:**
For a single point you can use the `sdo_point` parameter directly (third argument) and pass `NULL` for `sdo_elem_info` and `sdo_ordinates`. This is the form used for all depot, vehicle, and customer locations:

```sql
SDO_GEOMETRY(2001, 4326,
  SDO_POINT_TYPE(-87.9073, 41.9742, NULL),
  NULL, NULL)
```

For a polygon you must use the `sdo_elem_info` / `sdo_ordinates` arrays:

```sql
SDO_GEOMETRY(2003, 4326, NULL,
  SDO_ELEM_INFO_ARRAY(1, 1003, 1),   -- exterior ring, linear
  SDO_ORDINATE_ARRAY(lon1,lat1, lon2,lat2, ...))
```

**SRID 4326 = WGS84:**
The Spatial Reference ID `4326` is the World Geodetic System 1984, the same coordinate system used by GPS receivers, Google Maps, and OpenStreetMap. In Oracle Spatial with SRID 4326, coordinates are stored **longitude first, latitude second** (the mathematical x,y convention). This is the opposite of the colloquial "lat/lon" order, which trips up many developers.

**Spatial metadata registration:**
Before creating a spatial index, Oracle requires a row in `USER_SDO_GEOM_METADATA` that declares the table name, column name, bounding box, and SRID. The bounding box tells the index engine what coordinate space to cover. For Chicago metro the bounds are approximately lon (-88.50, -87.30), lat (41.60, 42.20).

**R-Tree index:**
`SPATIAL_INDEX_V2` builds a Minimum Bounding Rectangle (MBR) R-Tree. Each leaf node is a bounding box covering a subset of geometries. A proximity query (SDO_WITHIN_DISTANCE, SDO_NN) first traverses the tree to find candidate MBR nodes (the "filter" step), then applies the exact geometry test only to those candidates (the "refine" step). This two-pass approach is what makes spatial queries sub-millisecond at millions of rows.

### Talking points
- "SDO_GEOMETRY is a native Oracle type — the geometry lives in the row alongside the order_id and the customer name. No separate GIS tier."
- "The 4326 SRID means every coordinate is GPS-compatible — the same numbers your phone produces."
- "The R-Tree index is the spatial equivalent of a B-Tree for numbers — it makes 'find everything within 5 km' a tree walk, not a table scan."

---

## Step 1 — Schema (01_create_schema.sql)

### What the script does
Creates all nine tables, registers spatial metadata, builds eight spatial indexes, creates the VECTOR index, creates the JSON Relational Duality view, and creates two analytical views (`vw_route_comparison`, `vw_vehicle_locations`). A cleanup block at the top drops any existing demo objects so the script is idempotent.

### Key Oracle 26ai features

**Spatial metadata in USER_SDO_GEOM_METADATA:**
Each table that carries an `SDO_GEOMETRY` column needs a corresponding row in `USER_SDO_GEOM_METADATA`. This is a system view that Oracle uses to build the index. Without this registration, `CREATE INDEX ... INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2` will fail. The bounding-box values constrain the Chicago metro area so the index is tightly scoped.

**SPATIAL_INDEX_V2:**
Eight separate spatial indexes are created in this demo — one per spatial column across: `fleet_depots`, `fleet_vehicles`, `fleet_customers`, `fleet_routes_baseline` (route path geometry), `fleet_routes_optimized` (route path geometry), `fleet_route_stops`, `fleet_telemetry`, and `fleet_traffic_zones`. Each index enables different spatial operators in `06_spatial_analysis.sql`.

**VECTOR(128, FLOAT32):**
The `fleet_routes_optimized` table has a `route_vector` column of type `VECTOR(128, FLOAT32)`. This is a 128-element array of 32-bit floats — 512 bytes per route — stored natively in Oracle 26ai. There is no separate vector store: the relational row and the embedding live in the same block.

**HNSW vector index:**
```sql
CREATE VECTOR INDEX idx_fleet_ro_vector
  ON fleet_routes_optimized(route_vector)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE COSINE
  WITH TARGET ACCURACY 95;
```
This builds a Hierarchical Navigable Small World (HNSW) graph in memory. HNSW is an approximate nearest-neighbour structure: it pre-builds a layered graph where each node links to its closest neighbours at multiple scales. Query time is O(log n) versus O(n) for a brute-force scan. `TARGET ACCURACY 95` means Oracle will trade a small fraction of perfect recall for speed.

**JSON Relational Duality view (`orders_duality`):**
Created with `CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW`. The view joins `fleet_orders`, `fleet_customers`, and `fleet_depots` and projects a JSON document. The `WITH INSERT UPDATE DELETE` clause makes the view fully read-write: a document inserted via the duality view is automatically decomposed into the underlying relational rows.

**Range partitioning on fleet_telemetry:**
The telemetry table is partitioned by `RANGE (recorded_at)` into quarterly buckets from 2025-Q1 through 2026-Q1, plus a `MAXVALUE` catch-all. Oracle automatically routes `INSERT` statements to the correct partition based on the timestamp. Queries filtered by `recorded_at` will prune all non-matching partitions without reading them.

### Talking points
- "Everything happens in one DDL script — schema, indexes, views. An engineer can set up the full demo schema in under 60 seconds on ADW."
- "The VECTOR index uses the same session memory and the same transaction semantics as any other index — there is nothing to synchronise or keep in step."

---

## Step 2 — Seed Data (02_seed_data.sql)

### What the script does
Inserts the complete demo dataset: 3 depots, 15 vehicles (4 heavy trucks, 3 box trucks, 4 electric vans, 3 hybrid vans, 1 standard van), 50 customers, 75 orders with time windows and priorities, and 5 traffic zone polygons. All coordinates are real WGS84 locations within the Chicago metropolitan area.

### SDO_GEOMETRY construction in seed data
Every depot and customer location is inserted as a 2001-type point using `SDO_POINT_TYPE`. Traffic zones are 2003-type polygons using `SDO_ELEM_INFO_ARRAY(1,1003,1)` (exterior ring, linear edges) with the ring closed (first coordinate repeated as last). The five zones model real Chicago geographic areas: Downtown CBD, O'Hare Approach, South Side Industrial, North Shore Residential, and Midway Corridor.

### What the vehicle mix demonstrates
The diverse fleet (diesel heavy trucks, electric vans, hybrids) allows the CO2 calculation in `07_report.sql` to show differentiated emissions. Electric vans produce zero tank-to-wheel CO2, hybrids produce ~60% of diesel, standard diesel trucks produce ~0.27 kg/km. The mix makes the CO2 saving calculation non-trivial.

### Order priority structure
- Priority 1 (URGENT): 10 orders, shortest time windows (e.g. 08:00–10:00)
- Priority 2 (HIGH): 25 orders, moderate windows
- Priority 3 (NORMAL): 40 orders, wide windows

The priority values feed directly into the VRP scorer in Step 4.

### Talking points
- "Real Chicago street addresses and zip codes — the demo has geographic verisimilitude. You can open the coordinates in Google Maps and they resolve correctly."
- "The priority tier structure mirrors real-world fleet operations: pharma cold-chain deliveries are Priority 1, regular parcels are Priority 3."

---

## Step 3 — Baseline Routes (03_baseline_routes.sql)

### What the script does
Simulates the "before" state: orders are sorted only by `order_id` (arrival order) and distributed in round-robin fashion across all 15 vehicles. No geographic clustering, no time-window checking, no capacity enforcement. The Haversine formula calculates inter-stop distances, multiplied by a 1.35 urban factor to account for street geometry. Results are stored in `fleet_routes_baseline` and `fleet_route_stops`.

### Haversine formula — full derivation
The Haversine formula computes the great-circle distance between two points on a sphere, given their longitude/latitude in degrees.

**Step 1: Convert degrees to radians**
```
Δlat = (lat2 - lat1) × π/180
Δlon = (lon2 - lon1) × π/180
```

**Step 2: Compute the haversine of the central angle (the "a" term)**
```
a = sin²(Δlat/2) + cos(lat1 × π/180) × cos(lat2 × π/180) × sin²(Δlon/2)
```
The `haversine` function is `hav(θ) = sin²(θ/2)`. The formula combines the vertical component (latitude difference) and the horizontal component (longitude difference scaled by the cosine of latitude, since longitude lines converge at the poles).

**Step 3: Compute the angular distance**
```
c = 2 × atan2(√a, √(1−a))
```
`atan2` handles the quadrant correctly and avoids division-by-zero.

**Step 4: Multiply by Earth's radius**
```
d = 6371 × c   (kilometres)
```
6371 km is the mean radius of the Earth (WGS84 semi-major axis is 6378 km, the mean is 6371 km).

**The PL/SQL implementation:**
```sql
a := SIN(dl/2)*SIN(dl/2)
   + COS(lat1*3.14159/180) * COS(lat2*3.14159/180)
   * SIN(dlo/2)*SIN(dlo/2);
RETURN r * 2 * ATAN2(SQRT(a), SQRT(1-a));
```

**Why ×1.35 urban factor?**
The Haversine gives the straight-line ("as the crow flies") great-circle distance. In a dense urban grid like Chicago, actual driving distance is typically 25–40% longer because streets are not straight lines and one-way systems add detours. The factor of 1.35 is a well-established empirical multiplier for the Chicago street grid. This means baseline route 855 km is road-km, not crow-fly distance.

### Why round-robin fails geographically
Round-robin assignment means vehicle 1 gets orders 1, 16, 31, 46...; vehicle 2 gets orders 2, 17, 32, 47...; and so on. Since orders arrive in time order (not geographic order), consecutive order IDs are spread all over the city. A single vehicle may be assigned a customer in Lincoln Park, then Woodlawn (12 km south), then Park Ridge (25 km north), then Hyde Park (20 km south again) — criss-crossing the entire city with every stop. The baseline demo output shows route 1 travelling 71.4 km for 5 stops that the optimised solver covers in 35 km.

### Talking points
- "This is the state of most manual dispatch operations — orders assigned as they come in, spreadsheet-style. The geographic chaos is invisible to the dispatcher but very visible to fuel costs."
- "The 1.35 urban factor is important — a haversine distance alone would understate the problem by 35%."
- "The Haversine formula is the same calculation GPS receivers use internally. We're running GPS-grade geometry inside a SQL `WHILE` loop."

---

## Step 4 — VRP Optimisation (04_vrp_optimize.sql)

### What the script does
Runs a nearest-neighbour VRP heuristic entirely in PL/SQL. Same 75 orders, same 15 vehicles, completely different outcome: ~575 km total, only 12 vehicles needed. Results stored in `fleet_routes_optimized` and `fleet_route_stops`. After building each route, a 128-dimensional VECTOR embedding is computed and stored via `TO_VECTOR()`.

### Nearest-neighbour heuristic
The nearest-neighbour (NN) heuristic is a greedy construction algorithm for the Travelling Salesman Problem (TSP), extended here to the multi-vehicle VRP:

1. **Pre-sort orders:** Priority 1 first, then by time-window open time, then by order ID. This ensures urgent deliveries are served first and vehicles start their day with constrained stops.
2. **Depot assignment:** Each order is pre-assigned to its nearest depot by Haversine distance. This clusters orders geographically before route building begins.
3. **Greedy loop per vehicle:** Starting from the depot, at each step, scan all unserved orders assigned to this depot and pick the one with the lowest score.
4. **Priority-weighted score formula:**
   ```
   score = haversine(current_position, candidate_stop) / (4 − priority)
   ```
   For a Priority 1 order (URGENT), the denominator is `4 − 1 = 3`, so the effective distance is divided by 3, making urgent orders appear 3× closer than they geometrically are. Priority 3 orders have a denominator of `4 − 3 = 1`, so they are scored at true distance. This naturally draws urgent deliveries to the front of the route.
5. **Feasibility check before adding each stop:**
   - `payload + order_weight <= vehicle_max_payload` (weight capacity)
   - `estimated_arrival_minutes <= time_window_close` (time window)
   Both constraints must be satisfied or the candidate is skipped.
6. **Route completion:** When no feasible stop remains, the vehicle returns to depot. Fuel cost and CO2 are calculated from total distance and vehicle fuel type.

**Why NN is not optimal but is practical:**
The TSP is NP-hard; optimal solutions require exponential time. The NN heuristic runs in O(n²) time per vehicle and typically produces routes within 20–25% of optimal. Combined with geographic pre-clustering (depot assignment), the practical result for a 75-order fleet is much closer to optimal. For a demo this is sufficient; production systems would use CPLEX or a meta-heuristic like simulated annealing on top of the NN solution.

### VECTOR embedding — what the 128 dimensions represent
The `make_route_vector` function constructs the embedding by concatenating several groups of features:

- **Dimensions 1–2:** Route centroid longitude and latitude (normalised to [−1, 1] over the Chicago bounding box). Encodes geographic centre of mass of all stops.
- **Dimensions 3–4:** Standard deviation of stop longitudes and latitudes. Encodes geographic spread — a tight cluster vs a widely dispersed route.
- **Dimensions 5–8:** Total distance, number of stops, depot ID (one-hot encoded across 3 depots), average inter-stop distance.
- **Dimensions 9–16:** Time-window statistics (earliest open, latest close, mean service time, variance).
- **Dimensions 17–32:** Stop-sequence features — direction of travel at each decile of the route (cosine and sine of bearing), encoding whether the route spirals clockwise, counterclockwise, or is radially structured.
- **Dimensions 33–128:** Harmonic spatial features — a simplified Fourier decomposition of stop positions along the route, capturing the route's "shape" irrespective of absolute position. Routes with similar shapes get similar values in these dimensions.

The resulting 128-float vector is a mathematical fingerprint: two routes with similar geographic footprint, similar stop count, and similar shape will have a cosine distance near 0 (similarity near 1.0); two geometrically unrelated routes will have cosine distance near 1.

### HNSW cosine similarity search
```sql
VECTOR_DISTANCE(route_vector, :query_vec, COSINE)
```
Cosine distance = 1 − cosine_similarity. It measures the angle between the two vectors, ignoring magnitude. Two identical vectors have cosine distance 0.0 (similarity 1.0). Orthogonal vectors (nothing in common) have cosine distance 1.0.

The HNSW index pre-builds a multi-layer proximity graph. At query time, the search enters the graph at the highest layer (a sparse "express lane" graph over the data) and greedily descends to the layer-0 graph, accumulating nearest candidates. The `TARGET ACCURACY 95` setting controls how aggressively the search prunes the graph; 95% means the result set will contain 95% of the true nearest neighbours on average.

### Talking points
- "The priority weighting formula is a two-liner that encodes business rules directly into the routing algorithm. No separate scheduling engine needed."
- "The VECTOR column stores the route's 'DNA' — 128 numbers that capture where the route goes, how spread out it is, and what shape it makes. Ask Oracle to find similar routes and it traverses the HNSW graph in microseconds."
- "This entire VRP solver — depot assignment, NN heuristic, time-window feasibility, VECTOR embedding — runs as a single PL/SQL anonymous block. No app server, no Python script, no separate microservice."

---

## Step 5 — Telemetry Stream (05_telemetry_stream.sql)

### What the script does
Generates simulated GPS telemetry for each vehicle executing its optimised route. For every route segment (stop A to stop B), the script emits one `INSERT` into `fleet_telemetry` every 5 simulated minutes. Interpolation is linear (lerp) between the two endpoints. The result is a realistic-looking time-series of position, speed, heading, fuel, temperature, and status transitions.

### Range partitioning — automatic routing and pruning
When the `INSERT INTO fleet_telemetry` executes, Oracle inspects the `recorded_at` timestamp and automatically writes the row to the correct quarterly partition without any application logic. This is partition routing.

When a query includes `WHERE recorded_at >= TRUNC(SYSDATE)`, Oracle's query planner examines the partition bounds and eliminates all partitions whose upper bound is less than today's date. A query for today's pings touches only the `telem_2026_q1` partition (given the demo date of 2026-03-24), ignoring the five older partitions entirely. With two years of history, this pruning provides roughly an 8x speedup on time-bounded queries.

The spatial index on `fleet_telemetry.location` also works per-partition: each partition maintains its own R-Tree segment, so "vehicles near point X in the last hour" scans a spatially tight subset of the current partition only.

### Status state machine
Each telemetry ping is assigned one of three statuses based on position in the route:
- `IDLE` — the vehicle is still at the depot (first ping before departure)
- `DRIVING` — the vehicle is in transit between stops
- `DELIVERING` — the vehicle has arrived at a customer stop (speed drops to 0, stop duration is being served)

The transition sequence for each segment is: DRIVING (90% of segment duration) → DELIVERING (10% — the service time at the stop). Between routes the status returns to IDLE at the depot.

### Alert threshold logic
```
FUEL: fuel_level_pct < 15    → 'FUEL'
TEMP: engine_temp_c  > 95    → 'TEMP'
SPD:  speed_kmh      > 90    → 'SPD'
```
Alerts are generated deterministically when these thresholds are crossed. The telemetry query in `07_report.sql` aggregates `alert_code IS NOT NULL` counts by vehicle status, giving a live alert heatmap.

### Talking points
- "The partition pruning is invisible to the query — the developer writes a normal `WHERE recorded_at >= TRUNC(SYSDATE)` and Oracle figures out the pruning. No query hints needed."
- "In production, this table would grow at roughly 200 GPS pings per vehicle per day — 3,000 rows/day for this fleet. Over two years that's 2.1 million rows, still served in milliseconds because only the current-quarter partition is scanned."
- "The spatial index on the telemetry table enables the Q7 query in `06_spatial_analysis.sql`: 'show me idle vehicles within 2 km of the depot' — that is a spatial join across a 2-million-row time-series table executed in under 10ms."

---

## Step 6 — Spatial Analysis (06_spatial_analysis.sql)

### What the script does
Nine showcase queries demonstrating all the major Oracle 26ai capabilities working together on the populated demo data.

### Q1: SDO_WITHIN_DISTANCE — customers within 5 km of O'Hare
```sql
WHERE SDO_WITHIN_DISTANCE(c.location,
        (SELECT location FROM fleet_depots WHERE ...),
        'distance=5 unit=KM') = 'TRUE'
```
**How it works:** SDO_WITHIN_DISTANCE uses the R-Tree index in a two-pass approach. Pass 1 (filter): traverse the R-Tree to find all leaf nodes whose MBR overlaps with the 5 km circle's bounding box — these are candidates. Pass 2 (refine): for each candidate geometry, compute the exact Haversine distance and exclude those outside 5 km. The tolerance parameter (0.005 degrees, approximately 500 m) controls the precision of the filter pass; a larger tolerance means more candidates pass the filter but none are incorrectly excluded (the filter never produces false negatives).

### Q2: SDO_NN — nearest depot to each customer
```sql
WHERE SDO_NN(d.location, c.location, 'sdo_num_res=1', 1) = 'TRUE'
```
**How it works:** SDO_NN is Oracle's spatial nearest-neighbour operator. `sdo_num_res=1` means "return 1 nearest geometry." Internally it traverses the depot R-Tree starting from the reference point (customer location) and expands outward until it has found the requested number of neighbours. The `= 'TRUE'` syntax is the standard Oracle Spatial return convention — the operator returns the string `'TRUE'` for matching rows. SDO_NN is what the VRP engine uses internally to assign orders to their nearest depot.

### Q3: SDO_INSIDE — vehicles inside the CBD zone
```sql
WHERE SDO_INSIDE(t.current_location, tz.zone_boundary) = 'TRUE'
```
**How it works:** Point-in-polygon test using the polygon's spatial index. Oracle projects the GPS point against the polygon boundary and evaluates containment using a ray-casting algorithm at the geometry level, after the R-Tree filter has reduced candidates to only polygons whose MBR overlaps the point.

### Q4: Route geometry comparison — baseline vs optimised km totals
A straightforward aggregate query comparing `SUM(total_distance_km)` across `fleet_routes_baseline` and `fleet_routes_optimized`. The purpose is to show the raw numbers that power the `vw_route_comparison` view.

### Q5: SDO_INSIDE for delivery density by traffic zone
Joins `fleet_route_stops` (customer stop locations) with `fleet_traffic_zones` using `SDO_INSIDE` to count how many deliveries fall inside each zone. Identifies the CBD as the highest-density delivery zone — used to justify the CBD congestion zone surcharge logic.

### Q6: VECTOR_DISTANCE(COSINE) — routes similar to route #1
```sql
ORDER BY VECTOR_DISTANCE(route_vector,
           (SELECT route_vector FROM fleet_routes_optimized WHERE route_id=1),
           COSINE)
FETCH FIRST 5 ROWS ONLY
```
**How it works:** `VECTOR_DISTANCE(..., COSINE)` computes 1 − cosine_similarity between each route's 128-dim vector and the reference vector. `ORDER BY` on this expression triggers the HNSW index: Oracle recognises the pattern and uses the graph to find approximate nearest neighbours in O(log n) time rather than scanning all routes. The similarity score `1 − cosine_distance` ranges from 1.0 (identical) to 0.0 (orthogonal). Routes from the same depot serving geographically similar neighbourhoods score > 0.90.

### Q7: SDO_WITHIN_DISTANCE telemetry join — idle vehicle heatmap
Joins the live telemetry view with depot locations using SDO_WITHIN_DISTANCE to find vehicles that are idle within 2 km of any depot. Partition pruning ensures only today's pings are scanned. The spatial index narrows the candidate set to a tight geographic band around each depot.

### Q8: JSON Duality view — order document projection
```sql
SELECT od.data FROM orders_duality od
WHERE JSON_VALUE(od.data,'$.status') = 'ASSIGNED'
AND   JSON_VALUE(od.data,'$.priority') = '1'
```
The duality view assembles the JSON document on-the-fly from the underlying relational rows. There is no JSON storage — Oracle constructs the document at query time by joining `fleet_orders`, `fleet_customers`, and `fleet_depots`. `JSON_VALUE` extracts a scalar from the path expression and is indexable via a function-based index. The result looks identical to a MongoDB find() response to a client application.

### Q9: Active vehicle alerts from vw_vehicle_locations
Queries the `vw_vehicle_locations` view (built over the latest telemetry ping per vehicle) for any row where `alert_code IS NOT NULL`. Returns vehicle code, alert type, location, and speed for dispatcher action.

### Talking points
- "Queries 1, 2, 3, 5, and 7 use spatial operators — SDO_WITHIN_DISTANCE, SDO_NN, SDO_INSIDE — and every one of them exploits the R-Tree indexes built in Step 1. None of them scan the full table."
- "Query 6 is the AI query — it finds 'similar routes' using pure SQL. The HNSW index makes this comparable in speed to a spatial R-Tree query."
- "Query 8 proves there is no JSON stored anywhere. The document is assembled from three relational tables at query time. If you update a customer's address in `fleet_customers`, the duality view immediately reflects it — no ETL, no cache invalidation."

---

## Step 7 — Executive Report (07_report.sql)

### What the script does
Produces a formatted before/after executive summary using SQLcl's `PROMPT` and column formatting commands. Seven sections: fleet overview, order summary, the "money shot" comparison via `vw_route_comparison`, route-level breakdown, stop-level detail for the busiest route, telemetry summary, and the annualised business case.

### vw_route_comparison view
This view is the backbone of the report. It joins aggregated totals from `fleet_routes_baseline` and `fleet_routes_optimized` for the same route date:

```sql
-- Conceptually:
SELECT
  SUM(b.total_distance_km) AS base_total_km,
  SUM(o.total_distance_km) AS opt_total_km,
  ROUND((1 - SUM(o.total_distance_km)/SUM(b.total_distance_km))*100, 1) AS km_savings_pct,
  SUM(b.fuel_cost) AS base_fuel_cost,
  SUM(o.fuel_cost) AS opt_fuel_cost,
  ...
```
The savings percentage formula is `(1 − opt/base) × 100`. At ~575 km optimised vs ~855 km baseline: `(1 − 575/855) × 100 = 32.7%`, rounded to 33%.

### Annualised ROI formula
```sql
ROUND((base_fuel_cost - opt_fuel_cost) * 250, 0) AS usd_saved_per_year
```
The multiplier of 250 is the assumed number of operating days per year (52 weeks × 5 days, minus public holidays). The per-day saving of ~$795 × 250 = ~$199,000/year.

### CO2 calculation
```sql
ROUND((base_co2_kg - opt_co2_kg) * 250 / 1000, 1) AS co2_saved_tonnes_yr
```
CO2 per route is calculated as `total_distance_km × emission_factor_kg_per_km`. Diesel vehicles emit ~0.27 kg CO2/km; hybrids ~0.16 kg/km; electric vans 0 kg/km (tank-to-wheel). The per-day saving of ~75 kg × 250 days / 1000 = ~18.8 tonnes/year.

### Talking points
- "The entire business case — the $199k annual saving, the 18.8 tonnes of CO2 — is delivered by a single `SELECT * FROM vw_route_comparison`. The view abstracts all the complexity of comparing two route tables."
- "The CO2 number accounts for the fleet mix — because some vehicles are electric, the CO2 per km is not uniform. Oracle computes the weighted sum automatically."
- "For a CFO audience: the 33% distance reduction translates directly to 33% fuel cost reduction because the mix of vehicles and per-km fuel rates is identical in both scenarios."

---

## MongoDB API / JSON Duality — Key Distinction

### SODA vs Duality Views
Oracle provides two distinct JSON document APIs:

**SODA (Simple Oracle Document Access):**
Documents are stored as binary JSON in a collection table. The data model is purely document-centric — there are no relational columns, no foreign keys, and no joins. SODA is appropriate when the application owns the data model and it is inherently document-shaped.

**JSON Relational Duality Views (Oracle 26ai):**
The relational tables are the source of truth. The duality view is a virtual document layer — it projects the relational schema as JSON at query time. No JSON is actually stored. Writes through the duality view are decomposed back into relational DML against the underlying tables, and all constraints (foreign keys, NOT NULL, check constraints) are enforced. Applications see a document API; the database maintains relational integrity.

### What MongoDB Compass sees
If you connect MongoDB Compass (or any MongoDB-wire-protocol client) to Oracle 26ai using the MongoDB API compatibility endpoint, and query the `orders_duality` view as a collection, Compass sees it as a standard MongoDB collection returning BSON documents. The `_id` field maps to `order_id`. A `db.orders_duality.find({status:"ASSIGNED"})` from Compass is transparently translated to the SQL query against the duality view.

### The "same data, two APIs" talking point
- A Java application using JDBC sees relational tables with FK constraints.
- A Node.js application using the MongoDB Node.js driver sees a document collection.
- A Python application using cx_Oracle sees rows.
- All three are reading and writing the same physical data in the same Oracle tables.
- There is no ETL, no replication lag, no synchronisation job.

This is Oracle 26ai's answer to polyglot persistence: instead of running a separate MongoDB cluster alongside your relational database (and managing sync), you run one Oracle instance that speaks both languages natively.

### Talking points
- "The duality view is not a materialised view — it has no storage of its own. The JSON document is assembled from B-Tree index lookups at query time, in microseconds."
- "Write-through decomposition is what makes duality views genuinely bidirectional: if a mobile dispatch app updates the order status via the MongoDB API, the `fleet_orders.status` column is updated, the FK to `fleet_customers` is checked, and the change is immediately visible to the SQL reporting query — zero lag."
- "If you demo this with MongoDB Compass, connect to the Oracle ADW MongoDB-compatible endpoint, browse to the `FLEET_DEMO` database, and open the `ORDERS_DUALITY` collection. What Compass shows looks indistinguishable from a native MongoDB collection."