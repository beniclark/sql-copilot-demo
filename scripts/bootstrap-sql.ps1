#Requires -Version 5.1
<#
.SYNOPSIS
  Runs on the SQL Server VM after provisioning. Downloads AdventureWorksLT2022.bak,
  restores it into the SQL instance, and creates the Entra admin login with sysadmin.

.PARAMETER EntraAdminUpn
  UPN of the Entra user to configure as SQL sysadmin (e.g. you@contoso.com).
#>
param(
    [Parameter(Mandatory=$true)][string]$EntraAdminUpn,
    [string]$SqlAdminLogin,
    [string]$SqlAdminPassword
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

Write-Output "==> bootstrap-sql starting (EntraAdminUpn=$EntraAdminUpn)"

# Ensure data/log directories exist (SQL IaaS agent creates F:\data and G:\log).
foreach ($p in 'F:\data','G:\log') {
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

$bakPath = 'C:\AdventureWorksLT2022.bak'
if (-not (Test-Path $bakPath)) {
    Write-Output "==> Downloading AdventureWorksLT2022.bak ..."
    Invoke-WebRequest `
        -Uri 'https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2022.bak' `
        -OutFile $bakPath -UseBasicParsing
}

Write-Output "==> Ensuring SqlServer PowerShell module is available ..."
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
    Install-Module -Name SqlServer -Force -AllowClobber -Scope AllUsers
}
Import-Module SqlServer

$restoreSql = @"
IF DB_ID(N'AdventureWorksLT2022') IS NULL
BEGIN
    RESTORE DATABASE [AdventureWorksLT2022]
        FROM DISK = N'$bakPath'
        WITH MOVE N'AdventureWorksLT2022_Data' TO N'F:\data\AdventureWorksLT2022.mdf',
             MOVE N'AdventureWorksLT2022_Log'  TO N'G:\log\AdventureWorksLT2022_log.ldf',
             REPLACE, STATS = 10;
END
"@

$sqlAdminLogin    = $SqlAdminLogin
$sqlAdminPassword = $SqlAdminPassword
$authArgs = @{ ServerInstance = '.'; TrustServerCertificate = $true }
if ($sqlAdminLogin -and $sqlAdminPassword) {
    $authArgs.Username = $sqlAdminLogin
    $authArgs.Password = $sqlAdminPassword
}

# Retry loop: the SQL service may still be starting or the IaaS agent may still be
# applying configuration on first boot.
$connected = $false
for ($i = 1; $i -le 20 -and -not $connected; $i++) {
    try {
        Invoke-Sqlcmd @authArgs -Query 'SELECT 1' -ErrorAction Stop | Out-Null
        $connected = $true
    } catch {
        Write-Output "    SQL not reachable yet (attempt $i/20): $($_.Exception.Message)"
        Start-Sleep -Seconds 15
    }
}
if (-not $connected) { throw 'SQL Server did not become reachable in time.' }

Write-Output "==> Restoring AdventureWorksLT2022 ..."
# First peek at logical file names in the .bak so the MOVE clauses are correct.
$files = Invoke-Sqlcmd @authArgs -Query "RESTORE FILELISTONLY FROM DISK = N'$bakPath'"
$dataLogical = ($files | Where-Object Type -eq 'D').LogicalName
$logLogical  = ($files | Where-Object Type -eq 'L').LogicalName

$restoreSql = @"
IF DB_ID(N'AdventureWorksLT2022') IS NULL
BEGIN
    RESTORE DATABASE [AdventureWorksLT2022]
        FROM DISK = N'$bakPath'
        WITH MOVE N'$dataLogical' TO N'F:\data\AdventureWorksLT2022.mdf',
             MOVE N'$logLogical'  TO N'G:\log\AdventureWorksLT2022_log.ldf',
             REPLACE, STATS = 10;
END
"@
Invoke-Sqlcmd @authArgs -Query $restoreSql -QueryTimeout 600

Write-Output "==> Creating Entra login for $EntraAdminUpn ..."
$loginSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$EntraAdminUpn')
    CREATE LOGIN [$EntraAdminUpn] FROM EXTERNAL PROVIDER;
ALTER SERVER ROLE sysadmin ADD MEMBER [$EntraAdminUpn];
"@
try {
    Invoke-Sqlcmd @authArgs -Query $loginSql
} catch {
    Write-Warning "Could not create Entra login (Entra auth may not be fully configured yet): $($_.Exception.Message)"
}

Write-Output "==> bootstrap-sql complete."
