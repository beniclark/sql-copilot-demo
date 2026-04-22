# VSCode MSSQL — Connection Profiles

This demo connects from the **MSSQL extension** (publisher: Microsoft, id `ms-mssql.mssql`) to the Azure SQL VM provisioned by `azd up`.

Grab the live values first:

```powershell
$fqdn  = azd env get-value SQL_VM_FQDN
$login = azd env get-value SQL_ADMIN_LOGIN
$sqlpw = azd env get-value SQL_ADMIN_PASSWORD
$upn   = azd env get-value ENTRA_ADMIN_UPN
```

## 1 · Entra ID (passwordless) — the modern path

Use this as the primary profile during the demo.

1. **Ctrl+Shift+P** → `MS SQL: Add Connection`.
2. Fill in the prompts:
   - **Server name / Connection string**: `<SQL_VM_FQDN>,1433` (e.g., `sqldemo-xxxxx.eastus2.cloudapp.azure.com,1433`)
   - **Database**: `AdventureWorksLT2022`
   - **Authentication Type**: `Microsoft Entra Id - Universal with MFA support`
   - **Account**: select `<ENTRA_ADMIN_UPN>` (sign in if prompted)
   - **Profile Name**: `SQL Demo (Entra)`
3. A browser window may pop up for MFA. Once signed in, the server appears in the **Connections** side-bar.

### settings.json equivalent

```jsonc
{
  "mssql.connections": [
    {
      "profileName": "SQL Demo (Entra)",
      "server": "sqldemo-xxxxx.eastus2.cloudapp.azure.com,1433",
      "database": "AdventureWorksLT2022",
      "authenticationType": "AzureMFA",
      "user": "beclark@microsoft.com",
      "accountId": "<filled by the extension on first sign-in>",
      "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
      "encrypt": "Mandatory",
      "trustServerCertificate": true,
      "applicationName": "vscode-sqltools"
    }
  ]
}
```

> `trustServerCertificate: true` is fine for this demo because the VM uses a self-signed TLS cert. For production, install a proper certificate and remove this flag.

## 2 · SQL authentication — the fallback

Useful when Entra federation isn't available (air-gapped demo room, offline laptop, etc.).

1. **Ctrl+Shift+P** → `MS SQL: Add Connection`.
2. Fill in:
   - **Server name**: `<SQL_VM_FQDN>,1433`
   - **Database**: `AdventureWorksLT2022`
   - **Authentication Type**: `SQL Login`
   - **User name**: `<SQL_ADMIN_LOGIN>` (default: `demoadmin`)
   - **Password**: paste the value of `SQL_ADMIN_PASSWORD`
   - **Save Password?**: Yes (stores in the OS credential manager)
   - **Profile Name**: `SQL Demo (SQL auth)`

### settings.json equivalent

```jsonc
{
  "mssql.connections": [
    {
      "profileName": "SQL Demo (SQL auth)",
      "server": "sqldemo-xxxxx.eastus2.cloudapp.azure.com,1433",
      "database": "AdventureWorksLT2022",
      "authenticationType": "SqlLogin",
      "user": "demoadmin",
      "savePassword": true,
      "encrypt": "Mandatory",
      "trustServerCertificate": true
    }
  ]
}
```

## Verify the connection

Open a new file, change the language to **SQL** (bottom-right of VSCode status bar), and run:

```sql
SELECT @@SERVERNAME AS ServerName, DB_NAME() AS CurrentDb, SUSER_NAME() AS LoginName;
```

You should see the VM's computer name, `AdventureWorksLT2022` (or `master` if you didn't set Default DB), and either your UPN (Entra) or `demoadmin` (SQL auth).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `A network-related or instance-specific error occurred` | NSG rule: confirm your current public IP matches `PRESENTER_IP`. Re-run `azd env set PRESENTER_IP <ip>/32 && azd provision`. |
| `Login failed for user` (Entra) | Make sure the bootstrap extension finished (`azd env get-values`). Re-run the bootstrap: `az vm extension set ... --name bootstrap-sql`. |
| `SSL Provider, error: 0 - The certificate chain was issued by an authority that is not trusted` | Set `trustServerCertificate: true` in the profile. |
| Can't see `AdventureWorksLT2022` | Database restore may still be running. Wait ~5 minutes after `azd up` finishes, then reconnect. |
