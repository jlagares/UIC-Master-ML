# Databricks Jobs

This folder defines the Databricks Job that runs this project's dbt
pipeline natively inside Databricks (as opposed to `runFull.ps1`, which
runs it from your machine via Docker).

## Files

| File | Purpose |
|---|---|
| `dbt_e2e_job.json` | Exported job definition (templated — see placeholders below), originally exported from `https://dbc-5073bc09-1435.cloud.databricks.com/jobs/137614389825132` |
| `create_job.ps1` | Creates (or updates in place) the job via the Databricks Jobs REST API (`/api/2.2/jobs`), using the credentials in `.env`. Idempotent. |

## Template placeholders

`dbt_e2e_job.json` is not used verbatim — `create_job.ps1` substitutes:

| Placeholder | Resolved from |
|---|---|
| `__PROJECT_DIRECTORY__` | `DATABRICKS_WORKSPACE_PROJECT_DIR` in `.env`, or auto-resolved as `/Workspace/Users/<you>/<repo-folder-name>/dbt` via the SCIM "Me" API |
| `__WAREHOUSE_ID__` | Parsed from `DATABRICKS_HTTP_PATH` in `.env` |
| `__CATALOG__` | `DATABRICKS_CATALOG` in `.env` |

## Usage

```powershell
.\jobs\create_job.ps1
```

**Prerequisite:** the repo must be imported into the Databricks Workspace as
a Git folder (Workspace → Repos → Add repo) at the resolved project
directory — the job's `dbt_task` reads the dbt project from Databricks
Workspace storage, not from your local machine or GitHub directly.

## What the job does

A single `dbt_task` running:
```
dbt deps
dbt seed
dbt run
```
against the SQL Warehouse/catalog in your `.env`. This mirrors
`runFull.ps1`'s pipeline, but executed by Databricks' job scheduler instead
of your local Docker container — useful for scheduling recurring runs
(e.g. nightly refresh) without keeping your machine on.

> Note: unlike `runFull.ps1` (which runs `dbt build`, including all 19 data
> tests), this job runs plain `dbt run` with no `--select` scope, so it also
> builds the `dbt/models/example` smoke-test model and skips tests. Tighten
> `commands` in `dbt_e2e_job.json` (e.g. `dbt build --select path:models/staging path:models/intermediate path:models/marts`)
> if you want full parity with `runFull.ps1`.
