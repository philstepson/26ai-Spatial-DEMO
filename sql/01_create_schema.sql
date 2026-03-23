-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 01_create_schema.sql
-- Purpose: Create all tables, spatial metadata, indexes, views
--
-- Features showcased:
--   • Oracle Spatial  : SDO_GEOMETRY (points, linestrings, polygons)
--   • AI Vector Search: VECTOR(128) route fingerprints (Oracle 23ai/26ai)
--   • JSON columns    : Flexible metadata on all major entities
--   • Partitioning    : Range partition on telemetry by time
--   • Duality Views   : JSON Relational Duality (Oracle 26ai)
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK ON

PROMPT
PROMPT ============================================================
PROMPT  Oracle 26ai | Fleet Spatial Optimization Demo
PROMPT  Step 1/7 : Creating Schema
PROMPT ============================================================
PROMPT

-- ------------------------------------------------------------
-- Clean slate – drop existing demo objects if present
-- ------------------------------------------------------------
DECLARE
  PROCEDURE drop_if_exists(p_obj VARCHAR2, p_type VARCHAR2) IS
  BEGIN
    IF p_type = 'TABLE' THEN
      EXECUTE IMMEDIATE 'DROP TABLE ' || p_obj || ' CASCADE CONSTRAINTS PURGE';
    ELSIF p_type = 'VIEW' THEN
      EXECUTE IMMEDIATE 'DROP VIEW ' || p_obj;
    ELSIF p_type = 'SEQUENCE' THEN
      EXECUTE IMMEDIATE 'DROP SEQUENCE ' || p_obj;
    END IF;
    DBMS_OUTPUT.PUT_LINE('  Dropped ' || p_type || ': ' || p_obj);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  -- Drop in reverse FK order
  drop_if_exists('FLEET_TELEMETRY',          'TABLE');
  drop_if_exists('FLEET_ROUTE_STOPS',        'TABLE');
  drop_if_exists('FLEET_ROUTES_OPTIMIZED',   'TABLE');
  drop_if_exists('FLEET_ROUTES_BASELINE',    'TABLE');
  drop_if_exists('FLEET_ORDERS',             'TABLE');
  drop_if_exists('FLEET_CUSTOMERS',          'TABLE');
  drop_if_exists('FLEET_VEHICLES',           'TABLE');
  drop_if_exists('FLEET_DEPOTS',             'TABLE');
  drop_if_exists('FLEET_TRAFFIC_ZONES',      'TABLE');
  drop_if_exists('VW_ROUTE_COMPARISON',      'VIEW');
  drop_if_exists('VW_VEHICLE_LOCATIONS',     'VIEW');
  DBMS_OUTPUT.PUT_LINE('  Cleanup complete.');
END;
/

-- Remove stale spatial metadata
DELETE FROM user_sdo_geom_metadata
 WHERE table_name IN (
   'FLEET_DEPOTS','FLEET_VEHICLES','FLEET_CUSTOMERS',
   'FLEET_ROUTES_BASELINE','FLEET_ROUTES_OPTIMIZED',
   'FLEET_ROUTE_STOPS','FLEET_TELEMETRY','FLEET_TRAFFIC_ZONES'
 );
COMMIT;

PROMPT  Creating tables...

-- ============================================================
-- TABLE 1: fleet_depots
--   Distribution centres / warehouses
-- ============================================================
CREATE TABLE fleet_depots (
    depot_id          NUMBER          GENERATED ALWAYS AS IDENTITY
                                      CONSTRAINT pk_fleet_depots PRIMARY KEY,
    depot_name        VARCHAR2(100)   NOT NULL,
    city              VARCHAR2(100),
    address           VARCHAR2(250),
    location          SDO_GEOMETRY,             -- WGS84 point (SRID 4326)
    capacity_m3       NUMBER(10,2),
    vehicle_slots     NUMBER,
    operating_open    NUMBER(4)       DEFAULT 0600,  -- HHMM
    operating_close   NUMBER(4)       DEFAULT 2000,
    depot_meta        JSON,                     -- Oracle 26ai: native JSON column
    created_at        TIMESTAMP       DEFAULT SYSTIMESTAMP
);

