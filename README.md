# sql-copilot-demo

A one-command Azure deployment of a **SQL Server 2022 on Azure VM** seeded with **AdventureWorksLT**, plus a complete demo kit for showing **VSCode + MSSQL extension + GitHub Copilot** as a modern SSMS replacement.

## What gets deployed

| Resource | SKU | Notes |
|---|---|---|
| Windows Server 2022 VM | `Standard_D2s_v5` (override via `VM_SIZE`) | SQL Server 2022 Developer (free) |
| SQL IaaS Agent (Full mode) | — | Mixed-mode auth, Entra admin, auto-patching |
| VNet + Subnet | `10.20.0.0/16` | Single subnet `10.20.1.0/24` |
| Public IP (Standard, static) | — | DNS label `sqldemo-<hash>.<region>.cloudapp.azure.com` |
| NSG | — | 3389 & 1433 **restricted to presenter IP only** |
| Data / log managed disks | Premium_LRS | 128 GB data, 64 GB log |
| AdventureWorksLT2022 | — | Restored by bootstrap extension on first boot |

Location defaults to **`eastus2`**. Override with `AZURE_LOCATION`.

## Prerequisites

- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) 1.9+
- [Azure CLI (`az`)](https://learn.microsoft.com/cli/azure/install-azure-cli) signed in: `az login`
- **PowerShell 7+** (Windows) or `bash`+`jq`+`curl` (macOS/Linux)
- An Azure subscription where you can create a VM and assign yourself as Entra SQL admin
- [VSCode](https://code.visualstudio.com/) with these extensions:
  - **SQL Server (mssql)** — `ms-mssql.mssql`
  - **GitHub Copilot** — `GitHub.copilot`
  - **GitHub Copilot Chat** — `GitHub.copilot-chat`

## Quick start

```powershell
# 1. clone & enter
cd sql-copilot-demo

# 2. login once
azd auth login
az login

# 3. set the subscription you want to deploy into
azd env new sqldemo                 # creates .azure/sqldemo/
azd env set AZURE_SUBSCRIPTION_ID <your-sub-id>
azd env set AZURE_LOCATION eastus2  # optional, this is the default

# 4. deploy (~10 min; ~5 min extra for AdventureWorksLT restore inside the VM)
azd up
```

The `preprovision` hook detects your public IP, resolves your Entra UPN + object ID, and generates strong passwords for `SQL_ADMIN_PASSWORD` and `VM_ADMIN_PASSWORD` (stored as azd secrets). On `postprovision`, the connection details print to the console.

## Run the demo

1. Open this folder in VSCode.
2. Follow [`demo/connection-profiles.md`](demo/connection-profiles.md) to add a connection (Entra ID first, SQL auth as fallback).
3. Run the queries in [`demo/queries/`](demo/queries/) in order.
4. Use [`demo/copilot-prompts.md`](demo/copilot-prompts.md) for the Copilot segment.
5. Narrate from [`demo/script.md`](demo/script.md).

## Loading data into the database

### What's loaded automatically

On first deploy, `scripts/bootstrap-sql.ps1` runs on the VM via `az vm run-command` and:

1. Downloads `AdventureWorksLT2022.bak` from [Microsoft's sql-server-samples GitHub release](https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks).
2. Restores it as `AdventureWorksLT2022`, relocating files to `F:\data\` (data) and `G:\log\` (log).
3. Creates the `demoadmin` SQL login and grants it `sysadmin`.

You get customers, products, orders, and categories out of the box — no further action needed to run the demo queries.

### Adding the sample stored procedures

The three demo stored procedures (`usp_TopCustomersByRevenue`, `usp_ProductsInCategory`, `usp_CustomerOrderHistory`) live in `demo/sprocs/`. After the VM is up, load them with one command from your laptop:

```powershell
$fqdn = azd env get-value SQL_VM_FQDN
$pwd  = azd env get-value SQL_ADMIN_PASSWORD
Get-ChildItem demo/sprocs/*.sql | ForEach-Object {
    Invoke-Sqlcmd -ServerInstance $fqdn -Database AdventureWorksLT2022 `
        -Username demoadmin -Password $pwd -TrustServerCertificate `
        -InputFile $_.FullName
}
```

Or in VSCode: open each `.sql` file, connect the tab to `AdventureWorksLT2022`, and press **Ctrl+Shift+E** to execute.

### Loading a different `.bak` file

To restore your own backup instead of / in addition to AdventureWorksLT:

1. Upload the `.bak` to the VM (RDP + drag-and-drop, or Azure Storage + `azcopy` inside the VM).
2. From VSCode (connected as `demoadmin`):
   ```sql
   RESTORE FILELISTONLY FROM DISK = 'C:\path\to\yourdb.bak';  -- see logical names
   RESTORE DATABASE YourDb FROM DISK = 'C:\path\to\yourdb.bak'
       WITH MOVE 'YourDb'      TO 'F:\data\YourDb.mdf',
            MOVE 'YourDb_log'  TO 'G:\log\YourDb_log.ldf',
            REPLACE;
   ```

### Importing CSV / flat files

For ad-hoc data, use `bcp` (comes with SQL Server, already on the VM) or the MSSQL extension's **Import Wizard** (right-click a database in the Object Explorer → *Import Wizard*). Example from your laptop using `Invoke-Sqlcmd` and `Import-Csv`:

```powershell
$rows = Import-Csv .\mydata.csv
# CREATE TABLE ... first, then:
$rows | ForEach-Object {
    $q = "INSERT INTO dbo.MyTable (Col1, Col2) VALUES ('$($_.Col1)', '$($_.Col2)')"
    Invoke-Sqlcmd -ServerInstance $fqdn -Database AdventureWorksLT2022 `
        -Username demoadmin -Password $pwd -TrustServerCertificate -Query $q
}
```

For larger loads, use `bcp <db>.<schema>.<table> in data.csv -c -t, -S <fqdn> -U demoadmin -P <pwd>` — orders of magnitude faster.

### Loading another Microsoft sample DB

Same pattern as AdventureWorksLT. The full `AdventureWorks2022.bak` (not LT) and `WideWorldImporters-Full.bak` are available on the same [GitHub releases page](https://github.com/Microsoft/sql-server-samples/releases). Copy the `.bak` to the VM and `RESTORE DATABASE` as shown above.

### Using an existing SQL Server without azd

If you already have a SQL Server (on-prem, Azure SQL VM you provisioned yourself, Azure SQL DB, etc.) and just want the demo *content* — AdventureWorksLT + the sample sprocs — you can skip `azd` entirely. Point the tools at your server instead.

**What you need (manually, in place of what `azd` + `preprovision` provide):**

| `azd` workflow provides | Manual equivalent |
|---|---|
| `SQL_VM_FQDN` | Your server's FQDN or IP, e.g. `sql01.contoso.com` |
| `SQL_ADMIN_LOGIN` / `SQL_ADMIN_PASSWORD` | Any login with `dbcreator` (to restore) or `db_owner` on an existing DB |
| `ENTRA_ADMIN_UPN` | Only needed if you want Entra auth; otherwise omit |
| `PRESENTER_IP` (NSG rule) | N/A — configure firewall on your own network |
| `bootstrap-sql.ps1` running on the VM | Run the restore from your laptop instead |

**Caveats about `scripts/bootstrap-sql.ps1` on a remote/existing server:**

The script is hardcoded for in-VM execution and won't work unmodified against a remote server. Specifically:

- It uses `ServerInstance = '.'` (local only) — you'd need `-ServerInstance <fqdn>` on every `Invoke-Sqlcmd` call.
- It assumes data/log directories `F:\data\` and `G:\log\` exist — those paths likely don't exist on your server; you'd point `MOVE` clauses at your own paths.
- The `RESTORE DATABASE ... FROM DISK` reads the `.bak` from a local path on the server. For a remote server you must first copy the `.bak` onto the server (or a network share it can read) — `RESTORE` cannot stream from a client.
- `CREATE LOGIN ... FROM EXTERNAL PROVIDER` only works if the instance already has Entra authentication configured.

**Recommended path for an existing server:** don't use `bootstrap-sql.ps1` at all. Just run this from your laptop:

```powershell
$server   = 'sql01.contoso.com'   # your server FQDN
$user     = 'sa'                  # or any admin login
$pwd      = Read-Host -AsSecureString 'SQL password' | ConvertFrom-SecureString -AsPlainText

# 1. If restoring AdventureWorksLT2022: put the .bak somewhere the server can read.
#    (Local path on the server, or a UNC share the SQL service account can access.)
#    Then ask the server to restore from there:
$bak = 'C:\sqlbackups\AdventureWorksLT2022.bak'   # path *on the server*
Invoke-Sqlcmd -ServerInstance $server -Username $user -Password $pwd -TrustServerCertificate `
    -Query "RESTORE DATABASE AdventureWorksLT2022 FROM DISK = N'$bak' WITH REPLACE, STATS = 10" `
    -QueryTimeout 600

# 2. Load the sample sprocs (works against any DB you already have too —
#    just change -Database to your database name):
Get-ChildItem demo/sprocs/*.sql | ForEach-Object {
    Invoke-Sqlcmd -ServerInstance $server -Username $user -Password $pwd -TrustServerCertificate `
        -Database AdventureWorksLT2022 -InputFile $_.FullName
}
```

**If you want to reuse `bootstrap-sql.ps1` against a remote server**, you'd need to modify it: add a `-ServerInstance` parameter, add a `-SkipRestore` switch for the "existing DB" case, and replace `F:\data`/`G:\log` with parameters. Not required for this demo — the inline commands above are simpler.

## Retrieve connection details any time

```powershell
azd env get-value SQL_VM_FQDN
azd env get-value SQL_ADMIN_LOGIN
azd env get-value SQL_ADMIN_PASSWORD
azd env get-value ENTRA_ADMIN_UPN
```

## Tear down

```powershell
azd down --purge --force
```

This deletes the resource group and all resources. **Do this as soon as the demo is over** — an idle D2s_v5 with Premium SSDs runs ~$3/day.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `PRESENTER_IP` changed (e.g., hotel WiFi → LTE) | `azd env set PRESENTER_IP <new-ip>/32 && azd provision` |
| Bootstrap extension failed | Redeploy just the extension: `az vm extension set --resource-group rg-<env> --vm-name vm<env> --name CustomScriptExtension --publisher Microsoft.Compute --settings '{}'` — or RDP in and run the script manually. |
| Can't reach 1433 | Azure NSG + host firewall are both involved. NSG is handled by IaC; the SQL IaaS Agent opens the Windows firewall rule automatically. Wait ~2 minutes after provisioning. |
| "Login failed" over Entra | The bootstrap extension may still be running. Check `az vm run-command invoke ... --command-id RunPowerShellScript --scripts "Get-Service MSSQLSERVER"` and retry in a few minutes. |
| Restore in progress | The DB restore runs inside the VM extension and can take 3-8 minutes on first boot. If `AdventureWorksLT2022` isn't visible, wait and reconnect. |

## Repo layout

```
.
├── azure.yaml                # azd project + hooks
├── infra/
│   ├── main.bicep            # subscription-scope entry
│   ├── main.parameters.json
│   └── modules/
│       ├── network.bicep     # VNet, subnet, NSG, PIP, NIC
│       └── vm.bicep          # VM + SQL IaaS agent + bootstrap extension
├── scripts/
│   ├── preprovision.ps1      # detects IP, generates passwords, resolves Entra object ID
│   ├── preprovision.sh       # same, for macOS/Linux presenters
│   └── postprovision.ps1     # prints connection banner
└── demo/
    ├── script.md             # presenter talk track
    ├── connection-profiles.md# VSCode MSSQL connection how-to
    ├── copilot-prompts.md    # NL→SQL, inline, explain, fix-it
    └── queries/
        ├── 01-browse.sql
        ├── 02-joins-aggregates.sql
        ├── 03-top-customers.sql
        └── 04-export-example.sql
```

## Security notes

- The NSG is locked to a single `/32`. Do **not** open 1433 to the internet even temporarily.
- The Entra admin is added as **sysadmin** — fine for a demo, not for prod.
- The VM has a system-assigned managed identity but no roles are granted yet. Extend as needed.
- TLS on the SQL listener uses a self-signed cert by default; connection profiles use `trustServerCertificate: true`. Provision a real cert for production use.
