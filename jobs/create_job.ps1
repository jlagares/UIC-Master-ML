<#
.SYNOPSIS
    Creates (or updates) the Databricks Job that runs this project's dbt
    pipeline natively in Databricks (dbt deps / seed / run as a `dbt_task`).

.DESCRIPTION
    Exported from the real job at
    https://dbc-5073bc09-1435.cloud.databricks.com/jobs/137614389825132
    and templated in jobs/dbt_e2e_job.json (placeholders:
    __PROJECT_DIRECTORY__, __WAREHOUSE_ID__, __CATALOG__).

    This script:
      1. Reads Databricks credentials from .env.
      2. Resolves the current user via the SCIM "Me" API to build the
         Workspace project path (/Workspace/Users/<you>/<repo>/dbt) unless
         DATABRICKS_WORKSPACE_PROJECT_DIR is set in .env to override it.
      3. Fills in warehouse_id (from DATABRICKS_HTTP_PATH) and catalog
         (from DATABRICKS_CATALOG) in the job template.
      4. If a job with the same name already exists, updates it in place
         (jobs/reset) instead of creating a duplicate. Otherwise creates it.

    NOTE: this assumes the repo has been imported into the Databricks
    Workspace (Repos/Workspace Git folder) at the resolved project
    directory -- the dbt_task reads the dbt project from there, not from
    your local machine or GitHub directly.

.USAGE
    .\jobs\create_job.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot ".env"
$templateFile = Join-Path $PSScriptRoot "dbt_e2e_job.json"

if (-not (Test-Path $envFile)) {
    Write-Error ".env not found at $envFile. Copy .env.example to .env and fill in your Databricks credentials first."
    exit 1
}
if (-not (Test-Path $templateFile)) {
    Write-Error "Job template not found at $templateFile."
    exit 1
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)\s*$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2])
    }
}

foreach ($v in @("DATABRICKS_HOST", "DATABRICKS_TOKEN", "DATABRICKS_HTTP_PATH", "DATABRICKS_CATALOG")) {
    if (-not [System.Environment]::GetEnvironmentVariable($v)) {
        Write-Error "Missing $v in .env"
        exit 1
    }
}

$host_ = $env:DATABRICKS_HOST
$token = $env:DATABRICKS_TOKEN
$warehouseId = ($env:DATABRICKS_HTTP_PATH -split '/')[-1]
$catalog = $env:DATABRICKS_CATALOG
$headers = @{ Authorization = "Bearer $token" }
$jobsUri = "https://$host_/api/2.2/jobs"

# Resolve the Workspace project directory.
$projectDir = $env:DATABRICKS_WORKSPACE_PROJECT_DIR
if (-not $projectDir) {
    Write-Host "==> DATABRICKS_WORKSPACE_PROJECT_DIR not set in .env, resolving current user via SCIM..."
    $me = Invoke-RestMethod -Uri "https://$host_/api/2.0/preview/scim/v2/Me" -Headers $headers -Method Get
    $repoName = Split-Path -Leaf $repoRoot
    $projectDir = "/Workspace/Users/$($me.userName)/$repoName/dbt"
    Write-Host "    Resolved project directory: $projectDir"
    Write-Host "    (override by setting DATABRICKS_WORKSPACE_PROJECT_DIR in .env if your Git folder lives elsewhere)"
}

$jobJson = (Get-Content $templateFile -Raw) `
    -replace '__PROJECT_DIRECTORY__', ($projectDir -replace '\\', '\\') `
    -replace '__WAREHOUSE_ID__', $warehouseId `
    -replace '__CATALOG__', $catalog

$jobSettings = $jobJson | ConvertFrom-Json
$jobName = $jobSettings.name

Write-Host "==> Checking for an existing job named '$jobName'..."
$existing = $null
try {
    $list = Invoke-RestMethod -Uri "$jobsUri/list?limit=25" -Headers $headers -Method Get
    $existing = $list.jobs | Where-Object { $_.settings.name -eq $jobName } | Select-Object -First 1
} catch {
    Write-Warning "Could not list existing jobs (continuing to create): $($_.Exception.Message)"
}

if ($existing) {
    Write-Host "==> Job already exists (id=$($existing.job_id)). Updating it in place..."
    $resetBody = @{ job_id = $existing.job_id; new_settings = $jobSettings } | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Uri "$jobsUri/reset" -Headers $headers -Method Post -ContentType "application/json" -Body $resetBody | Out-Null
    $jobId = $existing.job_id
} else {
    Write-Host "==> Creating job '$jobName'..."
    $createBody = $jobSettings | ConvertTo-Json -Depth 20
    $resp = Invoke-RestMethod -Uri "$jobsUri/create" -Headers $headers -Method Post -ContentType "application/json" -Body $createBody
    $jobId = $resp.job_id
}

Write-Host "==> Job ready: id=$jobId"
Write-Host "    Open it at: https://$host_/jobs/$jobId"
