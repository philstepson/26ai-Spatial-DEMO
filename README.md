# Oracle 26ai – Fleet Spatial VRP Optimization Demo

A hands-on engineer demo showcasing **Oracle 26ai** on **Autonomous Data Warehouse (ADW)**,
featuring real-world spatial data, Vehicle Routing Problem (VRP) optimization,
AI Vector Search, JSON Relational Duality, and live telemetry — all runnable from VSCode
via the **SQLcl extension** (also usable as an **MCP server**).

---

## What the demo does

| Step | Script | Description |
|------|--------|-------------|
| 1 | `01_create_schema.sql` | Creates 9 tables, 3 views (incl. JSON Duality), spatial + VECTOR indexes |
| 2 | `02_seed_data.sql` | Seeds 3 Chicago depots, 15 vehicles, 50 customers, 75 orders, 5 traffic zones |
| 3 | `03_baseline_routes.sql` | Simulates **naive** route assignment — criss-crossing, no clustering |
| 4 | `04_vrp_optimize.sql` | Runs **VRP nearest-neighbour** heuristic with time-windows & capacity |
| 5 | `05_telemetry_stream.sql` | Generates real-time GPS pings every 5 min along optimised routes |
| 6 | `06_spatial_analysis.sql` | 9 showcase queries: SDO_NN, SDO_WITHIN_DISTANCE, VECTOR_DISTANCE, JSON |
| 7 | `07_report.sql` | Executive before/after report, annualised ROI |

### Expected results

| Metric            |  Baseline | Optimised |    Saving   |
|-------------------|--------=--|-----------|-------------|
| Routes (vehicles) |        15 |        12 | –3 vehicles |
| Total distance    |   ~855 km |   ~575 km |    **~33%** |
| Fuel cost / day   |   ~$2,420 |   ~$1,625 |**~$795/day**|
| CO2 / day         | ~230 kg   |   ~155 kg |      ~75 kg |
| **Annual saving** |           |           |**~$199,000**|

---

## Oracle 26ai Features Showcased

| Feature | Used in |
|---------|---------|
| `SDO_GEOMETRY` – points, lines, polygons | All spatial tables |
| `SPATIAL_INDEX_V2` | 8 spatial indexes |
| `SDO_WITHIN_DISTANCE`, `SDO_NN`, `SDO_GEOM.SDO_DISTANCE` | `06_spatial_analysis.sql` |
| `VECTOR(128, FLOAT32)` – route fingerprints | `fleet_routes_optimized` |
| HNSW Vector Index + `VECTOR_DISTANCE(COSINE)` | Q6 in analysis script |
| Native `JSON` columns | All major tables |
| **JSON Relational Duality View** | `orders_duality` |
| Range Partitioning (timestamp) | `fleet_telemetry` |
| PL/SQL – VRP heuristic, Haversine | `04_vrp_optimize.sql` |

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Oracle ADW | 23ai / 26ai | Any Always Free or paid ADW works |
| SQLcl | 24.1+ | `sql --version` to check |
| Java | 11+ | Required by SQLcl |
| VSCode | 1.85+ | |
| Oracle Developer Tools for VSCode | latest | Extension ID: `oracle.oracle-developer-tools-for-vscode` |
| Draw.io VSCode | optional | Extension ID: `hediet.vscode-drawio` |

---

## Setup

### 1 · Provision an Autonomous Database

1. Log in to **OCI Console** → **Oracle Database** → **Autonomous Database**
2. Create a new **ADW** instance (Always Free is sufficient)
3. Note your **DB name** and choose a strong **ADMIN password**

### 2 · Create a demo user (run as ADMIN)

```sql
-- Connect as ADMIN first, then:
CREATE USER fleet_demo IDENTIFIED BY "YourSecureP@ssword1!";
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO fleet_demo;
GRANT CREATE VIEW TO fleet_demo;
-- Required for Oracle Spatial
GRANT EXECUTE ON MDSYS.SDO_GEOM TO fleet_demo;
-- Required for JSON Duality (Oracle 23ai/26ai)
GRANT DB_DEVELOPER_ROLE TO fleet_demo;
```

### 3 · Download and place your wallet

1. In OCI Console → your ADW → **Database Connection** → **Download Wallet**
2. Save the ZIP as `wallet/Wallet_YourDB.zip` in this project folder
3. The `wallet/` directory is git-ignored

### 4 · Configure your connection

```bash
cp config/connection.properties.template config/connection.properties
# Edit config/connection.properties with your wallet path, username, password, service name
```

---

## Running the Demo

### Option A — VSCode SQLcl Extension (recommended)

