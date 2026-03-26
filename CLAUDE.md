# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

An Oracle 26ai Autonomous Data Warehouse demo showing Spatial, AI Vector Search, JSON Relational Duality, and MongoDB API compatibility through a Vehicle Routing Problem (VRP) scenario set in Chicago. All code is Oracle SQL and PL/SQL — there is no build system, no package manager, and no application runtime.

## Running the demo

All scripts run in SQLcl connected to an Oracle 26ai ADW instance. Scripts must be run in order.

**One-time setup (as ADMIN):**
```sql
SET CLOUDCONFIG wallet/Wallet_YourDB.zip
CONNECT admin/password@yourdb_medium
@sql/00_prereq_setup.sql
```

**Full demo run (as fleet_demo):**
```sql
CONNECT fleet_demo/Fleet_Demo_2026#@yourdb_medium
@sql/00_master_run.sql
```

**Optional MongoDB/SODA demo:**
```sql
@sql/08_soda_orders.sql
```

**Reset everything:**
```sql
@sql/99_cleanup.sql
```

**MCP server mode** (allows Claude to drive the demo via natural language):
```bash
sql /nolog -mcp
```

## Script execution order

`00_prereq_setup.sql` (ADMIN) → `00_master_run.sql` (fleet_demo) which calls 01→07 in sequence → optionally `08_soda_orders.sql`

Each numbered script is idempotent when preceded by `99_cleanup.sql`. Scripts 01–07 have interdependencies — 04 requires 01–03, 06 requires 01–05, etc.

## Key schema objects

- **`fleet_telemetry`** — range-partitioned by `recorded_at` date; spatial index on `location`
- **`vw_vehicle_locations`** — view joining `fleet_vehicles` + `fleet_depots` + latest telemetry ping per vehicle; exposes `last_ping` (aliased from `recorded_at`), `current_location` (aliased from `location`), and `engine_temp_c`
- **`orders_duality`** — JSON Relational Duality View over `fleet_orders`; single root table only (ORA-40935 constraint)
- **`fleet_routes_optimized`** — has `route_vector VECTOR(128,FLOAT32)` column with HNSW index for cosine similarity search
- **`fleet_orders_docs`** — SODA collection (Oracle table with JSON column) created by `08_soda_orders.sql`; visible in MongoDB Compass as a collection under the `fleet_demo` database

## Oracle 26ai–specific patterns

**Spatial geometry construction** — always use `SDO_GEOMETRY(2001, 4326, SDO_POINT_TYPE(lon, lat, NULL), NULL, NULL)`. Type code 2001 = point, 4326 = WGS84. Longitude comes before latitude.

**Spatial metadata** — `USER_SDO_GEOM_METADATA` must be populated before creating spatial indexes. This is done in `01_create_schema.sql`.

**VECTOR type** — `VECTOR(128, FLOAT32)`. `TO_VECTOR()` requires a bracketed string `'[n1,n2,...]'` — build with `TO_CHAR(val, 'FM999990.9999999')` to avoid leading-decimal parse errors.

**Local PL/SQL functions** — cannot be called inside SQL `VALUES (...)` or `SET col = fn()` clauses (PLS-00231). Pre-compute into a variable first. Trig functions (`SIN`, `COS`, `ATAN2`) inside local functions called from nested FOR/WHILE loops cause `ORA-06502 via SYS.STANDARD` in Oracle 26ai — use pure SQL `INSERT...SELECT` instead.

**SDO object attributes in aggregates** — require a table alias: `AVG(s.location.sdo_point.x)` not `AVG(location.sdo_point.x)`.

**SDO_INSIDE / SDO_WITHIN_DISTANCE** — return `'TRUE'`/`'FALSE'` strings; compare with `= 'TRUE'`.

## MongoDB API notes

The Oracle MongoDB wire protocol API (port 27017) exposes SODA collections, not relational tables or Duality Views. The `fleet_demo` Oracle schema maps directly to the `fleet_demo` MongoDB database — no separate database creation needed. Known gaps: `watch()`/change streams, `SPATIAL_INDEX_V2`/HNSW index creation via `createIndex()`, `$vectorSearch`, GridFS, TTL indexes.

## Presentation

`presentation/fleet-demo.html` is a self-contained Reveal.js deck. Open in a browser; press `S` for speaker view (shows `<aside class="notes">` content). `presentation/speaker-notes.md` is the standalone reference version of all speaker notes.
