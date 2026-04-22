#Requires -Version 7.0
$ErrorActionPreference = 'Continue'

$values = azd env get-values --output json | ConvertFrom-Json
$fqdn  = $values.SQL_VM_FQDN
$ip    = $values.SQL_VM_PUBLIC_IP
$login = $values.SQL_ADMIN_LOGIN
$upn   = $values.ENTRA_ADMIN_UPN

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host ' SQL Copilot Demo is ready!' -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
Write-Host "  Server FQDN : $fqdn"
Write-Host "  Server IP   : $ip"
Write-Host "  SQL Login   : $login   (password in azd env: SQL_ADMIN_PASSWORD)"
Write-Host "  Entra Admin : $upn"
Write-Host "  Database    : AdventureWorksLT2022"
Write-Host ''
Write-Host 'To retrieve generated passwords:'
Write-Host '  azd env get-value SQL_ADMIN_PASSWORD'
Write-Host '  azd env get-value VM_ADMIN_PASSWORD'
Write-Host ''
Write-Host 'Next: open VSCode, connect using demo\connection-profiles.md' -ForegroundColor Cyan
Write-Host ''
