-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 07_report.sql
-- Purpose: Executive summary – before/after visual comparison
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK OFF
SET LINESIZE 200
SET PAGESIZE 100

PROMPT
PROMPT ╔══════════════════════════════════════════════════════════════════╗
PROMPT ║   Oracle 26ai  │  Fleet Spatial Optimization  │  DEMO REPORT    ║
PROMPT ╠══════════════════════════════════════════════════════════════════╣
PROMPT ║   Chicago Metro Delivery Fleet  │  Single Day Optimisation       ║
PROMPT ╚══════════════════════════════════════════════════════════════════╝
PROMPT

-- ── SECTION 1: Fleet overview ──────────────────────────────────────────────
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT  FLEET OVERVIEW
PROMPT ─────────────────────────────────────────────────────────────────────

SELECT
    d.depot_name,
    COUNT(v.vehicle_id)                                          AS total_vehicles,
    SUM(CASE v.fuel_type WHEN 'ELECTRIC' THEN 1 ELSE 0 END)     AS electric,
    SUM(CASE v.fuel_type WHEN 'HYBRID'   THEN 1 ELSE 0 END)     AS hybrid,
    SUM(CASE v.fuel_type WHEN 'DIESEL'   THEN 1 ELSE 0 END)     AS diesel,
    ROUND(SUM(v.max_payload_kg)/1000, 1)                        AS total_payload_tonnes
FROM   fleet_depots   d
JOIN   fleet_vehicles v ON v.depot_id = d.depot_id
GROUP  BY d.depot_id, d.depot_name
ORDER  BY d.depot_id;

-- ── SECTION 2: Order summary ───────────────────────────────────────────────
PROMPT
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT  ORDER SUMMARY  (Delivery date: tomorrow)
PROMPT ─────────────────────────────────────────────────────────────────────

SELECT
    priority,
    CASE priority WHEN 1 THEN 'URGENT'
                  WHEN 2 THEN 'HIGH'
                  ELSE        'NORMAL' END  AS priority_label,
    COUNT(*)                                AS order_count,
    ROUND(SUM(weight_kg)/1000, 2)           AS total_tonnes,
    ROUND(SUM(volume_m3), 1)                AS total_m3
FROM   fleet_orders
WHERE  delivery_date = TRUNC(SYSDATE) + 1
GROUP  BY priority
ORDER  BY priority;

-- ── SECTION 3: The Money Shot – Before vs After ─────────────────────────
PROMPT
PROMPT ╔══════════════════════════════════════════════════════════════════╗
PROMPT ║         BEFORE  vs.  AFTER  ─  VRP OPTIMISATION RESULTS        ║
PROMPT ╚══════════════════════════════════════════════════════════════════╝

SELECT *
FROM   vw_route_comparison
WHERE  route_date = TRUNC(SYSDATE) + 1;

-- ── SECTION 4: Route-level breakdown ─────────────────────────────────────
PROMPT
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT  OPTIMISED ROUTE BREAKDOWN
PROMPT ─────────────────────────────────────────────────────────────────────

COLUMN vehicle_code     FORMAT A14
COLUMN dist_km          FORMAT 999.9
COLUMN fuel_usd         FORMAT 9999.99
COLUMN co2_kg           FORMAT 9999.9
COLUMN saves_km         FORMAT 999.9
COLUMN saves_pct        FORMAT 99.9
COLUMN num_stops        FORMAT 99

SELECT
    v.vehicle_code,
    v.vehicle_type,
    v.fuel_type,
    r.num_stops,
    ROUND(r.total_distance_km, 1)  AS dist_km,
    ROUND(r.fuel_cost,         2)  AS fuel_usd,
    ROUND(r.co2_kg,            1)  AS co2_kg,
    ROUND(r.savings_km,        1)  AS saves_km,
    ROUND(r.savings_pct,       1)  AS saves_pct
FROM   fleet_routes_optimized r
JOIN   fleet_vehicles         v ON v.vehicle_id = r.vehicle_id
WHERE  r.route_date = TRUNC(SYSDATE) + 1
AND    r.num_stops  > 0
ORDER  BY r.total_distance_km DESC;

-- ── SECTION 5: Stop-level detail for best route ──────────────────────────
PROMPT
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT  STOP SEQUENCE – most-loaded optimised route
PROMPT ─────────────────────────────────────────────────────────────────────

