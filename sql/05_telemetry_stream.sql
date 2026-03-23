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
  c_demo_date CONSTANT DATE      := TRUNC(SYSDATE) + 1;
  c_ping_min  CONSTANT NUMBER    := 5;     -- ping every 5 minutes

  v_ping_ts   TIMESTAMP;
  v_lon       NUMBER;
  v_lat       NUMBER;
  v_prev_lon  NUMBER;
  v_prev_lat  NUMBER;
  v_speed     NUMBER;
  v_heading   NUMBER;
  v_fuel_lvl  NUMBER;
  v_eng_temp  NUMBER;
  v_odometer  NUMBER;
  v_status    VARCHAR2(30);
  v_alert     VARCHAR2(10);
  v_ping_cnt  NUMBER := 0;

  FUNCTION lerp(a NUMBER, b NUMBER, t NUMBER) RETURN NUMBER IS
  BEGIN RETURN a + (b - a) * t; END;

  FUNCTION haversine(lon1 NUMBER, lat1 NUMBER,
                     lon2 NUMBER, lat2 NUMBER) RETURN NUMBER IS
    r  CONSTANT NUMBER := 6371;
    dl NUMBER := (lat2-lat1)*3.14159265/180;
    dlo NUMBER := (lon2-lon1)*3.14159265/180;
    a NUMBER;
  BEGIN
    a := SIN(dl/2)*SIN(dl/2)
       + COS(lat1*3.14159265/180)*COS(lat2*3.14159265/180)
       * SIN(dlo/2)*SIN(dlo/2);
    RETURN r*2*ATAN2(SQRT(a),SQRT(1-a));
  END;

  FUNCTION bearing(lon1 NUMBER, lat1 NUMBER,
                   lon2 NUMBER, lat2 NUMBER) RETURN NUMBER IS
    pi  CONSTANT NUMBER := 3.14159265;
    la1 NUMBER := lat1*pi/180;
    la2 NUMBER := lat2*pi/180;
    dlo NUMBER := (lon2-lon1)*pi/180;
    x   NUMBER := SIN(dlo)*COS(la2);
    y   NUMBER := COS(la1)*SIN(la2) - SIN(la1)*COS(la2)*COS(dlo);
    b   NUMBER := ATAN2(x,y)*180/pi;
  BEGIN RETURN MOD(b+360,360); END;

