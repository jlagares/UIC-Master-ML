<#
.SYNOPSIS
    Installs the dbt and Databricks CLI tooling needed to work with this repo
    on a Windows machine.

.DESCRIPTION
    - Installs/upgrades the dbt-databricks adapter (includes dbt-core) via pip.
    - Installs the Databricks CLI via winget.
    Authentication is OAuth-based — this script does not configure or require
    a DATABRICKS_TOKEN / personal access token.

.NOTES
    Run from a regular PowerShell prompt (winget requires Windows 10 1809+ / App Installer).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-Step($message) {
    Write-Host ""
    Write-Host "==> $message" -ForegroundColor Cyan
}

# --- Python / pip check -----------------------------------------------------
Write-Step "Checking for Python and pip"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    throw "Python was not found on PATH. Install Python 3.10+ first: https://www.python.org/downloads/"
}
python -m pip --version | Out-Null

# --- dbt-databricks (includes dbt-core) -------------------------------------
Write-Step "Installing/upgrading dbt-databricks (dbt-core + Databricks adapter)"
python -m pip install --upgrade pip
python -m pip install --upgrade dbt-databricks

Write-Step "Verifying dbt installation"
dbt --version

# --- Databricks CLI via winget -----------------------------------------------
Write-Step "Checking for winget"
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Warning "winget not found. Install 'App Installer' from the Microsoft Store, then re-run this script to install the Databricks CLI."
}
else {
    Write-Step "Installing/upgrading Databricks CLI"
    winget install --id Databricks.DatabricksCLI --silent --accept-package-agreements --accept-source-agreements

    Write-Step "Verifying Databricks CLI installation"
    databricks -v
}

Write-Step "Done. Next steps:"
Write-Host "  1. Copy .env.example to .env and fill in DATABRICKS_HOST / DATABRICKS_HTTP_PATH."
Write-Host "  2. From the 'dbt' folder, run 'dbt debug' to trigger OAuth login and test the connection."
Write-Host "  3. See README.md 'Running dbt' section for full instructions."