COLUMN stop_type        FORMAT A14
COLUMN stop_name        FORMAT A30
COLUMN planned_arrival  FORMAT A22
COLUMN dist_from_prev   FORMAT 99.99

SELECT
    s.stop_sequence,
    s.stop_type,
    NVL(c.customer_name, d.depot_name)              AS stop_name,
    NVL(c.neighborhood, d.city)                     AS area,
    TO_CHAR(s.planned_arrival, 'HH24:MI')           AS arrive,
    TO_CHAR(s.planned_departure,'HH24:MI')          AS depart,
    ROUND(s.distance_from_prev, 2)                  AS dist_km,
    ROUND(s.cumulative_dist_km, 2)                  AS cum_km
FROM   fleet_route_stops   s
LEFT JOIN fleet_orders      o  ON  o.order_id    = s.order_id
LEFT JOIN fleet_customers   c  ON  c.customer_id = o.customer_id
LEFT JOIN fleet_depots      d  ON  d.depot_id    = (
             SELECT depot_id FROM fleet_vehicles
             WHERE  vehicle_id = (
                 SELECT vehicle_id FROM fleet_routes_optimized
                 WHERE  route_id = s.route_id)
         )
WHERE  s.route_id   = (
           SELECT route_id
           FROM   fleet_routes_optimized
           WHERE  route_date = TRUNC(SYSDATE) + 1
           AND    num_stops  > 0
           ORDER  BY num_stops DESC
           FETCH FIRST 1 ROW ONLY
       )
AND    s.route_type = 'OPTIMIZED'
ORDER  BY s.stop_sequence;

-- ── SECTION 6: Telemetry summary ─────────────────────────────────────────
PROMPT
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT  REAL-TIME TELEMETRY SUMMARY
PROMPT ─────────────────────────────────────────────────────────────────────

COLUMN status           FORMAT A14

SELECT
    status,
    COUNT(*)                                 AS ping_count,
    ROUND(AVG(speed_kmh), 1)                 AS avg_speed_kmh,
    ROUND(AVG(fuel_level_pct), 1)            AS avg_fuel_pct,
    COUNT(CASE WHEN alert_code IS NOT NULL
               THEN 1 END)                   AS alerts
FROM   fleet_telemetry
WHERE  recorded_at >= TRUNC(SYSDATE)
GROUP  BY status
ORDER  BY ping_count DESC;

-- ── SECTION 7: Annualised business case ──────────────────────────────────
PROMPT
PROMPT ╔══════════════════════════════════════════════════════════════════╗
PROMPT ║                    ANNUALISED BUSINESS CASE                     ║
PROMPT ╚══════════════════════════════════════════════════════════════════╝

SELECT
    ROUND(base_total_km - opt_total_km, 0)            AS km_saved_per_day,
    ROUND((base_total_km - opt_total_km) * 250, 0)    AS km_saved_per_year,
    ROUND(base_fuel_cost - opt_fuel_cost, 2)          AS usd_saved_per_day,
    ROUND((base_fuel_cost - opt_fuel_cost) * 250, 0)  AS usd_saved_per_year,
    ROUND(base_co2_kg - opt_co2_kg, 1)                AS co2_saved_kg_per_day,
    ROUND((base_co2_kg - opt_co2_kg) * 250 / 1000, 1) AS co2_saved_tonnes_yr,
    km_savings_pct || '%'                             AS distance_reduction,
    cost_savings_pct || '%'                           AS cost_reduction
FROM   vw_route_comparison
WHERE  route_date = TRUNC(SYSDATE) + 1;

PROMPT
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT  ORACLE 26ai FEATURES USED IN THIS DEMO
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT   • Oracle Spatial     : SDO_GEOMETRY, SPATIAL_INDEX_V2
PROMPT                          SDO_WITHIN_DISTANCE, SDO_NN, SDO_GEOM.*
PROMPT   • AI Vector Search   : VECTOR(128,FLOAT32), HNSW index
PROMPT                          VECTOR_DISTANCE(... COSINE)
PROMPT   • JSON / Duality     : JSON columns, JSON Relational Duality View
PROMPT   • Partitioning       : Range partition on telemetry timestamp
PROMPT   • PL/SQL             : Nearest-neighbour VRP heuristic
PROMPT                          Haversine distance, time-window feasibility
PROMPT   • Analytical Views   : Before/after comparison view
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT  Demo complete!  Run @sql/99_cleanup.sql to drop all objects.
PROMPT ─────────────────────────────────────────────────────────────────────
PROMPT
