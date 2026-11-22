# Dbt + Databricks End-to-End: Weather & Sales

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

After the dbt build finishes, `runFull.ps1` also runs two **idempotent
"ensure it exists" steps** against the live Databricks workspace:

1. `alerts\create_alert.ps1` — checks for the gold-table-empty SQL Alert by
   name and creates it only if missing (never duplicates it).
2. `jobs\create_job.ps1` — checks for the native Databricks Job by name;
   creates it if missing, or **resets it in place** (`/jobs/reset`) to match
   `jobs/dbt_e2e_job.json` if it already exists.

Both print the alert/job URL so you can jump straight to it in the
Databricks UI to review what was created or updated.

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
| Silver | `dbt/models/intermediate/` | `workspace.silver` | `int_daily_weather_by_city`, `int_daily_weather_by_city_day`, `int_franchise_review_summary`, `int_review_sentiment_scores`, `int_daily_review_counts` |
| Gold | `dbt/models/marts/` | `workspace.gold` | `fct_weather_sales_correlation`, `fct_weather_sales_ai_summary`, `fct_weather_review_correlation_by_franchise` |

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

### Step 3 — DataOps: two layers of data quality

Data quality here is **two complementary layers**: build-time dbt tests, and
a run-time platform alert. Neither alone is enough — tests only run when you
run dbt; the alert only checks row counts, not shape.

**Layer 1 — dbt tests (build-time, 19 tests across 3 layers):**

| Layer | Tests | Checks |
|---|---|---|
| Bronze (`staging`) | 6 (4 `not_null`, 1 `unique`, 1 `relationships`) | Source data shape: keys present, franchise FK valid |
| Silver (`intermediate`) | 8 (7 `not_null`, 1 `unique`) | Aggregation keys/metrics not null, no duplicate city keys |
| Gold (`marts`) | 5 (4 `not_null`, 1 `unique`) | Final fact tables have valid franchise keys, no dupes |

- Defined in `dbt/models/staging/_staging__models.yml`,
  `intermediate/_intermediate__models.yml`, `marts/_marts__models.yml`.
- `.\runFull.ps1 test` (or `build`, which runs + tests) is the repeatable,
  versioned CI unit — **Agility** (fast feedback) + **Interoperability**
  (same container runs locally today, in CI tomorrow).
- **To review:** terminal output of `runFull.ps1` lists every test with
  `PASS`/`FAIL`/`WARN` (see the 30/30 `Done.` summary line), or open
  `dashboard/data_quality_and_alerts.png` for the visual lineage + test-count
  breakdown used in this scenario.