COMMENT ON TABLE  fleet_depots                IS 'Distribution centre / depot master';
COMMENT ON COLUMN fleet_depots.location       IS 'SDO_GEOMETRY point, SRID 4326 (WGS84)';
COMMENT ON COLUMN fleet_depots.operating_open IS 'Opening time HHMM e.g. 0600 = 06:00';

-- ============================================================
-- TABLE 2: fleet_vehicles
-- ============================================================
CREATE TABLE fleet_vehicles (
    vehicle_id          NUMBER          GENERATED ALWAYS AS IDENTITY
                                        CONSTRAINT pk_fleet_vehicles PRIMARY KEY,
    depot_id            NUMBER          NOT NULL
                                        CONSTRAINT fk_veh_depot
                                        REFERENCES fleet_depots(depot_id),
    vehicle_code        VARCHAR2(20)    NOT NULL CONSTRAINT uq_veh_code UNIQUE,
    vehicle_type        VARCHAR2(30)    NOT NULL,
      -- 'HEAVY_TRUCK' | 'BOX_TRUCK' | 'ELECTRIC_VAN' | 'VAN'
    max_payload_kg      NUMBER(8,2)     NOT NULL,
    max_volume_m3       NUMBER(6,2)     NOT NULL,
    fuel_type           VARCHAR2(20),   -- 'DIESEL' | 'ELECTRIC' | 'HYBRID'
    fuel_cost_per_km    NUMBER(6,4),    -- USD per km
    emissions_kg_per_km NUMBER(7,5),   -- kg CO2 per km
    current_location    SDO_GEOMETRY,
    status              VARCHAR2(20)    DEFAULT 'AVAILABLE',
      -- 'AVAILABLE' | 'IN_ROUTE' | 'MAINTENANCE' | 'OFFLINE'
    last_updated        TIMESTAMP       DEFAULT SYSTIMESTAMP,
    vehicle_meta        JSON
);

COMMENT ON TABLE fleet_vehicles IS 'Fleet vehicle master with spatial current location';

-- ============================================================
-- TABLE 3: fleet_customers
-- ============================================================
CREATE TABLE fleet_customers (
    customer_id       NUMBER          GENERATED ALWAYS AS IDENTITY
                                      CONSTRAINT pk_fleet_customers PRIMARY KEY,
    customer_name     VARCHAR2(100)   NOT NULL,
    neighborhood      VARCHAR2(100),
    city              VARCHAR2(60)    DEFAULT 'Chicago',
    address           VARCHAR2(250),
    location          SDO_GEOMETRY    NOT NULL,   -- Delivery point
    time_window_open  NUMBER(4)       DEFAULT 0800,
    time_window_close NUMBER(4)       DEFAULT 1700,
    service_minutes   NUMBER          DEFAULT 15,
    priority          NUMBER(1)       DEFAULT 3,
      -- 1=URGENT  2=HIGH  3=NORMAL
    contact_phone     VARCHAR2(20),
    created_at        TIMESTAMP       DEFAULT SYSTIMESTAMP
);

COMMENT ON TABLE fleet_customers IS 'Customer delivery locations (spatial points)';

