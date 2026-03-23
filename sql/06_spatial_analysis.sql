-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 06_spatial_analysis.sql
-- Purpose: Showcase Oracle Spatial query capabilities
--          and Oracle 26ai AI Vector Search on route embeddings
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK ON
SET LINESIZE 180
SET PAGESIZE 60
COLUMN metric         FORMAT A40
COLUMN value          FORMAT A30
COLUMN vehicle_code   FORMAT A14
COLUMN neighborhood   FORMAT A22
COLUMN distance_km    FORMAT 999.9
COLUMN route_id       FORMAT 9999
COLUMN similarity     FORMAT 0.999

PROMPT
PROMPT ============================================================
PROMPT  Oracle 26ai | Fleet Spatial Optimization Demo
PROMPT  Step 6/7 : Spatial & AI Vector Analysis Showcase
PROMPT ============================================================
PROMPT

-- ============================================================
-- QUERY 1: Customers within 5 km of O'Hare depot (SDO_WITHIN_DISTANCE)
-- ============================================================
PROMPT
PROMPT ── Q1: Customers within 5 km of O''Hare Depot ──────────────
PROMPT

SELECT c.customer_id,
       c.customer_name,
       c.neighborhood,
       ROUND(
         SDO_GEOM.SDO_DISTANCE(
           c.location,
           (SELECT location FROM fleet_depots WHERE depot_name LIKE '%O''Hare%'),
           0.005, 'unit=KM'
         ), 2
       ) AS distance_km
FROM   fleet_customers c
WHERE  SDO_WITHIN_DISTANCE(
           c.location,
           (SELECT location FROM fleet_depots WHERE depot_name LIKE '%O''Hare%'),
           'distance=5 unit=KM'
       ) = 'TRUE'
ORDER  BY distance_km;

-- ============================================================
-- QUERY 2: Nearest 3 depots to a given customer (SDO_NN)
-- ============================================================
PROMPT
PROMPT ── Q2: Nearest depot to each of 5 random customers (SDO_NN) ──
PROMPT

SELECT c.customer_name,
       c.neighborhood,
       d.depot_name,
       ROUND(
         SDO_GEOM.SDO_DISTANCE(c.location, d.location, 0.005, 'unit=KM'), 2
       ) AS dist_km
FROM   fleet_customers c,
       fleet_depots    d
WHERE  c.customer_id IN (5, 15, 25, 35, 45)
AND    SDO_NN(
           d.location, c.location,
           'sdo_num_res=1', 1
       ) = 'TRUE'
ORDER  BY c.customer_id;

-- ============================================================
-- QUERY 3: Vehicles currently inside the CBD traffic zone
-- ============================================================
PROMPT
PROMPT ── Q3: Vehicles currently inside CBD congestion zone ─────────
PROMPT

SELECT v.vehicle_code,
       v.vehicle_type,
       v.status,
       t.speed_kmh,
       t.alert_code,
       t.recorded_at AS last_ping
FROM   fleet_vehicles         v
JOIN   fleet_vehicle_locations t USING (vehicle_id)    -- uses the view
JOIN   fleet_traffic_zones    tz
    ON tz.zone_type = 'CBD'
WHERE  SDO_INSIDE(t.current_location, tz.zone_boundary) = 'TRUE';

-- ============================================================
-- QUERY 4: Total route length using SDO_GEOM.SDO_LENGTH
--          on the stored LineString geometries
-- ============================================================
PROMPT
PROMPT ── Q4: Comparing baseline vs. optimised route geometry lengths ─
PROMPT

-- NOTE: route_path LineStrings are built incrementally per stop.
-- For demo we compare the sum directly from the accumulators,
-- but this illustrates how you would query geometry directly.
SELECT 'Baseline routes'      AS scenario,
       COUNT(*)               AS num_routes,
       ROUND(SUM(total_distance_km),1) AS total_km,
       ROUND(AVG(total_distance_km),1) AS avg_km,
       ROUND(MAX(total_distance_km),1) AS max_km
FROM   fleet_routes_baseline
WHERE  route_date = TRUNC(SYSDATE) + 1
UNION ALL
SELECT 'Optimised routes',
       COUNT(*),
       ROUND(SUM(total_distance_km),1),
       ROUND(AVG(total_distance_km),1),
       ROUND(MAX(total_distance_km),1)
FROM   fleet_routes_optimized
WHERE  route_date = TRUNC(SYSDATE) + 1;

-- ============================================================
-- QUERY 5: Spatial clustering – customers grouped by traffic zone
-- ============================================================
PROMPT
PROMPT ── Q5: Delivery density by traffic zone ─────────────────────
PROMPT

