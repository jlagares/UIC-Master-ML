<#
.SYNOPSIS
    Basic dbt + Databricks connectivity demo. Builds (if needed) and runs the
    dbt-databricks Docker image against the scaffolded dbt project in this
    repo — use this to prove the connection works (dbt debug) and to run
    ad-hoc dbt commands.

.DESCRIPTION
    Reads connection settings (host, http_path, catalog, schema, token) from
    .env and passes them into the container, mounting ./dbt as the dbt
    project/profiles directory.

    For the full bronze/silver/gold end-to-end scenario (weather + sales +
    GenAI), use .\runFull.ps1 instead.

.PARAMETER Command
    The dbt subcommand(s) to run inside the container, e.g. "debug", "run",
    "test". Defaults to "debug". Use "docs" to generate and serve the local
    dbt docs workspace (lineage graph / project docs) at http://localhost:8080.

.EXAMPLE
    .\runBasic.ps1
    .\runBasic.ps1 run
    .\runBasic.ps1 run --select my_first_model
    .\runBasic.ps1 docs
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command = @("debug")
)

$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$EnvFile = Join-Path $RepoRoot ".env"
$DbtDir = Join-Path $RepoRoot "dbt"
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

Write-Host "==> Running: dbt $($Command -join ' ')" -ForegroundColor Cyan

if ($Command[0] -eq "docs") {
    # Local dbt docs workspace: generate catalog/manifest, then serve the
    # web UI (lineage graph + project docs) on http://localhost:8080.
    docker run --rm `
        --env-file $EnvFile `
        -v "${DbtDir}:/usr/app" `
        $ImageName docs generate

    Write-Host "==> Serving dbt docs workspace at http://localhost:8080 (Ctrl+C to stop)" -ForegroundColor Cyan
    docker run --rm -it `
        --env-file $EnvFile `
        -v "${DbtDir}:/usr/app" `
        -p 8080:8080 `
        $ImageName docs serve --host 0.0.0.0 --port 8080
}
else {
    docker run --rm `
        --env-file $EnvFile `
        -v "${DbtDir}:/usr/app" `
        $ImageName @Command
}