-- ============================================================
-- TABLE 4: fleet_orders
-- ============================================================
CREATE TABLE fleet_orders (
    order_id          NUMBER          GENERATED ALWAYS AS IDENTITY
                                      CONSTRAINT pk_fleet_orders PRIMARY KEY,
    customer_id       NUMBER          NOT NULL
                                      CONSTRAINT fk_ord_cust
                                      REFERENCES fleet_customers(customer_id),
    depot_id          NUMBER          NOT NULL
                                      CONSTRAINT fk_ord_depot
                                      REFERENCES fleet_depots(depot_id),
    order_ref         VARCHAR2(30)    NOT NULL CONSTRAINT uq_ord_ref UNIQUE,
    order_date        DATE            DEFAULT SYSDATE,
    delivery_date     DATE            NOT NULL,
    weight_kg         NUMBER(8,2)     NOT NULL,
    volume_m3         NUMBER(6,3)     NOT NULL,
    priority          NUMBER(1)       DEFAULT 3,
    status            VARCHAR2(30)    DEFAULT 'PENDING',
      -- 'PENDING' | 'ASSIGNED' | 'IN_TRANSIT' | 'DELIVERED' | 'FAILED'
    delivery_notes    VARCHAR2(500),
    order_meta        JSON
);

COMMENT ON TABLE fleet_orders IS 'Delivery orders linked to customers and sourced from depots';

-- ============================================================
-- TABLE 5: fleet_routes_baseline
--   Naive (unoptimised) routes – BEFORE VRP
-- ============================================================
CREATE TABLE fleet_routes_baseline (
    route_id          NUMBER          GENERATED ALWAYS AS IDENTITY
                                      CONSTRAINT pk_fleet_rb PRIMARY KEY,
    vehicle_id        NUMBER          NOT NULL
                                      CONSTRAINT fk_rb_veh
                                      REFERENCES fleet_vehicles(vehicle_id),
    route_date        DATE            NOT NULL,
    route_start       TIMESTAMP,
    route_end         TIMESTAMP,
    total_distance_km NUMBER(10,3),
    total_time_min    NUMBER(8,2),
    total_fuel_liters NUMBER(8,3),
    fuel_cost         NUMBER(10,2),
    co2_kg            NUMBER(10,3),
    num_stops         NUMBER,
    route_path        SDO_GEOMETRY,   -- LineString connecting all stops
    route_status      VARCHAR2(20)    DEFAULT 'COMPLETED',
    route_meta        JSON
);

COMMENT ON TABLE fleet_routes_baseline IS
  'Baseline (unoptimised) routes – naive first-come assignment';

-- ============================================================
-- TABLE 6: fleet_routes_optimized
--   VRP-optimised routes – AFTER optimisation
--   Showcases: VECTOR column for AI route similarity search
-- ============================================================
CREATE TABLE fleet_routes_optimized (
    route_id          NUMBER          GENERATED ALWAYS AS IDENTITY
                                      CONSTRAINT pk_fleet_ro PRIMARY KEY,
    vehicle_id        NUMBER          NOT NULL
                                      CONSTRAINT fk_ro_veh
                                      REFERENCES fleet_vehicles(vehicle_id),
    route_date        DATE            NOT NULL,
    route_start       TIMESTAMP,
    route_end         TIMESTAMP,
    total_distance_km NUMBER(10,3),
    total_time_min    NUMBER(8,2),
    total_fuel_liters NUMBER(8,3),
    fuel_cost         NUMBER(10,2),
    co2_kg            NUMBER(10,3),
    num_stops         NUMBER,
    route_path        SDO_GEOMETRY,
    route_status      VARCHAR2(20)    DEFAULT 'PLANNED',
    savings_km        NUMBER(10,3),   -- Distance saved vs. baseline
    savings_cost      NUMBER(10,2),   -- $ saved vs. baseline
    savings_pct       NUMBER(5,2),    -- % improvement
    -- Oracle 26ai: AI Vector Search – 128-dim route fingerprint
    -- Enables: "Find me routes similar to this one from last month"
    route_vector      VECTOR(128, FLOAT32),
    route_meta        JSON
);

COMMENT ON TABLE fleet_routes_optimized IS
  'VRP-optimised routes with AI Vector fingerprints for similarity search';
COMMENT ON COLUMN fleet_routes_optimized.route_vector IS
  'Oracle 26ai VECTOR: 128-dim embedding of route characteristics for similarity search';