SELECT tz.zone_name,
       tz.zone_type,
       COUNT(c.customer_id)         AS customers_in_zone,
       ROUND(tz.avg_speed_kmh, 0)   AS avg_speed_kmh,
       ROUND(tz.peak_am_factor, 2)  AS am_congestion_factor
FROM   fleet_traffic_zones  tz
LEFT JOIN fleet_customers   c
    ON SDO_INSIDE(c.location, tz.zone_boundary) = 'TRUE'
GROUP  BY tz.zone_id, tz.zone_name, tz.zone_type,
          tz.avg_speed_kmh, tz.peak_am_factor
ORDER  BY customers_in_zone DESC;

-- ============================================================
-- QUERY 6: Oracle 26ai AI Vector Search
--          "Find optimised routes similar to route #1
--           (same geographic cluster, similar stop count)"
-- ============================================================
PROMPT
PROMPT ── Q6: Oracle 26ai VECTOR SEARCH – similar routes ──────────
PROMPT        (HNSW approximate nearest-neighbour cosine similarity)
PROMPT

SELECT route_id,
       vehicle_id,
       num_stops,
       ROUND(total_distance_km, 1) AS dist_km,
       ROUND(fuel_cost,          2) AS fuel_usd,
       ROUND(savings_pct,        1) AS savings_pct,
       -- Vector similarity score (1.0 = identical)
       ROUND(1 - VECTOR_DISTANCE(
               route_vector,
               (SELECT route_vector FROM fleet_routes_optimized
                WHERE  route_id = (SELECT MIN(route_id) FROM fleet_routes_optimized)),
               COSINE
             ), 3)                  AS similarity
FROM   fleet_routes_optimized
WHERE  route_vector IS NOT NULL
ORDER  BY similarity DESC
FETCH FIRST 5 ROWS ONLY;

-- ============================================================
-- QUERY 7: Time-windowed telemetry heatmap
--          – where are vehicles spending the most time idle?
-- ============================================================
PROMPT
PROMPT ── Q7: Idle time by neighbourhood (telemetry spatial join) ───
PROMPT

SELECT
    c.neighborhood,
    COUNT(t.telemetry_id)                                AS idle_pings,
    ROUND(COUNT(t.telemetry_id) * 5 / 60, 1)            AS idle_hours,
    COUNT(DISTINCT t.vehicle_id)                         AS vehicles_affected
FROM   fleet_telemetry   t
JOIN   fleet_customers   c
    ON SDO_WITHIN_DISTANCE(t.location, c.location, 'distance=0.5 unit=KM') = 'TRUE'
WHERE  t.status      = 'IDLE'
AND    t.recorded_at >= TRUNC(SYSDATE)
GROUP  BY c.neighborhood
HAVING COUNT(t.telemetry_id) > 1
ORDER  BY idle_pings DESC
FETCH FIRST 10 ROWS ONLY;

-- ============================================================
-- QUERY 8: JSON Relational Duality – query orders as documents
-- ============================================================
PROMPT
PROMPT ── Q8: Oracle 26ai JSON Duality View – orders as JSON docs ───
PROMPT

SELECT od.data
FROM   orders_duality od
WHERE  JSON_VALUE(od.data, '$."status"')   = 'ASSIGNED'
AND    JSON_VALUE(od.data, '$."priority"') = '1'
ORDER  BY JSON_VALUE(od.data, '$."_id"' RETURNING NUMBER)
FETCH FIRST 3 ROWS ONLY;

-- ============================================================
-- QUERY 9: Vehicles with active alerts
-- ============================================================
PROMPT
PROMPT ── Q9: Active vehicle alerts (real-time) ────────────────────
PROMPT

SELECT
    v.vehicle_code,
    v.vehicle_type,
    t.alert_code,
    CASE t.alert_code
        WHEN 'FUEL' THEN 'Low fuel – ' || t.fuel_level_pct || '% remaining'
        WHEN 'TEMP' THEN 'Engine overheating – ' || t.engine_temp_c || '°C'
        WHEN 'SPD'  THEN 'Speed violation – ' || t.speed_kmh || ' km/h'
        ELSE 'Unknown alert'
    END                        AS alert_description,
    t.recorded_at              AS alert_time
FROM   fleet_vehicles         v
JOIN   fleet_vehicle_locations t USING (vehicle_id)
WHERE  t.alert_code IS NOT NULL
ORDER  BY t.recorded_at DESC;

PROMPT
PROMPT  Spatial & AI Vector analysis complete.
PROMPT  Next: run  @sql/07_report.sql  for the executive summary.
PROMPT