1. Open this folder in VSCode: `code .`
2. Install recommended extensions when prompted (`.vscode/extensions.json`)
3. Open **Oracle Explorer** panel (sidebar)
4. **Add Connection** → Cloud Wallet → select `wallet/Wallet_YourDB.zip`
5. Enter `fleet_demo` / your password / service name `yourdb_medium`
6. Open `sql/01_create_schema.sql` → right-click → **Run in SQLcl**
7. Proceed through scripts `02` → `07` in order

### Option B — SQLcl Command Line

```bash
# Navigate to this directory
cd /path/to/26ai-Spatial-DEMO

# Connect with wallet
sql /nolog
SQL> SET CLOUDCONFIG wallet/Wallet_YourDB.zip
SQL> CONNECT fleet_demo/YourSecureP@ssword1!@yourdb_medium

# Run the full demo end-to-end
SQL> @sql/00_master_run.sql

# Or step by step:
SQL> @sql/01_create_schema.sql
SQL> @sql/02_seed_data.sql
SQL> @sql/03_baseline_routes.sql
SQL> @sql/04_vrp_optimize.sql
SQL> @sql/05_telemetry_stream.sql
SQL> @sql/06_spatial_analysis.sql
SQL> @sql/07_report.sql
```

### Option C — Claude + SQLcl MCP Server

This lets Claude query your database directly via natural language.

1. Start the SQLcl MCP server:
   ```bash
   sql /nolog -mcp
   ```

2. Add the MCP server config to **Claude Desktop** (`~/.config/claude/claude_desktop_config.json`)
   or **VSCode MCP settings** — see `config/mcp_servers.json` for the config block.

3. In Claude, connect:
   ```
   SET CLOUDCONFIG /path/to/wallet/Wallet_YourDB.zip
   CONNECT fleet_demo/password@yourdb_medium
   ```

4. Ask Claude to:
   - *"Run the VRP demo from scratch"*
   - *"Show me the before/after cost comparison"*
   - *"Find routes similar to route #3 using vector search"*
   - *"Which vehicles are currently inside the CBD zone?"*

---

## Project Structure

```
26ai-Spatial-DEMO/
├── README.md                        ← You are here
├── architecture.drawio              ← System architecture diagram
├── .gitignore
├── .vscode/
│   ├── extensions.json              ← Recommended extensions
│   └── settings.json                ← SQLcl connection profile
├── config/
│   ├── connection.properties.template
│   └── mcp_servers.json             ← MCP server config block
├── wallet/
│   ├── README.md                    ← How to get your wallet
│   └── Wallet_YourDB.zip            ← YOUR WALLET (git-ignored)
└── sql/
    ├── 00_master_run.sql            ← Run everything at once
    ├── 01_create_schema.sql         ← DDL + indexes + views
    ├── 02_seed_data.sql             ← 50 customers, 15 vehicles, 75 orders
    ├── 03_baseline_routes.sql       ← Naive route simulation
    ├── 04_vrp_optimize.sql          ← VRP nearest-neighbour + VECTOR embed
    ├── 05_telemetry_stream.sql      ← Simulated GPS telemetry
    ├── 06_spatial_analysis.sql      ← 9 showcase spatial + AI queries
    ├── 07_report.sql                ← Executive before/after report
    └── 99_cleanup.sql               ← Drop all demo objects
```

---

## Architecture Diagram

Open `architecture.drawio` in VSCode with the **Draw.io** extension or at
[app.diagrams.net](https://app.diagrams.net) (File → Open from → Device).

The diagram shows three swim lanes:
- **Developer Tooling**: VSCode ↔ SQLcl Extension ↔ MCP Server ↔ Claude AI
- **Oracle 26ai ADW**: All tables, indexes, views, and engine capabilities
- **Data Flow**: 6-step pipeline from seed data to ROI results

---

## Cleanup

```sql
@sql/99_cleanup.sql
```

Drops all `fleet_*` tables, views, indexes, and spatial metadata. Safe to re-run.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ORA-29532: Java call terminated by uncaught Java exception` | SQLcl version too old — upgrade to 24.1+ |
| `ORA-13226: interface not supported without a spatial index` | Run `01_create_schema.sql` first to build indexes |
| `ORA-00904: "VECTOR": invalid identifier` | Database is not 23ai/26ai — check `SELECT BANNER FROM v$version` |
| Wallet connection fails | Check `wallet/tnsnames.ora` for correct service names |
| `ORA-01950: no privileges on tablespace USERS` | `GRANT UNLIMITED TABLESPACE TO fleet_demo;` as ADMIN |
| JSON Duality view fails | `GRANT DB_DEVELOPER_ROLE TO fleet_demo;` as ADMIN |

---

## License

Demo code. Free to use for learning and demonstrations.
Oracle Database, SQLcl, and associated trademarks are property of Oracle Corporation.
