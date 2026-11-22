# Databricks Alerts

This folder defines a Databricks SQL Alert as a safety net for the gold
layer: it fires when `workspace.gold.fct_weather_sales_ai_summary` has
**zero rows** — the exact silent-failure mode we hit earlier in this
project (the weather↔city join stopped matching and the dashboard went
empty with no error anywhere).

## Files

| File | Purpose |
|---|---|
| `gold_table_empty_check.sql` | The alert's condition query — `SELECT COUNT(*) AS row_count FROM workspace.gold.fct_weather_sales_ai_summary` |
| `create_alert.ps1` | Creates the alert via the Databricks Alerts v2 REST API (`/api/2.0/alerts`), using the credentials in `.env`. Idempotent — running it again won't create a duplicate. |

## Usage

```powershell
.\alerts\create_alert.ps1
```

This creates (or finds, if it already exists) an alert named
**"Gold Table Empty: fct_weather_sales_ai_summary"** that:
- Runs the condition query daily at 08:00 UTC on your configured SQL
  Warehouse.
- Fires when `row_count == 0`.

After running the script, open the printed URL in Databricks and add a
**notification destination** (email, Slack webhook, etc.) — the REST API
call creates the alert and schedule, but not who/what gets notified; that
step currently requires the UI (**Alert → Notifications → Add
destination**).

## Why this matters for the demo

Databricks Alerts don't support JSON import/export like Lakeview dashboards
do (see `dashboard/`), so this folder uses a small, idempotent REST API
script instead — same pattern as the rest of this repo's `*.ps1` helpers
(`runBasic.ps1`, `runFull.ps1`), reusing the same `.env` credentials.
