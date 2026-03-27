# Oracle 26ai – Fleet Spatial VRP Optimization Demo

A hands-on engineer demo showcasing **Oracle 26ai** on **Autonomous Data Warehouse (ADW)**,
featuring real-world spatial data, Vehicle Routing Problem (VRP) optimization,
AI Vector Search, JSON Relational Duality, and live telemetry — all runnable from VSCode
via the **SQLcl extension** (also usable as an **MCP server**).

---

## What the demo does

| Step | Script | Description |
|------|--------|-------------|
| 0 | `00_prereq_setup.sql` | **Run as ADMIN once** — creates fleet_demo user + grants |
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

## Quick Start

> **Run in this exact order. Steps 0–1 are one-time setup; Steps 2–4 are the demo.**

### Step 0 · Provision an Autonomous Database

1. Log in to **OCI Console** → **Oracle Database** → **Autonomous Database**
2. Create a new **ADW** instance (Always Free is sufficient)
3. Note your **DB name** and choose a strong **ADMIN password**

### Step 1 · Download and place your wallet

1. In OCI Console → your ADW → **Database Connection** → **Download Wallet**
2. Save the ZIP as `wallet/Wallet_YourDB.zip` in this project folder
3. The `wallet/` directory is git-ignored

---

## Setup

### Step 2 · Create the fleet_demo user (run ONCE as ADMIN)

Connect as ADMIN and run the prerequisite script:

```bash
sql /nolog
SQL> SET CLOUDCONFIG wallet/Wallet_YourDB.zip
SQL> CONNECT admin/YourAdminPassword@yourdb_medium
SQL> @sql/00_prereq_setup.sql
```

This script creates the `fleet_demo` user (default password: `Fleet_Demo_2026#`) and grants
all required privileges. Change the password before any non-demo use.

### Step 3 · Reconnect as fleet_demo

```sql
SQL> CONNECT fleet_demo/Fleet_Demo_2026#@yourdb_medium
```

### Step 4 · Run the demo

```sql
SQL> @sql/00_master_run.sql
```

### Step 5 (optional) · MongoDB / SODA demo

```sql
SQL> @sql/08_soda_orders.sql
```

### Configure your connection template (optional)

```bash
cp config/connection.properties.template config/connection.properties
# Edit config/connection.properties with your wallet path, password, and service name
```

---

## Running the Demo

### Option A — VSCode SQLcl Extension (recommended)

1. Open this folder in VSCode: `code .`
2. Install recommended extensions when prompted (`.vscode/extensions.json`)
3. Open **Oracle Explorer** panel (sidebar)
4. **Add Connection** → Cloud Wallet → select `wallet/Wallet_YourDB.zip`
5. Enter `fleet_demo` / `Fleet_Demo_2026#` / service name `yourdb_medium`
6. Open `sql/00_prereq_setup.sql` → right-click → **Run in SQLcl** (as ADMIN, once only)
7. Reconnect as `fleet_demo`, then open `sql/00_master_run.sql` → **Run in SQLcl**

### Option B — SQLcl Command Line

```bash
# Navigate to this directory
cd /path/to/26ai-Spatial-DEMO

# Step 1: Run prerequisite setup as ADMIN (once only)
sql /nolog
SQL> SET CLOUDCONFIG wallet/Wallet_YourDB.zip
SQL> CONNECT admin/YourAdminPassword@yourdb_medium
SQL> @sql/00_prereq_setup.sql

# Step 2: Reconnect as fleet_demo
SQL> CONNECT fleet_demo/Fleet_Demo_2026#@yourdb_medium

# Step 3: Run the full demo end-to-end
SQL> @sql/00_master_run.sql

# Or step by step:
SQL> @sql/01_create_schema.sql
SQL> @sql/02_seed_data.sql
SQL> @sql/03_baseline_routes.sql
SQL> @sql/04_vrp_optimize.sql
SQL> @sql/05_telemetry_stream.sql
SQL> @sql/06_spatial_analysis.sql
SQL> @sql/07_report.sql

# Optional: MongoDB / SODA demo
SQL> @sql/08_soda_orders.sql
```

MongoDB Compass connection string (after running `08_soda_orders.sql`):
```
mongodb://fleet_demo:Fleet_Demo_2026#@<your-host>:27017/fleet_demo?authMechanism=PLAIN&authSource=$external&ssl=true&retryWrites=false&loadBalanced=true
```

### Option C — Claude Code + SQLcl MCP Server

This lets Claude drive the demo and answer ad-hoc questions via natural language against live data.

1. Start the SQLcl MCP server:
   ```bash
   sql /nolog -mcp
   ```

2. Add the MCP server config to **Claude Desktop** (`~/.config/claude/claude_desktop_config.json`)
   or **VSCode MCP settings** — see `config/mcp_servers.json` for the config block.

3. In Claude, connect:
   ```
   SET CLOUDCONFIG /path/to/wallet/Wallet_YourDB.zip
   CONNECT fleet_demo/Fleet_Demo_2026#@yourdb_medium
   ```

4. Ask Claude to:
   - *"Run the VRP demo from scratch"*
   - *"Show me the before/after cost comparison"*
   - *"Find routes similar to route #3 using vector search"*
   - *"Which vehicles are currently inside the CBD zone?"*

---

## Claude Code Access Options

Claude Code is required for Option C (MCP-driven demo). Three ways to get access:

### Free tier
Claude Code includes a free usage tier — no Pro subscription required.
Suitable for development and testing. May hit rate limits during a heavy live demo
(multiple script runs + sustained Q&A). Check current limits at
**https://claude.ai/code** before relying on free tier for a live presentation.

### API key (recommended for live demos)
Use your own Anthropic API key — no subscription needed, pay only for what you use.

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

Purchase credits in dollar increments at **https://console.anthropic.com**.

> **Typical cost estimate:** A full demo run (scripts 01–08 + 8 ad-hoc questions)
> uses approximately 60,000–80,000 tokens, costing roughly **$0.50–$1.50** with
> Claude Sonnet (the default model). Budget **$10–20 per presenter** to cover
> test runs plus the live demo with comfortable headroom.
>
> ⚠️ *Token pricing changes regularly — verify current rates at
> https://www.anthropic.com/pricing before planning a demo budget.*

### Pro / Max subscription
Covers Claude Code usage within the subscription's included limits.
Pro ($20/month) is sufficient for occasional demos; Max ($100/month) for heavy daily use.

> ⚠️ *Subscription pricing and tier names may change — check https://www.anthropic.com/pricing
> for current options.*

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
    ├── 00_prereq_setup.sql          ← Run ONCE as ADMIN to create fleet_demo user
    ├── 00_master_run.sql            ← Run everything at once (as fleet_demo)
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
| `ORA-01950: no privileges on tablespace USERS` | Re-run `@sql/00_prereq_setup.sql` as ADMIN |
| JSON Duality view fails | Re-run `@sql/00_prereq_setup.sql` as ADMIN (grants `DB_DEVELOPER_ROLE`) |

---

## License

Demo code. Free to use for learning and demonstrations.
Oracle Database, SQLcl, and associated trademarks are property of Oracle Corporation.
