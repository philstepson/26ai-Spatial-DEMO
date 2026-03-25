-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 99_cleanup.sql
-- Purpose: Drop all demo objects – safe to re-run
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF

PROMPT Cleaning up Fleet Optimization demo objects...

BEGIN
  -- Drop SODA collection (optional step 8)
  DECLARE
    v_status NUMBER;
  BEGIN
    v_status := DBMS_SODA.drop_collection('fleet_orders_docs');
    IF v_status = 1 THEN
      DBMS_OUTPUT.PUT_LINE('  Dropped SODA collection: fleet_orders_docs');
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Drop views
  FOR v IN (SELECT view_name FROM user_views
            WHERE view_name LIKE 'VW_FLEET%'
               OR view_name LIKE 'ORDERS_DUALITY%') LOOP
    EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
    DBMS_OUTPUT.PUT_LINE('  Dropped view: ' || v.view_name);
  END LOOP;

  -- Drop tables (reverse FK order)
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN (
              'FLEET_TELEMETRY','FLEET_ROUTE_STOPS',
              'FLEET_ROUTES_OPTIMIZED','FLEET_ROUTES_BASELINE',
              'FLEET_ORDERS','FLEET_CUSTOMERS',
              'FLEET_VEHICLES','FLEET_DEPOTS','FLEET_TRAFFIC_ZONES'
            ) ORDER BY DECODE(table_name,
              'FLEET_TELEMETRY',1,'FLEET_ROUTE_STOPS',2,
              'FLEET_ROUTES_OPTIMIZED',3,'FLEET_ROUTES_BASELINE',4,
              'FLEET_ORDERS',5,'FLEET_CUSTOMERS',6,
              'FLEET_VEHICLES',7,'FLEET_DEPOTS',8,'FLEET_TRAFFIC_ZONES',9))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name
                      || ' CASCADE CONSTRAINTS PURGE';
    DBMS_OUTPUT.PUT_LINE('  Dropped table: ' || t.table_name);
  END LOOP;

  -- Remove spatial metadata
  DELETE FROM user_sdo_geom_metadata
  WHERE table_name IN (
    'FLEET_DEPOTS','FLEET_VEHICLES','FLEET_CUSTOMERS',
    'FLEET_ROUTES_BASELINE','FLEET_ROUTES_OPTIMIZED',
    'FLEET_ROUTE_STOPS','FLEET_TELEMETRY','FLEET_TRAFFIC_ZONES'
  );
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  Spatial metadata removed.');
  DBMS_OUTPUT.PUT_LINE('  Cleanup complete.');
END;
/

PROMPT Done.
