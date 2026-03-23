-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 03_baseline_routes.sql
-- Purpose: Simulate NAIVE (unoptimised) route assignment
--
--   Algorithm: Round-robin order assignment → vehicles sorted by order_id.
--   No clustering, no time-window awareness, no capacity packing.
--   This produces realistic "bad" routes that criss-cross the city.
--
-- Expected result  ~840–870 km total  |  15 routes  |  ~$2,300 fuel cost
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK ON

PROMPT
PROMPT ============================================================
PROMPT  Oracle 26ai | Fleet Spatial Optimization Demo
PROMPT  Step 3/7 : Generating Baseline (Unoptimised) Routes
PROMPT ============================================================
PROMPT

-- Clean previous baseline run
DELETE FROM fleet_route_stops  WHERE route_type = 'BASELINE';
DELETE FROM fleet_routes_baseline;
COMMIT;

DECLARE
  -- ----------------------------------------------------------------
  -- Constants
  -- ----------------------------------------------------------------
  c_demo_date   CONSTANT DATE      := TRUNC(SYSDATE) + 1;
  c_route_start CONSTANT TIMESTAMP := TO_TIMESTAMP(
                    TO_CHAR(c_demo_date,'YYYY-MM-DD') || ' 07:00:00',
                    'YYYY-MM-DD HH24:MI:SS');
  c_avg_speed   CONSTANT NUMBER    := 35;   -- km/h (urban, mixed congestion)
  c_service_min CONSTANT NUMBER    := 15;   -- avg service time per stop (min)

  -- ----------------------------------------------------------------
  -- Types
  -- ----------------------------------------------------------------
  TYPE t_num_tab   IS TABLE OF NUMBER        INDEX BY PLS_INTEGER;
  TYPE t_date_tab  IS TABLE OF TIMESTAMP     INDEX BY PLS_INTEGER;

  -- ----------------------------------------------------------------
  -- Working variables
  -- ----------------------------------------------------------------
  v_vehicles      t_num_tab;     -- vehicle_ids in depot order
  v_depots        t_num_tab;     -- depot per vehicle
  v_depot_lons    t_num_tab;     -- depot longitude
  v_depot_lats    t_num_tab;     -- depot latitude
  v_orders        t_num_tab;     -- order_ids sorted by order_id (naive)
  v_cust_lons     t_num_tab;     -- customer lon per order
  v_cust_lats     t_num_tab;     -- customer lat per order
  v_cust_svc      t_num_tab;     -- service minutes per customer

  v_veh_cnt       PLS_INTEGER := 0;
  v_ord_cnt       PLS_INTEGER := 0;
  v_route_id      NUMBER;
  v_stop_seq      PLS_INTEGER;
  v_cum_dist      NUMBER;
  v_cur_time      TIMESTAMP;
  v_arr_time      TIMESTAMP;
  v_dep_time      TIMESTAMP;
  v_seg_dist      NUMBER;
  v_seg_min       NUMBER;
  v_total_dist    NUMBER;
  v_total_min     NUMBER;
  v_fuel_liters   NUMBER;
  v_fuel_cost     NUMBER;
  v_co2_kg        NUMBER;
  v_prev_lon      NUMBER;
  v_prev_lat      NUMBER;
  v_cur_lon       NUMBER;
  v_cur_lat       NUMBER;
  v_ord_id        NUMBER;
  v_fuel_per_km   NUMBER;
  v_emit_per_km   NUMBER;

  -- ----------------------------------------------------------------
  -- Haversine distance (km) between two WGS84 points
  -- ----------------------------------------------------------------
  FUNCTION haversine(p_lon1 NUMBER, p_lat1 NUMBER,
                     p_lon2 NUMBER, p_lat2 NUMBER) RETURN NUMBER IS
    c_r   CONSTANT NUMBER := 6371;      -- Earth radius km
    d_lat NUMBER := (p_lat2 - p_lat1) * 3.14159265358979 / 180;
    d_lon NUMBER := (p_lon2 - p_lon1) * 3.14159265358979 / 180;
    a     NUMBER;
    c     NUMBER;
  BEGIN
    a := SIN(d_lat/2)*SIN(d_lat/2)
       + COS(p_lat1*3.14159265358979/180)
       * COS(p_lat2*3.14159265358979/180)
       * SIN(d_lon/2)*SIN(d_lon/2);
    c := 2 * ATAN2(SQRT(a), SQRT(1-a));
    RETURN c_r * c;
  END haversine;

  -- ----------------------------------------------------------------
  -- Build a simple 2-point SDO LineString
  -- (full route path built incrementally via SDO_UTIL.APPEND)
  -- ----------------------------------------------------------------
  FUNCTION make_point(p_lon NUMBER, p_lat NUMBER) RETURN SDO_GEOMETRY IS
  BEGIN
    RETURN SDO_GEOMETRY(2001, 4326,
             SDO_POINT_TYPE(p_lon, p_lat, NULL), NULL, NULL);
  END make_point;

