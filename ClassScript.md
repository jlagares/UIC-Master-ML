# Dbt + Databricks End-to-End: Weather & Sales

A guided, step-by-step script for running this class live (or self-paced). It
implements the 6-step scenario mapped to the five pillars (Data Management,
DataOps, Data Architecture, Software Engineering, Security) and the six
values (Cost, Agility, Scalability, Simplicity, Reuse, Interoperability).

---

## The Business Problem

**Question:** *Does the weather in a franchise's city help explain how many
customer reviews it receives — and can we explain that relationship in plain
English for someone who isn't a data analyst?*

A bakery franchise chain wants to understand whether external factors like
weather influence customer engagement (review volume), city by city, without
commissioning a new data pipeline or hiring an analyst to write ad-hoc SQL
every time someone asks. They need:

- A **self-serve dashboard** that non-technical stakeholders (store managers,
  regional leads) can open and explore on their own.
- **Plain-language insights**, not just raw numbers — a one-sentence summary
  per franchise rather than a wall of metrics.
- A pipeline that's **cheap and fast to stand up**, reusing data that's
  already in the lakehouse instead of integrating a new weather feed.

**What we build to solve it:** a governed bronze → silver → gold dbt
pipeline that joins Databricks' pre-loaded `samples.bakehouse` (franchise
sales/reviews) and `samples.accuweather` (weather) sample data, enriches the
result with a GenAI-generated narrative via `ai_query()`, and publishes it
all as a Databricks (Lakeview) dashboard anyone can open — answering
questions like *"Which franchises get the most reviews?"*, *"Is there a
pattern between temperature/humidity and review volume?"*, and *"What's
driving customer sentiment this month?"* — with zero new data ingestion.

**Data caveat — set expectations before showing results:**

| Source | Date range | Notes |
|---|---|---|
| `samples.bakehouse.media_customer_reviews` | 2024-05-20 to 2024-05-31 | Fixed sample dataset |
| `samples.accuweather.historical_daily_calendar_imperial` | 2024-06-27 to 2024-07-12 | Rolling window, ~2 weeks *before* today |
| `samples.accuweather.forecast_daily_calendar_imperial` | 2024-07-12 to 2024-07-26 | Rolling window, ~2 weeks *after* today |

The review dates and weather dates **never overlap** — the weather tables
slide forward with "today" while the reviews are frozen in the past. Because
of this, the gold layer correlates review volume with each city's **current
weather snapshot**, not the weather on the actual review date. Flag this
explicitly when walking through the dashboard: the insight is "reviews vs.
typical/current conditions in that city," not "reviews vs. the weather that
day."

---

## Technical Steps

The rest of this document walks through how we built that solution:

---

## 0. Prerequisites

- Docker Desktop running
- A Databricks workspace (Free Edition works) with Unity Catalog and a SQL
  Warehouse
- This repo cloned, with `.env` filled in (copy from `.env.example`):
  ```
  DATABRICKS_HOST=...
  DATABRICKS_HTTP_PATH=/sql/1.0/warehouses/...
  DATABRICKS_CATALOG=workspace
  DATABRICKS_SCHEMA=default
  DATABRICKS_TOKEN=...   # Databricks personal access token
  ```
- `catalog.schema` target: by convention this project writes to
  `workspace.bronze`, `workspace.silver`, `workspace.gold` (see "Schema
  naming" below) — dbt auto-creates these schemas on first run.

---

## 1. Prove connectivity — `runBasic.ps1`

Before touching the real pipeline, confirm dbt can talk to Databricks:

```powershell
.\runBasic.ps1            # dbt debug
.\runBasic.ps1 run        # builds the smoke-test model dbt/models/example/my_first_model.sql
.\runBasic.ps1 docs       # local dbt docs workspace at http://localhost:8080
```

`runBasic.ps1` builds the `dbt-databricks` Docker image (if missing) and runs
any dbt subcommand against the scaffolded project in `dbt/`, using
`--env-file .env`.

---

## 2. Run the full E2E scenario — `runFull.ps1`

```powershell
.\runFull.ps1              # dbt build: bronze -> silver -> gold + all tests
.\runFull.ps1 run          # same scope, skip tests
.\runFull.ps1 test
```

`runFull.ps1` targets only `models/staging`, `models/intermediate`, and
`models/marts` (the scenario below) — it does not touch the standalone
`dbt/models/example` smoke-test model.

---

## 3. The 6 steps of the scenario

### Step 1 — Data Management: reuse, don't ingest

- Source tables are declared in `dbt/models/staging/_staging__sources.yml`:
  - `samples.accuweather.forecast_daily_calendar_imperial` — pre-loaded
    weather forecast data, imperial units.
  - `samples.bakehouse.sales_franchises` / `media_customer_reviews` — the
    bakery franchise + review dataset used elsewhere in this repo.
- **Reuse** + **Cost**: zero ingestion pipeline, zero storage cost — we
  query Databricks sample data directly.

### Step 2 — Data Architecture: medallion layering (bronze → silver → gold)

| Layer | Folder | Schema | Models |
|---|---|---|---|
| Bronze | `dbt/models/staging/` | `workspace.bronze` | `stg_accuweather__forecast_daily`, `stg_bakehouse__sales_franchises`, `stg_bakehouse__media_customer_reviews` |
| Silver | `dbt/models/intermediate/` | `workspace.silver` | `int_daily_weather_by_city`, `int_franchise_review_summary` |
| Gold | `dbt/models/marts/` | `workspace.gold` | `fct_weather_sales_correlation`, `fct_weather_sales_ai_summary` |

**Schema naming:** `dbt/macros/get_custom_schema.sql` overrides dbt's default
`generate_schema_name` macro so each layer's `+schema` config (set in
`dbt/dbt_project.yml`) becomes the actual Unity Catalog schema name —
`bronze` / `silver` / `gold` — instead of being suffixed onto the profile's
default schema. This ties to **Scalability** + **Simplicity**: the pattern
is standard and extends cleanly to new sources.

