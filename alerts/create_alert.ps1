<#
.SYNOPSIS
    Creates a Databricks SQL Alert that fires when
    workspace.gold.fct_weather_sales_ai_summary has zero rows.

.DESCRIPTION
    Uses the Databricks Alerts v2 REST API (POST/GET /api/2.0/alerts) with
    the credentials already in .env (DATABRICKS_HOST, DATABRICKS_TOKEN,
    DATABRICKS_HTTP_PATH). Idempotent: if an alert with the same
    display name already exists, it prints its id/URL instead of creating a
    duplicate.

    This alert is a safety net for the exact failure mode hit earlier in
    this project: if the weather<->city join in fct_weather_sales_correlation
    stops matching (e.g. sample data drifts), fct_weather_sales_ai_summary
    silently ends up empty and the dashboard shows nothing. This alert makes
    that failure visible instead of silent.

.USAGE
    .\alerts\create_alert.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Error ".env not found at $envFile. Copy .env.example to .env and fill in your Databricks credentials first."
    exit 1
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)\s*$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2])
    }
}

$requiredVars = @("DATABRICKS_HOST", "DATABRICKS_TOKEN", "DATABRICKS_HTTP_PATH")
foreach ($v in $requiredVars) {
    if (-not [System.Environment]::GetEnvironmentVariable($v)) {
        Write-Error "Missing $v in .env"
        exit 1
    }
}

$host_ = $env:DATABRICKS_HOST
$token = $env:DATABRICKS_TOKEN
$warehouseId = ($env:DATABRICKS_HTTP_PATH -split '/')[-1]
$headers = @{ Authorization = "Bearer $token" }
$alertsUri = "https://$host_/api/2.0/alerts"

$displayName = "Gold Table Empty: fct_weather_sales_ai_summary"
$queryText = (Get-Content (Join-Path $PSScriptRoot "gold_table_empty_check.sql") -Raw).Trim()

Write-Host "==> Checking for an existing alert named '$displayName'..."
$existing = $null
try {
    $list = Invoke-RestMethod -Uri "$alertsUri`?page_size=100" -Headers $headers -Method Get
    $existing = $list.alerts | Where-Object { $_.display_name -eq $displayName } | Select-Object -First 1
} catch {
    Write-Warning "Could not list existing alerts (continuing to create): $($_.Exception.Message)"
}

if ($existing) {
    Write-Host "==> Alert already exists (id=$($existing.id)). Skipping creation."
    Write-Host "    Open it at: https://$host_/sql/alerts/$($existing.id)"
    exit 0
}

Write-Host "==> Creating alert '$displayName' on warehouse $warehouseId..."

$body = @{
    display_name = $displayName
    query_text    = $queryText
    warehouse_id  = $warehouseId
    evaluation    = @{
        comparison_operator = "EQUAL"
        threshold           = @{ value = @{ double_value = 0 } }
        source              = @{ name = "row_count" }
    }
    schedule      = @{
        # Every day at 08:00 UTC. Tighten this (e.g. hourly) if you run
        # runFull.ps1 more often and want faster feedback.
        quartz_cron_schedule = "0 0 8 * * ?"
        timezone_id           = "UTC"
    }
} | ConvertTo-Json -Depth 10

$resp = Invoke-RestMethod -Uri $alertsUri -Headers $headers -Method Post -ContentType "application/json" -Body $body

Write-Host "==> Alert created: id=$($resp.id)"
Write-Host "    Open it at: https://$host_/sql/alerts/$($resp.id)"
Write-Host "    NOTE: add a notification destination (email/Slack/webhook) to the alert in the"
Write-Host "    Databricks UI so you actually get notified -- the API call above does not set one."
