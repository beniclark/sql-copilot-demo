#Requires -Version 7.0
<#
.SYNOPSIS
  azd preprovision hook (Windows/pwsh). Detects presenter public IP, prompts for
  Entra admin UPN and secrets, and populates required azd env vars before Bicep runs.
#>

$ErrorActionPreference = 'Stop'

function Set-AzdEnv {
    param([string]$Key, [string]$Value, [switch]$Secret)
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    azd env set $Key $Value | Out-Null
}

function Get-AzdEnvValue {
    param([string]$Key)
    $json = azd env get-values --output json 2>$null
    if (-not $json) { return $null }
    $obj = $json | ConvertFrom-Json
    return $obj.$Key
}

# --- PRESENTER_IP ---
if (-not (Get-AzdEnvValue 'PRESENTER_IP')) {
    Write-Host 'Detecting presenter public IP...' -ForegroundColor Cyan
    try {
        $ip = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 10).ip
    } catch {
        $ip = Read-Host 'Could not auto-detect IP. Enter presenter public IPv4'
    }
    if ($ip -notmatch '/') { $ip = "$ip/32" }
    Write-Host "  Presenter IP: $ip"
    Set-AzdEnv -Key 'PRESENTER_IP' -Value $ip
}

if (-not (Get-AzdEnvValue 'ENTRA_ADMIN_UPN')) {
    try {
        $entraUpn = (az account show --query user.name -o tsv 2>$null).Trim()
    } catch { $entraUpn = $null }
    if (-not $entraUpn) {
        $entraUpn = Read-Host 'Entra admin UPN (e.g., you@contoso.com)'
    }
    Set-AzdEnv -Key 'ENTRA_ADMIN_UPN' -Value $entraUpn
}

function New-StrongPassword {
    $upper  = -join ((65..90)  | Get-Random -Count 4 | ForEach-Object { [char]$_ })
    $lower  = -join ((97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
    $digits = -join ((48..57)  | Get-Random -Count 4 | ForEach-Object { [char]$_ })
    $syms   = -join (('!','@','#','$','%','^','&','*','?') | Get-Random -Count 2)
    return ($upper + $lower + $digits + $syms)
}

if (-not (Get-AzdEnvValue 'SQL_ADMIN_PASSWORD')) {
    Set-AzdEnv -Key 'SQL_ADMIN_PASSWORD' -Value (New-StrongPassword) -Secret
    Write-Host 'Generated SQL_ADMIN_PASSWORD (stored as azd secret).' -ForegroundColor Green
}

if (-not (Get-AzdEnvValue 'VM_ADMIN_PASSWORD')) {
    Set-AzdEnv -Key 'VM_ADMIN_PASSWORD' -Value (New-StrongPassword) -Secret
    Write-Host 'Generated VM_ADMIN_PASSWORD (stored as azd secret).' -ForegroundColor Green
}

Write-Host 'Preprovision hook complete.' -ForegroundColor Green
