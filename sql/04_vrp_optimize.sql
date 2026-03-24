-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 04_vrp_optimize.sql
-- Purpose: Vehicle Routing Problem solver using Nearest-Neighbour heuristic
--          with time-window awareness and capacity constraints
--
--   Algorithm highlights:
--   1. Pre-sort orders by PRIORITY → TIME WINDOW OPEN
--   2. Cluster customers spatially to their nearest depot
--   3. For each vehicle: greedily pick the nearest FEASIBLE unvisited stop
--      (feasible = within time window AND within remaining capacity)
--   4. Store route VECTOR embeddings (Oracle 26ai AI Vector Search)
--   5. Calculate savings vs. baseline
--
-- Expected result  ~560–590 km  |  12 routes  |  ~$1,580 fuel cost
--                  ~32% distance saving  |  ~$730/day saved
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK ON

PROMPT
PROMPT ============================================================
PROMPT  Oracle 26ai | Fleet Spatial Optimization Demo
PROMPT  Step 4/7 : Running VRP Nearest-Neighbour Optimiser
PROMPT ============================================================
PROMPT

-- Clean previous run
DELETE FROM fleet_route_stops  WHERE route_type = 'OPTIMIZED';
DELETE FROM fleet_routes_optimized;
COMMIT;

DECLARE
  -- ----------------------------------------------------------------
  c_demo_date   CONSTANT DATE      := TRUNC(SYSDATE) + 1;
  c_route_start CONSTANT TIMESTAMP := TO_TIMESTAMP(
                    TO_CHAR(c_demo_date,'YYYY-MM-DD') || ' 06:30:00',
                    'YYYY-MM-DD HH24:MI:SS');
  c_avg_speed   CONSTANT NUMBER    := 38;   -- km/h (slightly higher – better routing)
  c_max_stops   CONSTANT NUMBER    := 8;    -- cap stops per vehicle
  c_max_payload CONSTANT NUMBER    := 9000; -- kg safety cap (under truck max)

  -- ----------------------------------------------------------------
  TYPE t_num_tab    IS TABLE OF NUMBER    INDEX BY PLS_INTEGER;
  TYPE t_ts_tab     IS TABLE OF TIMESTAMP INDEX BY PLS_INTEGER;
  TYPE t_bool_tab   IS TABLE OF BOOLEAN   INDEX BY PLS_INTEGER;
  TYPE t_str_tab    IS TABLE OF VARCHAR2(30) INDEX BY PLS_INTEGER;

  -- Order pool
  v_order_ids    t_num_tab;
  v_ord_lons     t_num_tab;
  v_ord_lats     t_num_tab;
  v_ord_svc      t_num_tab;
  v_ord_wopen    t_num_tab;   -- window open  (minutes from midnight)
  v_ord_wclose   t_num_tab;   -- window close
  v_ord_weight   t_num_tab;
  v_ord_priority t_num_tab;
  v_ord_depot    t_num_tab;   -- nearest depot assignment
  v_ord_served   t_bool_tab;  -- visited flag
  v_ord_cnt      PLS_INTEGER := 0;

  -- Vehicle pool
  v_veh_ids      t_num_tab;
  v_veh_depot    t_num_tab;
  v_dep_lons     t_num_tab;
  v_dep_lats     t_num_tab;
  v_fuel_km      t_num_tab;
  v_emit_km      t_num_tab;
  v_max_pay      t_num_tab;
  v_veh_cnt      PLS_INTEGER := 0;

  -- Route-level accumulators
  v_route_id     NUMBER;
  v_stop_seq     PLS_INTEGER;
  v_cur_lon      NUMBER;
  v_cur_lat      NUMBER;
  v_cur_time     TIMESTAMP;
  v_cum_dist     NUMBER;
  v_total_dist   NUMBER;
  v_total_min    NUMBER;
  v_payload_used NUMBER;
  v_best_idx     PLS_INTEGER;
  v_best_dist    NUMBER;
  v_dist         NUMBER;
  v_seg_min      NUMBER;
  v_arr_time     TIMESTAMP;
  v_dep_time     TIMESTAMP;
  v_arr_min      NUMBER;

  -- Savings
  v_base_km      NUMBER;
  v_base_cost    NUMBER;

  -- ----------------------------------------------------------------
  FUNCTION haversine(lon1 NUMBER, lat1 NUMBER,
                     lon2 NUMBER, lat2 NUMBER) RETURN NUMBER IS
    r CONSTANT NUMBER := 6371;
    dlat NUMBER := (lat2-lat1)*3.14159265/180;
    dlon NUMBER := (lon2-lon1)*3.14159265/180;
    a    NUMBER;
  BEGIN
    a := SIN(dlat/2)*SIN(dlat/2)
       + COS(lat1*3.14159265/180)*COS(lat2*3.14159265/180)
       * SIN(dlon/2)*SIN(dlon/2);
    RETURN r * 2 * ATAN2(SQRT(a), SQRT(1-a));
  END haversine;

  FUNCTION ts_to_min(p_ts TIMESTAMP) RETURN NUMBER IS
  BEGIN
    RETURN (EXTRACT(HOUR FROM p_ts)*60 + EXTRACT(MINUTE FROM p_ts));
  END ts_to_min;

  -- Generate a deterministic 128-float route fingerprint
  -- Based on: centroid, spread, total distance, stop count
  -- (In production this would use an ML embedding model via ONNX)
  FUNCTION make_route_vector(
      p_centroid_lon NUMBER, p_centroid_lat NUMBER,
      p_spread_km    NUMBER, p_total_km     NUMBER,
      p_num_stops    NUMBER, p_depot_id     NUMBER
  ) RETURN VECTOR IS
    -- Use associative array (no EXTEND, no SQL collection types)
    TYPE t_floats IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_vals t_floats;
    v_str  VARCHAR2(8000) := '[';
    v_base PLS_INTEGER;
  BEGIN
    -- Dimensions 1-8: spatial characteristics
    v_vals(1) := p_centroid_lon + 87.7;    -- normalise around Chicago
    v_vals(2) := p_centroid_lat - 41.9;
    v_vals(3) := p_spread_km / 50;
    v_vals(4) := p_total_km   / 200;
    v_vals(5) := p_num_stops  / 10;
    v_vals(6) := p_depot_id   / 3;
    v_vals(7) := SIN(p_centroid_lon * 0.1);
    v_vals(8) := COS(p_centroid_lat * 0.1);
    -- Dimensions 9-128: harmonic features (simulate learned embedding)
    FOR i IN 9..128 LOOP
      v_base    := MOD(i, 8) + 1;
      v_vals(i) := SIN(v_vals(v_base) * i * 0.31415)
                 * COS(v_vals(MOD(i,6)+1) * i * 0.27182);
    END LOOP;
    -- Build bracketed decimal string for TO_VECTOR
    -- FM format avoids scientific notation; 0 prefix avoids leading dot
    FOR i IN 1..128 LOOP
      IF i > 1 THEN v_str := v_str || ','; END IF;
      v_str := v_str || TO_CHAR(v_vals(i), 'FM999990.9999999');
    END LOOP;
    v_str := v_str || ']';
    RETURN TO_VECTOR(v_str, 128, FLOAT32);
  EXCEPTION WHEN OTHERS THEN RETURN NULL;
  END make_route_vector;