-- ============================================================
-- TABLE 7: fleet_route_stops
--   Individual stop records for both baseline and optimised routes
-- ============================================================
CREATE TABLE fleet_route_stops (
    stop_id             NUMBER          GENERATED ALWAYS AS IDENTITY
                                        CONSTRAINT pk_fleet_stops PRIMARY KEY,
    route_id            NUMBER          NOT NULL,
    route_type          VARCHAR2(20)    NOT NULL,
      -- 'BASELINE' | 'OPTIMIZED'
    stop_sequence       NUMBER          NOT NULL,
    order_id            NUMBER          REFERENCES fleet_orders(order_id),
    stop_type           VARCHAR2(20)    DEFAULT 'DELIVERY',
      -- 'DEPOT_START' | 'DELIVERY' | 'DEPOT_END'
    location            SDO_GEOMETRY,
    planned_arrival     TIMESTAMP,
    planned_departure   TIMESTAMP,
    actual_arrival      TIMESTAMP,
    actual_departure    TIMESTAMP,
    distance_from_prev  NUMBER(10,3),   -- km from previous stop
    cumulative_dist_km  NUMBER(10,3),
    on_time             VARCHAR2(1)     DEFAULT 'Y'
);

-- ============================================================
-- TABLE 8: fleet_telemetry
--   Real-time GPS telemetry from vehicles (partitioned by time)
-- ============================================================
CREATE TABLE fleet_telemetry (
    telemetry_id      NUMBER          GENERATED ALWAYS AS IDENTITY
                                      CONSTRAINT pk_fleet_telem PRIMARY KEY,
    vehicle_id        NUMBER          NOT NULL
                                      CONSTRAINT fk_telem_veh
                                      REFERENCES fleet_vehicles(vehicle_id),
    recorded_at       TIMESTAMP       DEFAULT SYSTIMESTAMP,
    location          SDO_GEOMETRY    NOT NULL,   -- Live GPS position
    speed_kmh         NUMBER(5,2),
    heading_deg       NUMBER(5,2),    -- 0-360 compass bearing
    fuel_level_pct    NUMBER(5,2),
    engine_temp_c     NUMBER(5,2),
    odometer_km       NUMBER(10,3),
    status            VARCHAR2(30),
      -- 'DRIVING' | 'IDLE' | 'DELIVERING' | 'BREAKDOWN' | 'REFUELLING'
    alert_code        VARCHAR2(10)    -- NULL | 'SPD' | 'FUEL' | 'TEMP' | 'DEVRT'
)
PARTITION BY RANGE (recorded_at) (
    PARTITION telem_2025_q1 VALUES LESS THAN (TIMESTAMP '2025-04-01 00:00:00'),
    PARTITION telem_2025_q2 VALUES LESS THAN (TIMESTAMP '2025-07-01 00:00:00'),
    PARTITION telem_2025_q3 VALUES LESS THAN (TIMESTAMP '2025-10-01 00:00:00'),
    PARTITION telem_2025_q4 VALUES LESS THAN (TIMESTAMP '2026-01-01 00:00:00'),
    PARTITION telem_2026_q1 VALUES LESS THAN (TIMESTAMP '2026-04-01 00:00:00'),
    PARTITION telem_future  VALUES LESS THAN (MAXVALUE)
);

COMMENT ON TABLE fleet_telemetry IS
  'High-frequency GPS telemetry – range-partitioned by time for performance';

