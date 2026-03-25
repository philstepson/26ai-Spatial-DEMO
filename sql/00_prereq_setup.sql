-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 00_prereq_setup.sql
-- Purpose: ONE-TIME setup — run as ADMIN before anything else
--
-- This script creates the fleet_demo user and grants all required privileges.
-- After running this script, reconnect as fleet_demo and run 00_master_run.sql.
--
-- Usage (run as ADMIN):
--   SQL> SET CLOUDCONFIG wallet/Wallet_YourDB.zip
--   SQL> CONNECT admin/YourAdminPassword@yourdb_medium
--   SQL> @sql/00_prereq_setup.sql
--
-- Then reconnect as fleet_demo:
--   SQL> CONNECT fleet_demo/Fleet_Demo_2026#@yourdb_medium
-- ============================================================================

PROMPT
PROMPT ╔══════════════════════════════════════════════════════════════════╗
PROMPT ║   Oracle 26ai │ Fleet Demo – Prerequisite Setup (as ADMIN)      ║
PROMPT ╚══════════════════════════════════════════════════════════════════╝
PROMPT

-- ----------------------------------------------------------------------------
-- Step 1: Create the fleet_demo user
-- NOTE: Change the password 'Fleet_Demo_2026#' before running in production.
-- ----------------------------------------------------------------------------
PROMPT [1/5] Creating user fleet_demo...

DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM dba_users WHERE username = 'FLEET_DEMO';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE q'[CREATE USER fleet_demo IDENTIFIED BY "Fleet_Demo_2026#"]';
    DBMS_OUTPUT.PUT_LINE('  --> User fleet_demo created.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  --> User fleet_demo already exists. Skipping CREATE USER.');
  END IF;
END;
/

PROMPT [1/5] Done.
PROMPT

-- ----------------------------------------------------------------------------
-- Step 2: Grant core connection and resource privileges
-- ----------------------------------------------------------------------------
PROMPT [2/5] Granting CONNECT, RESOURCE, UNLIMITED TABLESPACE...
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO fleet_demo;
PROMPT [2/5] Done.
PROMPT

-- ----------------------------------------------------------------------------
-- Step 3: Grant CREATE VIEW (needed for JSON Duality view)
-- ----------------------------------------------------------------------------
PROMPT [3/5] Granting CREATE VIEW...
GRANT CREATE VIEW TO fleet_demo;
PROMPT [3/5] Done.
PROMPT

-- ----------------------------------------------------------------------------
-- Step 4: Grant SODA_APP (needed for MongoDB-compatible JSON / SODA API)
-- ----------------------------------------------------------------------------
PROMPT [4/5] Granting SODA_APP...
GRANT SODA_APP TO fleet_demo;
PROMPT [4/5] Done.
PROMPT

-- ----------------------------------------------------------------------------
-- Step 5: Grant DB_DEVELOPER_ROLE (required for JSON Relational Duality Views
--         and other Oracle 23ai/26ai developer features)
-- ----------------------------------------------------------------------------
PROMPT [5/5] Granting DB_DEVELOPER_ROLE...
GRANT DB_DEVELOPER_ROLE TO fleet_demo;
PROMPT [5/5] Done.
PROMPT

PROMPT ╔══════════════════════════════════════════════════════════════════╗
PROMPT ║  Prerequisite setup complete!                                    ║
PROMPT ║                                                                  ║
PROMPT ║  Next step — reconnect as fleet_demo:                           ║
PROMPT ║    CONNECT fleet_demo/Fleet_Demo_2026#@yourdb_medium            ║
PROMPT ║                                                                  ║
PROMPT ║  Then run the demo:                                              ║
PROMPT ║    @sql/00_master_run.sql                                        ║
PROMPT ╚══════════════════════════════════════════════════════════════════╝
PROMPT
