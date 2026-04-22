#Requires -Version 5.1
<#
.SYNOPSIS
  Loads the sample stored procedures from demo/sprocs/ into a SQL Server you
  already have. Designed for demo attendees cloning this repo to try the
  VSCode + MSSQL + Copilot workflow against their own database.

.DESCRIPTION
  Unlike scripts/bootstrap-sql.ps1 (which runs on the Azure VM provisioned by
  `azd up` and does a full AdventureWorksLT restore), this script targets an
  EXISTING SQL Server you supply. It will:

    1. Test the connection.
    2. Verify the target database exists.
    3. Execute every .sql file in demo/sprocs/ against that database.

  It does NOT provision infrastructure and does NOT restore AdventureWorksLT.
  If you don't already have AdventureWorksLT2022 loaded, see the README for
  options.

.PARAMETER ServerInstance
  SQL Server FQDN or hostname. Examples:
    - sql01.contoso.com              (on-prem / Azure SQL VM)
    - myserver.database.windows.net  (Azure SQL DB)
    - localhost                      (local install)

.PARAMETER Database
  Target database name. Defaults to AdventureWorksLT2022.

.PARAMETER Username
  SQL authentication username. Omit to use Windows / Entra integrated auth.

.PARAMETER Password
  SQL authentication password. Omit to be prompted securely.

.PARAMETER TrustServerCertificate
  Trust a self-signed TLS cert (common for dev SQL Servers). Default: $true.

.EXAMPLE
  # SQL authentication, prompts for password
  ./scripts/load-demo-data.ps1 -ServerInstance sql01.contoso.com -Username sa

.EXAMPLE
  # Windows/Entra integrated auth, custom database
  ./scripts/load-demo-data.ps1 -ServerInstance localhost -Database MyAwDb

.EXAMPLE
  # Azure SQL DB
  ./scripts/load-demo-data.ps1 `
      -ServerInstance myserver.database.windows.net `
      -Database AdventureWorksLT2022 `
      -Username sqladmin
#>
param(
    [Parameter(Mandatory = $true)][string]$ServerInstance,
    [string]$Database = 'AdventureWorksLT2022',
    [string]$Username,
    [string]$Password,
    [bool]$TrustServerCertificate = $true
)

$ErrorActionPreference = 'Stop'

# Ensure SqlServer module is installed.
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "Installing SqlServer PowerShell module..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
}
Import-Module SqlServer

# Prompt for password if username given but password wasn't.
if ($Username -and -not $Password) {
    $sec = Read-Host -AsSecureString "Password for $Username"
    $Password = [System.Net.NetworkCredential]::new('', $sec).Password
}

# Build auth splat.
$authArgs = @{
    ServerInstance         = $ServerInstance
    TrustServerCertificate = $TrustServerCertificate
}
if ($Username) {
    $authArgs.Username = $Username
    $authArgs.Password = $Password
}

# 1. Test the connection.
Write-Host "==> Testing connection to $ServerInstance ..." -ForegroundColor Cyan
try {
    $v = Invoke-Sqlcmd @authArgs -Query "SELECT @@VERSION AS Version" -QueryTimeout 30
    Write-Host "    Connected: $($v.Version.Split("`n")[0].Trim())" -ForegroundColor Green
} catch {
    Write-Error "Could not connect to $ServerInstance. $_"
    exit 1
}

# 2. Verify target database exists.
Write-Host "==> Checking database '$Database' exists ..." -ForegroundColor Cyan
$dbCheck = Invoke-Sqlcmd @authArgs -Query "SELECT name FROM sys.databases WHERE name = N'$Database'"
if (-not $dbCheck) {
    Write-Error "Database '$Database' not found on $ServerInstance. Restore or create it first, then re-run."
    exit 1
}
Write-Host "    Found." -ForegroundColor Green

# 3. Load every .sql file in demo/sprocs/.
$sprocDir = Join-Path $PSScriptRoot '..\demo\sprocs'
$sprocDir = Resolve-Path $sprocDir
$files = Get-ChildItem -Path $sprocDir -Filter *.sql | Sort-Object Name

if (-not $files) {
    Write-Warning "No .sql files found in $sprocDir."
    exit 0
}

Write-Host "==> Loading $($files.Count) procedure(s) from $sprocDir ..." -ForegroundColor Cyan
foreach ($f in $files) {
    Write-Host "    - $($f.Name)" -NoNewline
    try {
        Invoke-Sqlcmd @authArgs -Database $Database -InputFile $f.FullName -QueryTimeout 60
        Write-Host "  OK" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED" -ForegroundColor Red
        Write-Error $_.Exception.Message
        exit 1
    }
}

Write-Host ""
Write-Host "Done. Try one of the procedures:" -ForegroundColor Cyan
Write-Host "  EXEC SalesLT.usp_TopCustomersByRevenue @TopN = 5;" -ForegroundColor Gray
Write-Host "  EXEC SalesLT.usp_ProductsInCategory    @CategoryName = 'Road Bikes';" -ForegroundColor Gray
Write-Host "  EXEC SalesLT.usp_CustomerOrderHistory  @CustomerID = 29485;" -ForegroundColor Gray
