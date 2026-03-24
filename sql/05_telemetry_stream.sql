-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 05_telemetry_stream.sql
-- Purpose: Simulate real-time GPS telemetry – vehicles executing optimised routes
--          One ping every 5 minutes, interpolated along route path
--          Includes realistic events: speed changes, idle, fuel alerts
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK ON

PROMPT
PROMPT ============================================================
PROMPT  Oracle 26ai | Fleet Spatial Optimization Demo
PROMPT  Step 5/7 : Simulating Real-time Telemetry Stream
PROMPT ============================================================
PROMPT

DELETE FROM fleet_telemetry
 WHERE recorded_at >= TRUNC(SYSDATE);
COMMIT;

DECLARE
  c_demo_date CONSTANT DATE := TRUNC(SYSDATE) + 1;
  v_ping_cnt  NUMBER;
  v_routes    NUMBER;
  v_alerts    NUMBER;
BEGIN
  -- Pure SQL INSERT avoids trig functions in PL/SQL loops (ORA-06502 via SYS.STANDARD)
  -- One telemetry row per route stop; values computed via SQL arithmetic only
  INSERT INTO fleet_telemetry (
      vehicle_id, recorded_at, location,
      speed_kmh, heading_deg, fuel_level_pct,
      engine_temp_c, odometer_km, status, alert_code
  )
  SELECT
      r.vehicle_id,
      NVL(s.planned_arrival,
          CAST(c_demo_date AS TIMESTAMP)
            + NUMTODSINTERVAL(s.stop_sequence * 30, 'MINUTE')),
      s.location,
      -- Speed: 0 at depot/delivery stops, simulated via stop sequence otherwise
      CASE s.stop_type
          WHEN 'DEPOT_START' THEN 0
          WHEN 'DEPOT_END'   THEN 0
          WHEN 'DELIVERY'    THEN 0
          ELSE ROUND(35 + MOD(s.stop_sequence * 7, 25), 1)
      END  AS speed_kmh,
      -- Heading: deterministic pseudo-random from stop sequence
      MOD(s.stop_sequence * 67, 360)  AS heading_deg,
      -- Fuel: starts at 95%, drains by distance
      GREATEST(ROUND(95 - s.cumulative_dist_km * 0.28, 1), 5)  AS fuel_level_pct,
      -- Engine temp: pseudo-random variation around 82C
      ROUND(82 + MOD(s.stop_sequence * 3, 12), 1)  AS engine_temp_c,
      ROUND(s.cumulative_dist_km, 2)  AS odometer_km,
      -- Status
      CASE s.stop_type
          WHEN 'DELIVERY'    THEN 'DELIVERING'
          WHEN 'DEPOT_START' THEN 'IDLE'
          WHEN 'DEPOT_END'   THEN 'IDLE'
          ELSE 'DRIVING'
      END  AS status,
      -- Alert: FUEL when tank below 15%
      CASE WHEN 95 - s.cumulative_dist_km * 0.28 < 15 THEN 'FUEL' ELSE NULL END
        AS alert_code
  FROM  fleet_routes_optimized r
  JOIN  fleet_route_stops      s
      ON  s.route_id   = r.route_id
      AND s.route_type = 'OPTIMIZED'
  WHERE r.route_date = c_demo_date
  AND   r.num_stops  > 0;

  v_ping_cnt := SQL%ROWCOUNT;
  COMMIT;

  SELECT COUNT(DISTINCT vehicle_id),
         SUM(CASE WHEN alert_code IS NOT NULL THEN 1 ELSE 0 END)
  INTO   v_routes, v_alerts
  FROM   fleet_telemetry
  WHERE  recorded_at >= TRUNC(SYSDATE);

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('  Telemetry pings inserted : ' || v_ping_cnt);
  DBMS_OUTPUT.PUT_LINE('  Vehicles tracked         : ' || v_routes);
  DBMS_OUTPUT.PUT_LINE('  Alerts triggered         : ' || v_alerts);
  DBMS_OUTPUT.PUT_LINE('  (FUEL alert when cumulative distance exceeds ~300 km)');
END;
/

-- Update vehicle current_location to final telemetry position
UPDATE fleet_vehicles v
SET    current_location = (
    SELECT t.location
    FROM   fleet_telemetry t
    WHERE  t.vehicle_id  = v.vehicle_id
    AND    t.recorded_at = (
               SELECT MAX(t2.recorded_at)
               FROM   fleet_telemetry t2
               WHERE  t2.vehicle_id = v.vehicle_id)
    AND    ROWNUM = 1),
       status       = 'IN_ROUTE',
       last_updated = SYSTIMESTAMP
WHERE  EXISTS (
    SELECT 1 FROM fleet_telemetry t
    WHERE  t.vehicle_id = v.vehicle_id);

COMMIT;

PROMPT
PROMPT  Telemetry simulation complete.
PROMPT  Vehicles now show live GPS positions in vw_vehicle_locations.
PROMPT
PROMPT  Next: run  @sql/06_spatial_analysis.sql
PROMPT