BEGIN
  -- ----------------------------------------------------------------
  -- Load vehicles
  -- ----------------------------------------------------------------
  FOR r IN (
    SELECT v.vehicle_id, v.depot_id, v.max_payload_kg,
           d.location.sdo_point.x  dep_lon,
           d.location.sdo_point.y  dep_lat,
           v.fuel_cost_per_km, v.emissions_kg_per_km
    FROM   fleet_vehicles v
    JOIN   fleet_depots   d ON d.depot_id = v.depot_id
    ORDER  BY v.depot_id, v.vehicle_id
  ) LOOP
    v_veh_cnt := v_veh_cnt + 1;
    v_veh_ids (v_veh_cnt) := r.vehicle_id;
    v_veh_depot(v_veh_cnt):= r.depot_id;
    v_dep_lons (v_veh_cnt):= r.dep_lon;
    v_dep_lats (v_veh_cnt):= r.dep_lat;
    v_fuel_km  (v_veh_cnt):= r.fuel_cost_per_km;
    v_emit_km  (v_veh_cnt):= r.emissions_kg_per_km;
    v_max_pay  (v_veh_cnt):= LEAST(r.max_payload_kg, c_max_payload);
  END LOOP;

  -- ----------------------------------------------------------------
  -- Load orders → sorted PRIORITY first, then time_window_open
  -- Assign each order to its nearest depot
  -- ----------------------------------------------------------------
  FOR r IN (
    SELECT o.order_id,
           c.location.sdo_point.x                  clon,
           c.location.sdo_point.y                  clat,
           NVL(c.service_minutes, 15)               svc,
           c.time_window_open                       twin_o,
           c.time_window_close                      twin_c,
           o.weight_kg,
           o.priority
    FROM   fleet_orders   o
    JOIN   fleet_customers c ON c.customer_id = o.customer_id
    WHERE  o.delivery_date = c_demo_date
    ORDER  BY o.priority, c.time_window_open, o.order_id
  ) LOOP
    v_ord_cnt := v_ord_cnt + 1;
    v_order_ids   (v_ord_cnt) := r.order_id;
    v_ord_lons    (v_ord_cnt) := r.clon;
    v_ord_lats    (v_ord_cnt) := r.clat;
    v_ord_svc     (v_ord_cnt) := r.svc;
    v_ord_wopen   (v_ord_cnt) := TRUNC(r.twin_o / 100) * 60
                                 + MOD(r.twin_o, 100);
    v_ord_wclose  (v_ord_cnt) := TRUNC(r.twin_c / 100) * 60
                                 + MOD(r.twin_c, 100);
    v_ord_weight  (v_ord_cnt) := r.weight_kg;
    v_ord_priority(v_ord_cnt) := r.priority;
    v_ord_served  (v_ord_cnt) := FALSE;

    -- Assign to nearest depot
    DECLARE
      v_near_depot PLS_INTEGER := 1;
      v_near_dist  NUMBER      := 99999;
      v_d          NUMBER;
    BEGIN
      FOR di IN 1..v_veh_cnt LOOP
        -- Only check first vehicle of each depot
        IF di = 1 OR v_veh_depot(di) != v_veh_depot(di-1) THEN
          v_d := haversine(r.clon, r.clat,
                           v_dep_lons(di), v_dep_lats(di));
          IF v_d < v_near_dist THEN
            v_near_dist  := v_d;
            v_near_depot := v_veh_depot(di);
          END IF;
        END IF;
      END LOOP;
      v_ord_depot(v_ord_cnt) := v_near_depot;
    END;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('  Orders sorted by priority+time: ' || v_ord_cnt);

  -- ----------------------------------------------------------------
  -- VRP: Nearest-Neighbour with time windows
  -- ----------------------------------------------------------------
  FOR v_idx IN 1..v_veh_cnt LOOP

    -- Start each vehicle at its depot
    v_stop_seq    := 0;
    v_cum_dist    := 0;
    v_total_dist  := 0;
    v_total_min   := 0;
    v_payload_used:= 0;
    v_cur_lon     := v_dep_lons(v_idx);
    v_cur_lat     := v_dep_lats(v_idx);
    v_cur_time    := c_route_start;

    -- Count feasible orders remaining for this vehicle's depot
    DECLARE v_avail NUMBER := 0; BEGIN
      FOR oi IN 1..v_ord_cnt LOOP
        IF NOT v_ord_served(oi)
           AND v_ord_depot(oi) = v_veh_depot(v_idx) THEN
          v_avail := v_avail + 1;
        END IF;
      END LOOP;
      IF v_avail = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  Vehicle ' || v_veh_ids(v_idx)
            || ': no unserved orders for this depot – skipping.');
        CONTINUE;
      END IF;
    END;

    -- Create route header
    INSERT INTO fleet_routes_optimized (
        vehicle_id, route_date, route_start,
        total_distance_km, total_time_min,
        total_fuel_liters, fuel_cost, co2_kg,
        num_stops, route_status, route_meta
    ) VALUES (
        v_veh_ids(v_idx), c_demo_date, c_route_start,
        0, 0, 0, 0, 0, 0, 'PLANNED',
        JSON('{"algorithm":"nearest_neighbour_tw","optimized":true}')
    ) RETURNING route_id INTO v_route_id;

    -- Depot start stop
    INSERT INTO fleet_route_stops (
        route_id, route_type, stop_sequence, stop_type, location,
        planned_arrival, planned_departure,
        distance_from_prev, cumulative_dist_km
    ) VALUES (
        v_route_id, 'OPTIMIZED', 0, 'DEPOT_START',
        SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(v_cur_lon,v_cur_lat,NULL),NULL,NULL),
        v_cur_time, v_cur_time, 0, 0
    );

    -- Greedy nearest feasible neighbour loop
    LOOP
      EXIT WHEN v_stop_seq >= c_max_stops;

      v_best_idx  := 0;
      v_best_dist := 999999;

      -- Find nearest unserved feasible order from this depot
      FOR oi IN 1..v_ord_cnt LOOP
        IF NOT v_ord_served(oi)
           AND v_ord_depot(oi) = v_veh_depot(v_idx)
           AND (v_payload_used + v_ord_weight(oi)) <= v_max_pay(v_idx)
        THEN
          v_dist    := haversine(v_cur_lon, v_cur_lat,
                                 v_ord_lons(oi), v_ord_lats(oi)) * 1.35;
          v_seg_min := (v_dist / c_avg_speed) * 60;
          v_arr_min := ts_to_min(v_cur_time) + v_seg_min;

          -- Time-window feasibility check
          IF v_arr_min <= v_ord_wclose(oi) THEN
            -- Priority boost: score = distance / (4 - priority)
            DECLARE v_score NUMBER;
            BEGIN
              v_score := v_dist / (4 - v_ord_priority(oi));
              IF v_score < v_best_dist THEN
                v_best_dist := v_score;
                v_best_idx  := oi;
              END IF;
            END;
          END IF;
        END IF;
      END LOOP;

      EXIT WHEN v_best_idx = 0;   -- no more feasible stops

      -- Commit to this stop
      v_stop_seq    := v_stop_seq + 1;
      v_dist        := haversine(v_cur_lon, v_cur_lat,
                                 v_ord_lons(v_best_idx),
                                 v_ord_lats(v_best_idx)) * 1.35;
      v_seg_min     := (v_dist / c_avg_speed) * 60;
      v_arr_time    := v_cur_time + v_dist/c_avg_speed/24;

      -- Respect time window: wait if arriving early
      DECLARE
        v_open_ts TIMESTAMP;
        v_open_min NUMBER := v_ord_wopen(v_best_idx);
      BEGIN
        v_open_ts := TRUNC(v_arr_time)
                     + v_open_min/1440;
        IF v_arr_time < v_open_ts THEN
          v_arr_time := v_open_ts;
        END IF;
      END;

      v_dep_time    := v_arr_time + v_ord_svc(v_best_idx)/60/24;
      v_cum_dist    := v_cum_dist + v_dist;

      INSERT INTO fleet_route_stops (
          route_id, route_type, stop_sequence, stop_type,
          order_id, location,
          planned_arrival, planned_departure,
          distance_from_prev, cumulative_dist_km
      ) VALUES (
          v_route_id, 'OPTIMIZED', v_stop_seq, 'DELIVERY',
          v_order_ids(v_best_idx),
          SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(v_ord_lons(v_best_idx),v_ord_lats(v_best_idx),NULL),NULL,NULL),
          v_arr_time, v_dep_time,
          ROUND(v_dist, 3), ROUND(v_cum_dist, 3)
      );

      UPDATE fleet_orders SET status = 'ASSIGNED'
      WHERE  order_id = v_order_ids(v_best_idx);

      v_total_dist   := v_total_dist + v_dist;
      v_total_min    := v_total_min  + v_seg_min + v_ord_svc(v_best_idx);
      v_payload_used := v_payload_used + v_ord_weight(v_best_idx);
      v_ord_served(v_best_idx) := TRUE;
      v_cur_lon      := v_ord_lons(v_best_idx);
      v_cur_lat      := v_ord_lats(v_best_idx);
      v_cur_time     := v_dep_time;

    END LOOP;

    -- Return to depot
    IF v_stop_seq > 0 THEN
      DECLARE
        v_ret_dist NUMBER;
        v_ret_min  NUMBER;
      BEGIN
        v_ret_dist   := haversine(v_cur_lon, v_cur_lat,
                                  v_dep_lons(v_idx),
                                  v_dep_lats(v_idx)) * 1.35;
        v_ret_min    := (v_ret_dist / c_avg_speed) * 60;
        v_arr_time   := v_cur_time + v_ret_dist/c_avg_speed/24;
        v_cum_dist   := v_cum_dist + v_ret_dist;
        v_total_dist := v_total_dist + v_ret_dist;
        v_total_min  := v_total_min  + v_ret_min;

        INSERT INTO fleet_route_stops (
            route_id, route_type, stop_sequence, stop_type, location,
            planned_arrival, planned_departure,
            distance_from_prev, cumulative_dist_km
        ) VALUES (
            v_route_id, 'OPTIMIZED', v_stop_seq + 1, 'DEPOT_END',
            SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(v_dep_lons(v_idx),v_dep_lats(v_idx),NULL),NULL,NULL),
            v_arr_time, v_arr_time,
            ROUND(v_ret_dist,3), ROUND(v_cum_dist,3)
        );
      END;
    END IF;

    -- Baseline for comparison
    SELECT NVL(SUM(total_distance_km),0), NVL(SUM(fuel_cost),0)
    INTO   v_base_km, v_base_cost
    FROM   fleet_routes_baseline
    WHERE  vehicle_id = v_veh_ids(v_idx)
    AND    route_date = c_demo_date;

    DECLARE
      v_fl   NUMBER := v_total_dist * 0.28;
      v_fc   NUMBER := v_total_dist * v_fuel_km(v_idx);
      v_co2  NUMBER := v_total_dist * v_emit_km(v_idx);
      v_sav_km   NUMBER := v_base_km   - v_total_dist;
      v_sav_cost NUMBER := v_base_cost - v_fc;
      v_sav_pct  NUMBER := CASE WHEN v_base_km > 0
                            THEN (v_base_km - v_total_dist)/v_base_km*100
                            ELSE 0 END;
      -- Route centroid for vector embedding
      v_clon NUMBER; v_clat NUMBER; v_spread NUMBER;
      v_rvec VECTOR(128, FLOAT32);
    BEGIN
      SELECT AVG(s.location.sdo_point.x),
             AVG(s.location.sdo_point.y)
      INTO   v_clon, v_clat
      FROM   fleet_route_stops s
      WHERE  s.route_id   = v_route_id
      AND    s.route_type = 'OPTIMIZED'
      AND    s.stop_type  = 'DELIVERY';

      v_spread := NVL(haversine(
                    NVL(v_clon, v_dep_lons(v_idx)),
                    NVL(v_clat, v_dep_lats(v_idx)),
                    v_dep_lons(v_idx), v_dep_lats(v_idx)), 5);

      -- Compute vector in PL/SQL first (local fn cannot be called in SQL)
      v_rvec := make_route_vector(
                  NVL(v_clon, v_dep_lons(v_idx)),
                  NVL(v_clat, v_dep_lats(v_idx)),
                  v_spread, v_total_dist,
                  v_stop_seq, v_veh_depot(v_idx));

      UPDATE fleet_routes_optimized SET
          route_end         = v_arr_time,
          total_distance_km = ROUND(v_total_dist, 3),
          total_time_min    = ROUND(v_total_min,  2),
          total_fuel_liters = ROUND(v_fl,   3),
          fuel_cost         = ROUND(v_fc,   2),
          co2_kg            = ROUND(v_co2,  3),
          num_stops         = v_stop_seq,
          savings_km        = ROUND(v_sav_km,   3),
          savings_cost      = ROUND(v_sav_cost, 2),
          savings_pct       = ROUND(v_sav_pct,  2),
          route_vector      = v_rvec
      WHERE route_id = v_route_id;

      DBMS_OUTPUT.PUT_LINE(
          '  Opt Route ' || v_route_id
          || ' (veh ' || v_veh_ids(v_idx) || ')'
          || '  stops=' || v_stop_seq
          || '  dist='  || ROUND(v_total_dist,1) || 'km'
          || '  saved=' || ROUND(v_sav_pct,1) || '%'
      );
    END;

  END LOOP;

  COMMIT;

  -- ----------------------------------------------------------------
  -- Final comparison
  -- ----------------------------------------------------------------
  DECLARE
    v_b_km   NUMBER; v_b_cost NUMBER; v_b_co2 NUMBER; v_b_veh NUMBER;
    v_o_km   NUMBER; v_o_cost NUMBER; v_o_co2 NUMBER; v_o_veh NUMBER;
  BEGIN
    SELECT COUNT(*), SUM(total_distance_km), SUM(fuel_cost), SUM(co2_kg)
    INTO   v_b_veh, v_b_km, v_b_cost, v_b_co2
    FROM   fleet_routes_baseline WHERE route_date = c_demo_date;

    SELECT COUNT(*), SUM(total_distance_km), SUM(fuel_cost), SUM(co2_kg)
    INTO   v_o_veh, v_o_km, v_o_cost, v_o_co2
    FROM   fleet_routes_optimized WHERE route_date = c_demo_date;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  ╔═══════════════════════════════════════════════╗');
    DBMS_OUTPUT.PUT_LINE('  ║   BEFORE vs. AFTER – VRP OPTIMISATION         ║');
    DBMS_OUTPUT.PUT_LINE('  ╠════════════════════╦══════════╦═══════════════╣');
    DBMS_OUTPUT.PUT_LINE('  ║ Metric             ║ Baseline ║   Optimised   ║');
    DBMS_OUTPUT.PUT_LINE('  ╠════════════════════╬══════════╬═══════════════╣');
    DBMS_OUTPUT.PUT_LINE('  ║ Routes (vehicles)  ║    '
        || LPAD(v_b_veh,4) || '    ║      '
        || LPAD(v_o_veh,4) || '       ║');
    DBMS_OUTPUT.PUT_LINE('  ║ Total distance km  ║  '
        || LPAD(ROUND(v_b_km,0),6) || '    ║    '
        || LPAD(ROUND(v_o_km,0),6) || '       ║');
    DBMS_OUTPUT.PUT_LINE('  ║ Fuel cost  USD/day ║ $'
        || LPAD(ROUND(v_b_cost,0),6) || '    ║   $'
        || LPAD(ROUND(v_o_cost,0),6) || '       ║');
    DBMS_OUTPUT.PUT_LINE('  ║ CO2 emitted  kg    ║  '
        || LPAD(ROUND(v_b_co2,0),6) || '    ║    '
        || LPAD(ROUND(v_o_co2,0),6) || '       ║');
    DBMS_OUTPUT.PUT_LINE('  ╠════════════════════╬══════════╩═══════════════╣');
    DBMS_OUTPUT.PUT_LINE('  ║ KM SAVED           ║  '
        || ROUND(v_b_km - v_o_km,0) || ' km  ('
        || ROUND((v_b_km-v_o_km)/v_b_km*100,1) || '%)           ║');
    DBMS_OUTPUT.PUT_LINE('  ║ COST SAVED / day   ║  $'
        || ROUND(v_b_cost - v_o_cost,0) || ' ('
        || ROUND((v_b_cost-v_o_cost)/v_b_cost*100,1) || '%)          ║');
    DBMS_OUTPUT.PUT_LINE('  ║ CO2 SAVED  kg/day  ║  '
        || ROUND(v_b_co2 - v_o_co2,0) || ' kg                     ║');
    DBMS_OUTPUT.PUT_LINE('  ║ ANNUALISED SAVING  ║  $'
        || ROUND((v_b_cost-v_o_cost)*250,0) || ' / year                ║');
    DBMS_OUTPUT.PUT_LINE('  ╚════════════════════╩════════════════════════════╝');
  END;

END;
/

PROMPT
PROMPT  VRP optimisation complete.
PROMPT  Route VECTOR embeddings stored for AI similarity search.
PROMPT
PROMPT  Next: run  @sql/05_telemetry_stream.sql
PROMPT
