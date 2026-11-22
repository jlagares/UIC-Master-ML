<#
.SYNOPSIS
    Full end-to-end dbt + Databricks demo: builds the bronze -> silver -> gold
    pipeline (samples.accuweather + samples.bakehouse), runs all data tests,
    and points you at the ready-to-import Lakeview dashboard.

.DESCRIPTION
    Runs `dbt build` for the staging (bronze), intermediate (silver), and
    marts (gold) models only — the full weather + sales + GenAI scenario
    described in ClassScript.md. Reads connection settings from .env.

    This does NOT run the standalone `dbt/models/example` smoke-test model;
    use .\runBasic.ps1 for that.

.PARAMETER Command
    The dbt subcommand to run against the bronze/silver/gold models.
    Defaults to "build" (run + test). Use "run" to skip tests, or pass
    extra args, e.g. "run --select fct_weather_sales_ai_summary".

.EXAMPLE
    .\runFull.ps1
    .\runFull.ps1 run
    .\runFull.ps1 test
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command = @("build")
)

$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$EnvFile = Join-Path $RepoRoot ".env"
$DbtDir = Join-Path $RepoRoot "dbt"
$DashboardFile = Join-Path $RepoRoot "dashboard\weather_sales_dashboard.lvdash.json"
$ImageName = "dbt-databricks"

if (-not (Test-Path $EnvFile)) {
    throw ".env not found at $EnvFile. Copy .env.example to .env and fill in your Databricks values first."
}

if (-not (Test-Path $DbtDir)) {
    throw "dbt project folder not found at $DbtDir."
}

# Build the image if it doesn't already exist locally.
$imageExists = docker images -q $ImageName
if (-not $imageExists) {
    Write-Host "==> Image '$ImageName' not found locally, building it..." -ForegroundColor Cyan
    docker build -t $ImageName $RepoRoot
}

# Target only the bronze/silver/gold model folders (the E2E scenario),
# selecting by dbt path so the standalone example model is left out.
$dbtArgs = $Command + @("--select", "path:models/staging", "path:models/intermediate", "path:models/marts")

Write-Host "==> Running: dbt $($dbtArgs -join ' ')" -ForegroundColor Cyan
docker run --rm `
    --env-file $EnvFile `
    -v "${DbtDir}:/usr/app" `
    $ImageName @dbtArgs

Write-Host ""
Write-Host "==> E2E pipeline complete (bronze -> silver -> gold)." -ForegroundColor Green
Write-Host "    Gold tables: workspace.gold.fct_weather_sales_correlation, workspace.gold.fct_weather_sales_ai_summary"
Write-Host "    To visualize: in Databricks, go to Dashboards > Create > Import dashboard from file,"
Write-Host "    and select: $DashboardFile"
Write-Host "    See ClassScript.md for the full walkthrough."

# Make sure the "gold table empty" safety-net alert exists (idempotent).
$CreateAlertScript = Join-Path $RepoRoot "alerts\create_alert.ps1"
if (Test-Path $CreateAlertScript) {
    Write-Host ""
    Write-Host "==> Ensuring the gold-table-empty Databricks alert exists..." -ForegroundColor Cyan
    & $CreateAlertScript
}

# Make sure the native Databricks Job (dbt_task) mirrors this pipeline (idempotent).
$CreateJobScript = Join-Path $RepoRoot "jobs\create_job.ps1"
if (Test-Path $CreateJobScript) {
    Write-Host ""
    Write-Host "==> Ensuring the Databricks Job (dbt_task) is up to date..." -ForegroundColor Cyan
    & $CreateJobScript
}