-- ============================================================
-- TABLE 9: fleet_traffic_zones
--   Chicago area traffic/congestion zone polygons
-- ============================================================
CREATE TABLE fleet_traffic_zones (
    zone_id           NUMBER          GENERATED ALWAYS AS IDENTITY
                                      CONSTRAINT pk_fleet_zones PRIMARY KEY,
    zone_name         VARCHAR2(100)   NOT NULL,
    zone_type         VARCHAR2(30),
      -- 'CBD' | 'RESIDENTIAL' | 'INDUSTRIAL' | 'HIGHWAY' | 'AIRPORT'
    zone_boundary     SDO_GEOMETRY,   -- Polygon
    peak_am_factor    NUMBER(4,2)     DEFAULT 1.00, -- Speed multiplier 6–9am
    peak_pm_factor    NUMBER(4,2)     DEFAULT 1.00, -- Speed multiplier 4–7pm
    avg_speed_kmh     NUMBER(5,2)     DEFAULT 40.0,
    zone_notes        VARCHAR2(300)
);

PROMPT  Tables created. Registering spatial metadata...

-- ============================================================
-- SPATIAL METADATA REGISTRATION
--   Required for Oracle Spatial indexes (SDO_INDEX)
--   Bounding box: Chicago Metro Area
--   LON: -88.50 to -87.30  /  LAT: 41.60 to 42.20
-- ============================================================
INSERT INTO user_sdo_geom_metadata VALUES (
  'FLEET_DEPOTS','LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LON', -88.50, -87.30, 0.005),
    SDO_DIM_ELEMENT('LAT',  41.60,  42.20, 0.005)
  ), 4326);

INSERT INTO user_sdo_geom_metadata VALUES (
  'FLEET_VEHICLES','CURRENT_LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LON', -88.50, -87.30, 0.005),
    SDO_DIM_ELEMENT('LAT',  41.60,  42.20, 0.005)
  ), 4326);

INSERT INTO user_sdo_geom_metadata VALUES (
  'FLEET_CUSTOMERS','LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LON', -88.50, -87.30, 0.005),
    SDO_DIM_ELEMENT('LAT',  41.60,  42.20, 0.005)
  ), 4326);

INSERT INTO user_sdo_geom_metadata VALUES (
  'FLEET_ROUTES_BASELINE','ROUTE_PATH',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LON', -88.50, -87.30, 0.005),
    SDO_DIM_ELEMENT('LAT',  41.60,  42.20, 0.005)
  ), 4326);

INSERT INTO user_sdo_geom_metadata VALUES (
  'FLEET_ROUTES_OPTIMIZED','ROUTE_PATH',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LON', -88.50, -87.30, 0.005),
    SDO_DIM_ELEMENT('LAT',  41.60,  42.20, 0.005)
  ), 4326);

INSERT INTO user_sdo_geom_metadata VALUES (
  'FLEET_ROUTE_STOPS','LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LON', -88.50, -87.30, 0.005),
    SDO_DIM_ELEMENT('LAT',  41.60,  42.20, 0.005)
  ), 4326);

INSERT INTO user_sdo_geom_metadata VALUES (
  'FLEET_TELEMETRY','LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LON', -88.50, -87.30, 0.005),
    SDO_DIM_ELEMENT('LAT',  41.60,  42.20, 0.005)
  ), 4326);

INSERT INTO user_sdo_geom_metadata VALUES (
  'FLEET_TRAFFIC_ZONES','ZONE_BOUNDARY',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('LON', -88.50, -87.30, 0.005),
    SDO_DIM_ELEMENT('LAT',  41.60,  42.20, 0.005)
  ), 4326);

COMMIT;
PROMPT  Spatial metadata registered.

-- ============================================================
-- SPATIAL INDEXES
-- ============================================================
PROMPT  Building spatial indexes...

CREATE INDEX idx_fleet_depots_loc
    ON fleet_depots(location)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2
    PARAMETERS ('layer_gtype=POINT');

CREATE INDEX idx_fleet_vehicles_loc
    ON fleet_vehicles(current_location)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2
    PARAMETERS ('layer_gtype=POINT');

CREATE INDEX idx_fleet_customers_loc
    ON fleet_customers(location)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2
    PARAMETERS ('layer_gtype=POINT');

CREATE INDEX idx_fleet_rb_path
    ON fleet_routes_baseline(route_path)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2
    PARAMETERS ('layer_gtype=LINE');