> **Data note:** `samples.accuweather` forecast/historical tables are
> **rolling windows relative to "today"** (~2 weeks back/forward), not a
> fixed historical archive, while `media_customer_reviews` is fixed around
> May 2024. Because of this, the silver weather model aggregates to **one
> row per city** (a "current conditions" snapshot) rather than per
> city+month, and the gold join is on **city only**. Call this out live —
> it's a good teaching moment about validating assumptions in sample/demo
> data before joining on time windows.

### Step 3 — DataOps: tests as the unit of trust

- `dbt/models/staging/_staging__models.yml`,
  `intermediate/_intermediate__models.yml`, `marts/_marts__models.yml`
  define `not_null`, `unique`, and `relationships` tests on every layer.
- `.\runFull.ps1 test` (or `build`, which runs + tests) is the repeatable,
  versioned CI unit — **Agility** (fast feedback) + **Interoperability**
  (same container runs locally today, in CI tomorrow).

### Step 4 — Software Engineering: modularity

- `dbt/macros/fahrenheit_to_celsius.sql` — a reusable Jinja macro, applied
  in `stg_accuweather__forecast_daily.sql` to derive `temperature_avg_c`
  without duplicating the conversion formula.
- `.\runBasic.ps1 docs` generates and serves the dbt docs lineage graph —
  living documentation of the whole DAG, from source to gold.

### Step 5 — Security: least privilege

- dbt writes only to `workspace.bronze` / `silver` / `gold` — keep broader
  `workspace.default` / other catalogs out of this pipeline's grants.
- Auth is via a scoped `DATABRICKS_TOKEN` (PAT) in a gitignored `.env`,
  targeting one SQL Warehouse — never hardcode credentials in `profiles.yml`
  or commit them.
- In a real workspace: grant `USE CATALOG` + `USE SCHEMA` + `SELECT` on the
  `samples` catalog (read), and `CREATE TABLE`/`CREATE SCHEMA`/`MODIFY`
  scoped to `bronze`/`silver`/`gold` only (write).

### Step 6 — Close the loop: GenAI (`ai_query()`)

- `dbt/models/marts/fct_weather_sales_ai_summary.sql` calls
  `ai_query('databricks-meta-llama-3-1-8b-instruct', ...)` to turn each
  franchise/month's review volume + weather snapshot into a one-sentence,
  human-readable insight — the same `LOWER(ai_query(...))` pattern used in
  `Notebooks/From Table to GenAI.ipynb`.
- This is the payoff moment for the class: raw sample data → governed,
  tested bronze/silver/gold tables → an LLM-generated narrative, all driven
  by `dbt build`.

---

## 4. Visualize — import the dashboard

1. Run `.\runFull.ps1` first so `workspace.gold.fct_weather_sales_ai_summary`
   exists and is populated.
2. In Databricks: **Dashboards → Create dashboard → Import dashboard from
   file**.
3. Select `dashboard/weather_sales_dashboard.lvdash.json`.
4. Click **Publish**.

The dashboard includes:
- A **counter**: total customer reviews across all franchises.
- A **bar chart**: review volume by franchise, colored by average
  temperature.
- A **table**: the full gold row set — franchise, city, review count,
  weather metrics, and the `ai_query()`-generated insight.

If your catalog/schema differs from `workspace.gold`, edit the dataset
query at the top of the `.lvdash.json` file (or in the dashboard UI after
import) to match your environment.

---

## 5. Recap — pillars & values hit by each step

| Step | Pillar | Value(s) |
|---|---|---|
| 1. Reuse sample sources | Data Management | Reuse, Cost |
| 2. Bronze/silver/gold | Data Architecture | Scalability, Simplicity |
| 3. Schema tests + CI | DataOps | Agility, Interoperability |
| 4. Macros + docs | Software Engineering | Simplicity, Reuse |
| 5. Scoped grants + token | Security | — |
| 6. `ai_query()` insight + dashboard | (ties it all together) | Agility, Interoperability |
