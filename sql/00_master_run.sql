-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 00_master_run.sql
-- Purpose: Single entry-point – runs all 7 steps in sequence
--
-- IMPORTANT: Run 00_prereq_setup.sql as ADMIN first (one time only).
--            Then connect as fleet_demo before running this script.
--
-- Connect as fleet_demo:
--   SQL> SET CLOUDCONFIG wallet/Wallet_YourDB.zip
--   SQL> CONNECT fleet_demo/Fleet_Demo_2026#@yourdb_medium
--
-- Usage (SQLcl):
--   SQL> @sql/00_master_run.sql
--
-- Or step-by-step (recommended for first run so you can review output):
--   @sql/01_create_schema.sql
--   @sql/02_seed_data.sql
--   @sql/03_baseline_routes.sql
--   @sql/04_vrp_optimize.sql
--   @sql/05_telemetry_stream.sql
--   @sql/06_spatial_analysis.sql
--   @sql/07_report.sql
-- ============================================================================

PROMPT
PROMPT ╔══════════════════════════════════════════════════════════════════╗
PROMPT ║      Oracle 26ai │ Fleet Spatial VRP Optimization Demo          ║
PROMPT ║      Full End-to-End Run  (00_master_run.sql)                   ║
PROMPT ╚══════════════════════════════════════════════════════════════════╝
PROMPT

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

-- Step 1: Schema
PROMPT [1/7] Creating schema...
@@01_create_schema.sql

-- Step 2: Seed data
PROMPT [2/7] Seeding reference data...
@@02_seed_data.sql

-- Step 3: Baseline (unoptimised) routes
PROMPT [3/7] Generating baseline routes...
@@03_baseline_routes.sql

-- Step 4: VRP optimisation
PROMPT [4/7] Running VRP optimiser...
@@04_vrp_optimize.sql

-- Step 5: Telemetry stream
PROMPT [5/7] Simulating telemetry stream...
@@05_telemetry_stream.sql

-- Step 6: Spatial analysis queries
PROMPT [6/7] Running spatial analysis...
@@06_spatial_analysis.sql

-- Step 7: Final report
PROMPT [7/7] Generating executive report...
@@07_report.sql

PROMPT
PROMPT ╔══════════════════════════════════════════════════════════════════╗
PROMPT ║  All 7 steps completed successfully!                            ║
PROMPT ║  Run @sql/99_cleanup.sql when done to remove demo objects.      ║
PROMPT ╚══════════════════════════════════════════════════════════════════╝
PROMPT