CREATE INDEX idx_fleet_ro_path
    ON fleet_routes_optimized(route_path)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2
    PARAMETERS ('layer_gtype=LINE');

CREATE INDEX idx_fleet_stops_loc
    ON fleet_route_stops(location)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2
    PARAMETERS ('layer_gtype=POINT');

CREATE INDEX idx_fleet_telem_loc
    ON fleet_telemetry(location)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2
    PARAMETERS ('layer_gtype=POINT');

CREATE INDEX idx_fleet_tz_boundary
    ON fleet_traffic_zones(zone_boundary)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2
    PARAMETERS ('layer_gtype=POLYGON');

-- ============================================================
-- VECTOR INDEX (Oracle 26ai – AI Vector Search)
--   HNSW index for fast approximate nearest-neighbour search
--   on route embeddings
-- ============================================================
CREATE VECTOR INDEX idx_fleet_ro_vector
    ON fleet_routes_optimized(route_vector)
    ORGANIZATION INMEMORY NEIGHBOR GRAPH
    DISTANCE COSINE
    WITH TARGET ACCURACY 95;

PROMPT  Indexes created.

-- ============================================================
-- STANDARD B-TREE INDEXES
-- ============================================================
CREATE INDEX idx_fleet_veh_depot   ON fleet_vehicles(depot_id);
CREATE INDEX idx_fleet_ord_cust    ON fleet_orders(customer_id);
CREATE INDEX idx_fleet_ord_depot   ON fleet_orders(depot_id);
CREATE INDEX idx_fleet_ord_deldate ON fleet_orders(delivery_date);
CREATE INDEX idx_fleet_rb_vehicle  ON fleet_routes_baseline(vehicle_id, route_date);
CREATE INDEX idx_fleet_ro_vehicle  ON fleet_routes_optimized(vehicle_id, route_date);
CREATE INDEX idx_fleet_stops_route ON fleet_route_stops(route_id, route_type, stop_sequence);
CREATE INDEX idx_fleet_telem_veh   ON fleet_telemetry(vehicle_id, recorded_at);

-- ============================================================
-- VIEWS
-- ============================================================
PROMPT  Creating analytical views...

-- Before/After comparison view
CREATE OR REPLACE VIEW vw_route_comparison AS
WITH baseline_summary AS (
    SELECT
        route_date,
        COUNT(*)                        AS vehicles_used,
        SUM(total_distance_km)          AS total_km,
        SUM(total_time_min)             AS total_min,
        SUM(fuel_cost)                  AS total_fuel_cost,
        SUM(co2_kg)                     AS total_co2_kg,
        SUM(num_stops)                  AS total_stops,
        ROUND(AVG(total_distance_km),1) AS avg_km_per_route
    FROM fleet_routes_baseline
    GROUP BY route_date
),
optimized_summary AS (
    SELECT
        route_date,
        COUNT(*)                        AS vehicles_used,
        SUM(total_distance_km)          AS total_km,
        SUM(total_time_min)             AS total_min,
        SUM(fuel_cost)                  AS total_fuel_cost,
        SUM(co2_kg)                     AS total_co2_kg,
        SUM(num_stops)                  AS total_stops,
        ROUND(AVG(total_distance_km),1) AS avg_km_per_route
    FROM fleet_routes_optimized
    GROUP BY route_date
)
SELECT
    b.route_date,
    -- Baseline
    b.vehicles_used                                         AS base_vehicles,
    ROUND(b.total_km, 1)                                    AS base_total_km,
    ROUND(b.total_fuel_cost, 2)                             AS base_fuel_cost,
    ROUND(b.total_co2_kg, 1)                                AS base_co2_kg,
    -- Optimized
    o.vehicles_used                                         AS opt_vehicles,
    ROUND(o.total_km, 1)                                    AS opt_total_km,
    ROUND(o.total_fuel_cost, 2)                             AS opt_fuel_cost,
    ROUND(o.total_co2_kg, 1)                                AS opt_co2_kg,
    -- Savings
    (b.vehicles_used - o.vehicles_used)                     AS vehicles_saved,
    ROUND(b.total_km - o.total_km, 1)                       AS km_saved,
    ROUND(b.total_fuel_cost - o.total_fuel_cost, 2)         AS cost_saved,
    ROUND(b.total_co2_kg - o.total_co2_kg, 1)               AS co2_saved_kg,
    ROUND((b.total_km - o.total_km) / b.total_km * 100, 1) AS km_savings_pct,
    ROUND((b.total_fuel_cost - o.total_fuel_cost)
           / b.total_fuel_cost * 100, 1)                    AS cost_savings_pct