**Layer 2 — Databricks SQL Alert (run-time, catches what tests can't):**

- dbt tests catch *shape* problems (nulls, duplicates, broken foreign keys)
  but not a *silently empty* table that still passes every test (0 rows is
  still "all rows are not-null"). This is the exact failure this project hit
  when the weather↔city join stopped matching.
- `alerts/gold_table_empty_check.sql` is the alert's condition query
  (`SELECT COUNT(*) AS row_count FROM workspace.gold.fct_weather_sales_ai_summary`).
- `alerts/create_alert.ps1` creates/verifies a Databricks SQL Alert that
  fires when that row count is `0`, on a daily schedule (08:00 UTC). It is
  now called automatically at the end of `runFull.ps1` (idempotent — safe to
  re-run every time).
- **To review:** in Databricks, go to **SQL → Alerts**, open "Gold Table
  Empty: fct_weather_sales_ai_summary", and check its evaluation history.
  You'll still need to add a notification destination (email/Slack/webhook)
  once, via the Databricks UI — the REST API used here doesn't set that.

### Step 4 — Software Engineering: modularity

- `dbt/macros/fahrenheit_to_celsius.sql` — a reusable Jinja macro, applied
  in `stg_accuweather__forecast_daily.sql` to derive `temperature_avg_c`
  without duplicating the conversion formula.
- `.\runBasic.ps1 docs` generates and serves the dbt docs lineage graph —
  living documentation of the whole DAG, from source to gold.
- **Column-level documentation, pushed into Unity Catalog:** every model's
  `_*.yml` file now has a `description` for *every* column (not just the
  ones with tests) — grain, units, join keys, and which fields are
  GenAI-derived. `dbt_project.yml` sets
  `+persist_docs: { relation: true, columns: true }`, so the next
  `dbt run`/`build` writes these descriptions as **real column/table
  comments** directly on the Unity Catalog objects — visible in Catalog
  Explorer, Genie, and any BI tool, not just in `dbt docs`. No code change
  needed to pick this up: it applies automatically on the next
  `.\runFull.ps1`.

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
- `dbt/models/intermediate/int_review_sentiment_scores.sql` uses the same
  `ai_query()` pattern to classify **each individual review's sentiment**
  (positive/neutral/negative → +1/0/-1), which feeds the correlation metric
  below. This is the payoff moment for the class: raw sample data → governed,
  tested bronze/silver/gold tables → an LLM-generated narrative, all driven
  by `dbt build`.

### Bonus — "Does weather really impact reviews?" (per-franchise correlation)

- `dbt/models/marts/fct_weather_review_correlation_by_franchise.sql`
  computes a real **Pearson correlation coefficient (`CORR()`)** per
  franchise, between its daily review sentiment and the city's daily
  weather — directly answering "is this correlation statistically real, or
  just a nice sentence?"
- **Why sentiment, not review count:** franchises get ~1 review/day, so
  review *volume* barely varies day to day — `CORR()` against volume is
  almost always `NULL` (no variance to correlate). Review *sentiment* score
  does vary, so it's the metric that can actually show a relationship.
- **Why `day_index`, not calendar date:** per the data caveat above, review
  dates and weather dates don't share a calendar window. We align each
  franchise's Nth day of reviews with the Nth day of its city's weather data
  (`day_index`) as a teaching proxy — label this clearly as directional, not
  causal, since most franchises have well under 20 matched days
  (`matched_days` column; franchises below 3 matched days are excluded).

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
- A **bar chart**: per-franchise correlation between review sentiment and
  temperature (`fct_weather_review_correlation_by_franchise`) — "does
  weather really impact reviews?" with an actual coefficient, not just a
  sentence.
- A **detail table**: `matched_days`, sentiment↔temperature correlation,
  sentiment↔humidity correlation, and average sentiment per franchise.

If your catalog/schema differs from `workspace.gold`, edit the dataset
query at the top of the `.lvdash.json` file (or in the dashboard UI after
import) to match your environment.

---

## 5. Review the native Databricks Job run

This local, Docker-driven pipeline (`runFull.ps1`) has a **native Databricks
Job twin** so the same pipeline can run on a schedule, inside the workspace,
without Docker or a developer's laptop.

- `jobs/dbt_e2e_job.json` — templated export of the real job (originally
  created by hand in the Databricks Jobs UI, job id `137614389825132`,
  named **"DBT Job"**). Single `dbt_task` running `dbt deps` → `dbt seed` →
  `dbt run` against the project at
  `/Workspace/Users/<you>/UIC-Master-ML/dbt`, on a SQL Warehouse, targeting
  the `workspace` catalog.
- `jobs/create_job.ps1` — resolves your Databricks user (via SCIM `Me`) to
  build the project path, then creates the job if it doesn't exist, or
  **resets it in place** to match `jobs/dbt_e2e_job.json` if it does. Now
  called automatically at the end of `runFull.ps1`.

**To review a run:**

1. In Databricks, go to **Workflows → Jobs** and open **"DBT Job"**
   (or use the URL printed by `runFull.ps1`/`create_job.ps1`).
2. Click **Run now**, then open the run to see the `dbt_task` logs — the
   same `dbt deps` / `dbt seed` / `dbt run` steps you saw locally, now
   executed by a Databricks job cluster against the SQL Warehouse.
3. Check the **"Warehouse catalog"** setting on the dbt task is explicit
   (`workspace`) — if left blank, Databricks' auto-generated dbt profile
   falls back to the legacy Hive Metastore, which is disabled on Free
   Edition workspaces (`UC_HIVE_METASTORE_DISABLED_EXCEPTION`).

> **Note:** the job runs `dbt run` (no `--select`, no tests), so it also
> builds the standalone `dbt/models/example` smoke-test model and skips the
> 19 dbt tests that `runFull.ps1`'s `dbt build` covers. See
> `jobs/README.md` for the gap and how to tighten the job's commands for
> parity if you want build+test coverage scheduled too.

---

## 6. Recap — pillars & values hit by each step

| Step | Pillar | Value(s) |
|---|---|---|
| 1. Reuse sample sources | Data Management | Reuse, Cost |
| 2. Bronze/silver/gold | Data Architecture | Scalability, Simplicity |
| 3a. dbt tests (19 across bronze/silver/gold) | DataOps — Data Quality (build-time) | Agility, Interoperability |
| 3b. Databricks SQL Alert (zero-row check) | DataOps — Data Quality (run-time) | Agility, Reuse |
| 4. Macros + docs + persisted column comments | Software Engineering | Simplicity, Reuse |
| 5. Scoped grants + token | Security | — |
| 6. `ai_query()` insight + dashboard | (ties it all together) | Agility, Interoperability |
| Bonus. Per-franchise sentiment↔weather `CORR()` | (validates the narrative) | Agility, Interoperability |
| Native Databricks Job (scheduled twin of `runFull.ps1`) | Orchestration / DataOps | Agility, Reuse |