BEGIN
  -- ----------------------------------------------------------------
  -- Load vehicles (sorted: depot 1 first, then 2, then 3)
  -- ----------------------------------------------------------------
  DECLARE
    CURSOR c_veh IS
      SELECT v.vehicle_id, v.depot_id,
             SDO_GEOM.SDO_COORD_REF_SYS(v.current_location).x  -- workaround
               -- Actually: use depot location coordinates
      FROM fleet_vehicles v ORDER BY v.depot_id, v.vehicle_id;
  BEGIN
    FOR r IN (
      SELECT v.vehicle_id, v.depot_id,
             d.location.sdo_point.x AS dep_lon,
             d.location.sdo_point.y AS dep_lat,
             v.fuel_cost_per_km,
             v.emissions_kg_per_km
      FROM   fleet_vehicles v
      JOIN   fleet_depots   d ON d.depot_id = v.depot_id
      ORDER  BY v.depot_id, v.vehicle_id
    ) LOOP
      v_veh_cnt := v_veh_cnt + 1;
      v_vehicles(v_veh_cnt)   := r.vehicle_id;
      v_depots(v_veh_cnt)     := r.depot_id;
      v_depot_lons(v_veh_cnt) := r.dep_lon;
      v_depot_lats(v_veh_cnt) := r.dep_lat;
    END LOOP;
  END;

  -- ----------------------------------------------------------------
  -- Load orders (NAIVE: sorted by order_id only – not geographically)
  -- ----------------------------------------------------------------
  FOR r IN (
    SELECT o.order_id,
           c.location.sdo_point.x AS clon,
           c.location.sdo_point.y AS clat,
           NVL(c.service_minutes, 15) AS svc
    FROM   fleet_orders   o
    JOIN   fleet_customers c ON c.customer_id = o.customer_id
    WHERE  o.delivery_date = c_demo_date
    ORDER  BY o.order_id          -- <--- NAIVE: no geo clustering
  ) LOOP
    v_ord_cnt               := v_ord_cnt + 1;
    v_orders(v_ord_cnt)     := r.order_id;
    v_cust_lons(v_ord_cnt)  := r.clon;
    v_cust_lats(v_ord_cnt)  := r.clat;
    v_cust_svc(v_ord_cnt)   := r.svc;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('  Vehicles loaded: ' || v_veh_cnt);
  DBMS_OUTPUT.PUT_LINE('  Orders loaded  : ' || v_ord_cnt);

  -- ----------------------------------------------------------------
  -- Assign orders round-robin to vehicles (naive)
  -- ----------------------------------------------------------------
  FOR v_idx IN 1..v_veh_cnt LOOP

    -- Get vehicle cost params
    SELECT fuel_cost_per_km, emissions_kg_per_km
    INTO   v_fuel_per_km, v_emit_per_km
    FROM   fleet_vehicles WHERE vehicle_id = v_vehicles(v_idx);

    -- ---- Insert route header ----
    INSERT INTO fleet_routes_baseline (
        vehicle_id, route_date, route_start,
        total_distance_km, total_time_min,
        total_fuel_liters, fuel_cost, co2_kg,
        num_stops, route_status, route_meta
    ) VALUES (
        v_vehicles(v_idx), c_demo_date, c_route_start,
        0, 0, 0, 0, 0, 0, 'COMPLETED',
        JSON('{"algorithm":"round_robin_naive","optimized":false}')
    ) RETURNING route_id INTO v_route_id;

    -- ---- Depot start stop ----
    v_stop_seq  := 0;
    v_cum_dist  := 0;
    v_cur_time  := c_route_start;
    v_prev_lon  := v_depot_lons(v_idx);
    v_prev_lat  := v_depot_lats(v_idx);

    INSERT INTO fleet_route_stops (
        route_id, route_type, stop_sequence, stop_type,
        location, planned_arrival, planned_departure,
        distance_from_prev, cumulative_dist_km
    ) VALUES (
        v_route_id, 'BASELINE', 0, 'DEPOT_START',
        make_point(v_prev_lon, v_prev_lat),
        v_cur_time, v_cur_time, 0, 0
    );

    v_total_dist := 0;
    v_total_min  := 0;

    -- ---- Delivery stops – orders assigned to this vehicle ----
    --      Vehicle v_idx gets every v_veh_cnt-th order starting at v_idx
    FOR o_idx IN 1..v_ord_cnt LOOP
      IF MOD(o_idx - 1, v_veh_cnt) + 1 = v_idx THEN

        v_stop_seq := v_stop_seq + 1;
        v_cur_lon  := v_cust_lons(o_idx);
        v_cur_lat  := v_cust_lats(o_idx);

        -- Straight-line distance with urban factor (× 1.35)
        v_seg_dist := haversine(v_prev_lon, v_prev_lat,
                                v_cur_lon,  v_cur_lat) * 1.35;
        v_seg_min  := (v_seg_dist / c_avg_speed) * 60
                      + v_cust_svc(o_idx);

        v_arr_time := v_cur_time + v_seg_dist/c_avg_speed/24;
        v_dep_time := v_arr_time + v_cust_svc(o_idx)/60/24;
        v_cum_dist := v_cum_dist + v_seg_dist;

        INSERT INTO fleet_route_stops (
            route_id, route_type, stop_sequence, stop_type,
            order_id, location,
            planned_arrival, planned_departure,
            distance_from_prev, cumulative_dist_km
        ) VALUES (
            v_route_id, 'BASELINE', v_stop_seq, 'DELIVERY',
            v_orders(o_idx),
            make_point(v_cur_lon, v_cur_lat),
            v_arr_time, v_dep_time,
            ROUND(v_seg_dist, 3), ROUND(v_cum_dist, 3)
        );

        -- Update order status
        UPDATE fleet_orders SET status = 'ASSIGNED'
        WHERE  order_id = v_orders(o_idx);

        v_total_dist := v_total_dist + v_seg_dist;
        v_total_min  := v_total_min  + v_seg_min;
        v_prev_lon   := v_cur_lon;
        v_prev_lat   := v_cur_lat;
        v_cur_time   := v_dep_time;

      END IF;
    END LOOP;

    -- ---- Return to depot ----
    v_seg_dist := haversine(v_prev_lon, v_prev_lat,
                            v_depot_lons(v_idx),
                            v_depot_lats(v_idx)) * 1.35;
    v_seg_min  := (v_seg_dist / c_avg_speed) * 60;
    v_arr_time := v_cur_time + v_seg_dist/c_avg_speed/24;
    v_cum_dist := v_cum_dist + v_seg_dist;
    v_total_dist := v_total_dist + v_seg_dist;
    v_total_min  := v_total_min  + v_seg_min;

    INSERT INTO fleet_route_stops (
        route_id, route_type, stop_sequence, stop_type,
        location, planned_arrival, planned_departure,
        distance_from_prev, cumulative_dist_km
    ) VALUES (
        v_route_id, 'BASELINE', v_stop_seq + 1, 'DEPOT_END',
        make_point(v_depot_lons(v_idx), v_depot_lats(v_idx)),
        v_arr_time, v_arr_time,
        ROUND(v_seg_dist, 3), ROUND(v_cum_dist, 3)
    );

    -- ---- Fuel and emissions ----
    v_fuel_liters := v_total_dist * 0.28;   -- avg 28L/100km diesel equiv
    v_fuel_cost   := v_total_dist * v_fuel_per_km;
    v_co2_kg      := v_total_dist * v_emit_per_km;

    -- ---- Update route header with actuals ----
    UPDATE fleet_routes_baseline SET
        route_end         = v_arr_time,
        total_distance_km = ROUND(v_total_dist, 3),
        total_time_min    = ROUND(v_total_min,  2),
        total_fuel_liters = ROUND(v_fuel_liters, 3),
        fuel_cost         = ROUND(v_fuel_cost,   2),
        co2_kg            = ROUND(v_co2_kg,      3),
        num_stops         = v_stop_seq
    WHERE route_id = v_route_id;

    DBMS_OUTPUT.PUT_LINE(
        '  Route ' || v_route_id
        || ' (veh ' || v_vehicles(v_idx) || ')'
        || '  stops=' || v_stop_seq
        || '  dist='  || ROUND(v_total_dist,1) || 'km'
        || '  cost=$' || ROUND(v_fuel_cost,2)
    );

  END LOOP;

  COMMIT;

  -- ----------------------------------------------------------------
  -- Summary report
  -- ----------------------------------------------------------------
  DECLARE
    v_tot_km    NUMBER;
    v_tot_cost  NUMBER;
    v_tot_co2   NUMBER;
    v_tot_stops NUMBER;
  BEGIN
    SELECT SUM(total_distance_km), SUM(fuel_cost),
           SUM(co2_kg), SUM(num_stops)
    INTO   v_tot_km, v_tot_cost, v_tot_co2, v_tot_stops
    FROM   fleet_routes_baseline
    WHERE  route_date = c_demo_date;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  ======== BASELINE SUMMARY ========');
    DBMS_OUTPUT.PUT_LINE('  Routes        : ' || v_veh_cnt);
    DBMS_OUTPUT.PUT_LINE('  Total stops   : ' || v_tot_stops);
    DBMS_OUTPUT.PUT_LINE('  Total distance: ' || ROUND(v_tot_km,1) || ' km');
    DBMS_OUTPUT.PUT_LINE('  Fuel cost     : $' || ROUND(v_tot_cost,2));
    DBMS_OUTPUT.PUT_LINE('  CO2 emitted   : ' || ROUND(v_tot_co2,1) || ' kg');
    DBMS_OUTPUT.PUT_LINE('  ===================================');
  END;

END;
/

PROMPT
PROMPT  Baseline route simulation complete.
PROMPT  Run vw_route_comparison AFTER step 4 to see savings.
PROMPT
PROMPT  Next: run  @sql/04_vrp_optimize.sql
PROMPT