FROM  baseline_summary  b
JOIN  optimized_summary o ON b.route_date = o.route_date
ORDER BY b.route_date;

COMMENT ON TABLE vw_route_comparison IS
  'Side-by-side before/after comparison: baseline vs. VRP-optimised routes';

-- Live vehicle location view
CREATE OR REPLACE VIEW vw_vehicle_locations AS
SELECT
    v.vehicle_id,
    v.vehicle_code,
    v.vehicle_type,
    v.fuel_type,
    v.status,
    d.depot_name,
    d.city,
    t.speed_kmh,
    t.heading_deg,
    t.fuel_level_pct,
    t.recorded_at        AS last_ping,
    t.alert_code,
    t.location           AS current_location
FROM  fleet_vehicles    v
JOIN  fleet_depots      d  ON d.depot_id  = v.depot_id
LEFT JOIN (
    -- Most-recent telemetry ping per vehicle
    SELECT *
    FROM   fleet_telemetry
    WHERE  (vehicle_id, recorded_at) IN (
               SELECT vehicle_id, MAX(recorded_at)
               FROM   fleet_telemetry
               GROUP BY vehicle_id
           )
) t ON t.vehicle_id = v.vehicle_id;

-- ============================================================
-- JSON RELATIONAL DUALITY VIEW (Oracle 26ai)
--   Exposes fleet_orders as a document-centric JSON API
--   while being backed by relational tables.
-- ============================================================
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW orders_duality AS
SELECT JSON {
    '_id'          : o.order_id,
    'orderRef'     : o.order_ref,
    'deliveryDate' : o.delivery_date,
    'status'       : o.status,
    'priority'     : o.priority,
    'payload'      : {
        'weightKg' : o.weight_kg,
        'volumeM3' : o.volume_m3
    },
    'customer'     : {
        'id'        : c.customer_id,
        'name'      : c.customer_name,
        'address'   : c.address,
        'neighborhood': c.neighborhood
    },
    'depot'        : {
        'id'   : d.depot_id,
        'name' : d.depot_name,
        'city' : d.city
    }
}
FROM fleet_orders  o
JOIN fleet_customers c ON c.customer_id = o.customer_id
JOIN fleet_depots    d ON d.depot_id    = o.depot_id
WITH INSERT UPDATE DELETE;

PROMPT  Views created.

PROMPT
PROMPT ============================================================
PROMPT  Schema creation COMPLETE
PROMPT
PROMPT  Tables  : fleet_depots, fleet_vehicles, fleet_customers,
PROMPT            fleet_orders, fleet_routes_baseline,
PROMPT            fleet_routes_optimized, fleet_route_stops,
PROMPT            fleet_telemetry, fleet_traffic_zones
PROMPT
PROMPT  Views   : vw_route_comparison, vw_vehicle_locations,
PROMPT            orders_duality (JSON Duality)
PROMPT
PROMPT  Indexes : 8 spatial, 1 VECTOR (HNSW), 8 B-tree
PROMPT ============================================================
PROMPT  Next: run  @sql/02_seed_data.sql
PROMPT ============================================================
PROMPT