BEGIN
  -- Iterate over every optimised route
  FOR route_rec IN (
    SELECT r.route_id, r.vehicle_id,
           r.route_start,
           r.total_distance_km,
           v.depot_id
    FROM   fleet_routes_optimized r
    JOIN   fleet_vehicles         v ON v.vehicle_id = r.vehicle_id
    WHERE  r.route_date = c_demo_date
    AND    r.num_stops  > 0
    ORDER  BY r.route_id
  ) LOOP

    v_odometer := 0;
    v_fuel_lvl := 95 + DBMS_RANDOM.VALUE(-5, 5);  -- start ~95% full

    -- Iterate through sequential stop pairs
    FOR seg_rec IN (
      SELECT s1.stop_sequence              seq_from,
             s1.location.sdo_point.x      lon_from,
             s1.location.sdo_point.y      lat_from,
             s1.planned_departure         dep_from,
             s2.location.sdo_point.x      lon_to,
             s2.location.sdo_point.y      lat_to,
             s2.planned_arrival           arr_to,
             s2.stop_type                 next_type
      FROM   fleet_route_stops s1
      JOIN   fleet_route_stops s2
          ON s2.route_id   = s1.route_id
         AND s2.route_type = s1.route_type
         AND s2.stop_sequence = s1.stop_sequence + 1
      WHERE  s1.route_id   = route_rec.route_id
      AND    s1.route_type = 'OPTIMIZED'
      ORDER  BY s1.stop_sequence
    ) LOOP

      v_prev_lon := seg_rec.lon_from;
      v_prev_lat := seg_rec.lat_from;
      v_ping_ts  := seg_rec.dep_from;

      -- Insert pings along this segment
      DECLARE
        v_seg_dist    NUMBER;
        v_seg_min     NUMBER;
        v_elapsed_min NUMBER := 0;
        v_t           NUMBER;
      BEGIN
        v_seg_dist := haversine(seg_rec.lon_from, seg_rec.lat_from,
                                seg_rec.lon_to,   seg_rec.lat_to);
        v_seg_min  := EXTRACT(MINUTE FROM (seg_rec.arr_to - seg_rec.dep_from))
                    + EXTRACT(HOUR   FROM (seg_rec.arr_to - seg_rec.dep_from)) * 60;
        IF v_seg_min <= 0 THEN v_seg_min := 10; END IF;

        WHILE v_elapsed_min < v_seg_min LOOP
          v_t   := LEAST(v_elapsed_min / v_seg_min, 1.0);
          v_lon := lerp(seg_rec.lon_from, seg_rec.lon_to, v_t);
          v_lat := lerp(seg_rec.lat_from, seg_rec.lat_to, v_t);

          -- Simulate realistic speed (slower near stops, faster on segments)
          IF v_t < 0.1 OR v_t > 0.9 THEN
            v_speed := DBMS_RANDOM.VALUE(10, 25);   -- near stop
          ELSIF v_t > 0.3 AND v_t < 0.7 THEN
            v_speed := DBMS_RANDOM.VALUE(35, 65);   -- mid-segment
          ELSE
            v_speed := DBMS_RANDOM.VALUE(20, 45);
          END IF;

          v_heading   := bearing(v_prev_lon, v_prev_lat, v_lon, v_lat);
          v_odometer  := v_odometer + v_seg_dist * (c_ping_min / v_seg_min);
          v_fuel_lvl  := GREATEST(v_fuel_lvl - (v_seg_dist * 0.28 / 50), 5);
          v_eng_temp  := 82 + DBMS_RANDOM.VALUE(-3, 12);
          v_status    := CASE WHEN v_speed < 5 THEN 'IDLE' ELSE 'DRIVING' END;
          v_alert     := NULL;

          -- Occasional alerts
          IF v_fuel_lvl < 15 THEN v_alert := 'FUEL'; END IF;
          IF v_eng_temp > 95  THEN v_alert := 'TEMP'; END IF;
          IF v_speed > 90     THEN v_alert := 'SPD';  END IF;

          INSERT INTO fleet_telemetry (
              vehicle_id, recorded_at, location,
              speed_kmh, heading_deg, fuel_level_pct,
              engine_temp_c, odometer_km, status, alert_code
          ) VALUES (
              route_rec.vehicle_id,
              v_ping_ts,
              SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(v_lon,v_lat,NULL),NULL,NULL),
              ROUND(v_speed, 1),
              ROUND(v_heading, 1),
              ROUND(v_fuel_lvl, 1),
              ROUND(v_eng_temp, 1),
              ROUND(v_odometer, 2),
              v_status,
              v_alert
          );

          v_ping_cnt    := v_ping_cnt + 1;
          v_prev_lon    := v_lon;
          v_prev_lat    := v_lat;
          v_ping_ts     := v_ping_ts + c_ping_min/1440;
          v_elapsed_min := v_elapsed_min + c_ping_min;
        END LOOP;
      END;

      -- Insert a "DELIVERING" ping at the stop itself
      IF seg_rec.next_type = 'DELIVERY' THEN
        INSERT INTO fleet_telemetry (
            vehicle_id, recorded_at, location,
            speed_kmh, heading_deg, fuel_level_pct,
            engine_temp_c, odometer_km, status, alert_code
        ) VALUES (
            route_rec.vehicle_id,
            seg_rec.arr_to,
            SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(
                seg_rec.lon_to, seg_rec.lat_to, NULL),NULL,NULL),
            0, v_heading, ROUND(v_fuel_lvl,1),
            ROUND(80 + DBMS_RANDOM.VALUE(0,5),1),
            ROUND(v_odometer,2),
            'DELIVERING', NULL
        );
        v_ping_cnt := v_ping_cnt + 1;
      END IF;

    END LOOP;  -- segments

  END LOOP;  -- routes

  COMMIT;

  DECLARE
    v_routes  NUMBER; v_alerts NUMBER;
  BEGIN
    SELECT COUNT(DISTINCT vehicle_id), SUM(CASE WHEN alert_code IS NOT NULL THEN 1 ELSE 0 END)
    INTO   v_routes, v_alerts
    FROM   fleet_telemetry
    WHERE  recorded_at >= TRUNC(SYSDATE);

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  Telemetry pings inserted : ' || v_ping_cnt);
    DBMS_OUTPUT.PUT_LINE('  Vehicles tracked         : ' || v_routes);
    DBMS_OUTPUT.PUT_LINE('  Alerts triggered         : ' || v_alerts);
    DBMS_OUTPUT.PUT_LINE('  (FUEL / TEMP / SPD alerts)');
  END;
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
