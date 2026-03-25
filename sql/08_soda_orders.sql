-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 08_soda_orders.sql
-- Purpose: Create a SODA collection (fleet_orders_docs) populated from the
--          relational fleet_orders table.
--          Exposes order data as MongoDB-compatible JSON documents so that
--          MongoDB Compass (or any MongoDB driver) can query them directly,
--          demonstrating Oracle 26ai as a native multi-model database.
--
-- Run AFTER: 00_master_run.sql  (needs seed data + optimised routes)
-- Run from : SQLcl  @sql/08_soda_orders.sql
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK ON

PROMPT
PROMPT ============================================================
PROMPT  Oracle 26ai | Fleet Spatial Optimization Demo
PROMPT  Step 8 (optional) : MongoDB-compatible SODA Collection
PROMPT  -- Demonstrates Oracle as a multi-model database --
PROMPT ============================================================
PROMPT

DECLARE
  v_collection  SODA_COLLECTION_T;
  v_document    SODA_DOCUMENT_T;
  v_status      NUMBER;
  v_count       NUMBER := 0;
  v_json        CLOB;

  -- Format NUMBER(4) time window (e.g. 0830) as HH:MM string
  FUNCTION fmt_time(p_t NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN LPAD(FLOOR(NVL(p_t,0) / 100), 2, '0')
        || ':'
        || LPAD(MOD(NVL(p_t,0), 100), 2, '0');
  END fmt_time;

BEGIN

  -- ── Drop collection if it already exists ──────────────────────────────
  v_status := DBMS_SODA.drop_collection('fleet_orders_docs');
  IF v_status = 1 THEN
    DBMS_OUTPUT.PUT_LINE('  Existing collection dropped.');
  END IF;

  -- ── Create fresh collection ────────────────────────────────────────────
  v_collection := DBMS_SODA.create_collection('fleet_orders_docs');
  DBMS_OUTPUT.PUT_LINE('  Collection fleet_orders_docs created.');
  DBMS_OUTPUT.PUT_LINE('  Inserting order documents...');

  -- ── One document per order ─────────────────────────────────────────────
  FOR r IN (
    SELECT
        o.order_id,
        o.order_ref,
        o.status,
        o.priority,
        CASE o.priority
            WHEN 1 THEN 'URGENT'
            WHEN 2 THEN 'HIGH'
            ELSE        'NORMAL'
        END                                          AS priority_label,
        TO_CHAR(o.delivery_date, 'YYYY-MM-DD')       AS delivery_date,
        o.weight_kg,
        o.volume_m3,
        NVL(o.delivery_notes, 'None')                AS delivery_notes,
        -- Customer details
        c.customer_name,
        c.neighborhood,
        c.city,
        c.address,
        c.contact_phone,
        fmt_time(c.time_window_open)                 AS tw_open,
        fmt_time(c.time_window_close)                AS tw_close,
        c.service_minutes
    FROM  fleet_orders    o
    JOIN  fleet_customers c ON c.customer_id = o.customer_id
    ORDER BY o.order_id
  ) LOOP

    v_json :=
      JSON_OBJECT(
        'order_id'       VALUE r.order_id,
        'order_ref'      VALUE r.order_ref,
        'status'         VALUE r.status,
        'priority'       VALUE r.priority,
        'priority_label' VALUE r.priority_label,
        'delivery_date'  VALUE r.delivery_date,
        'weight_kg'      VALUE r.weight_kg,
        'volume_m3'      VALUE r.volume_m3,
        'delivery_notes' VALUE r.delivery_notes,
        'customer' VALUE
          JSON_OBJECT(
            'name'            VALUE r.customer_name,
            'neighborhood'    VALUE r.neighborhood,
            'city'            VALUE r.city,
            'address'         VALUE r.address,
            'contact_phone'   VALUE r.contact_phone,
            'time_window'     VALUE r.tw_open || ' - ' || r.tw_close,
            'service_minutes' VALUE r.service_minutes
            ABSENT ON NULL
          )
        ABSENT ON NULL
      );

    v_document := SODA_DOCUMENT_T(b_content => UTL_RAW.cast_to_raw(v_json));
    v_status   := v_collection.insert_one(v_document);
    v_count    := v_count + 1;

  END LOOP;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('  Documents inserted : ' || v_count);
  DBMS_OUTPUT.PUT_LINE('  Collection name    : fleet_orders_docs');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('  Connect MongoDB Compass to Oracle 26ai ADW and');
  DBMS_OUTPUT.PUT_LINE('  browse fleet_orders_docs to query orders as JSON.');
  DBMS_OUTPUT.PUT_LINE('  Same data, same instance, two APIs.');

END;
/

PROMPT
PROMPT  SODA collection ready.
PROMPT  In Compass: database = fleet_demo, collection = fleet_orders_docs
PROMPT
