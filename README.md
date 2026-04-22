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

> **Demo attendees** — if you're cloning this repo to try the workflow against your **own** existing SQL Server (on-prem, local install, Azure SQL VM, Azure SQL DB, etc.), use **`scripts/load-demo-data.ps1`** to load the sample stored procedures. You do **not** need `azd` or the Azure VM from the Quick Start above — that path is only relevant if you want to provision the full demo environment from scratch.

### Attendee path: bring your own SQL Server

You'll do two things: **(1) restore AdventureWorksLT2022 onto your server**, then **(2) load the sample stored procedures**. Steps below.

#### Step 1 — Restore `AdventureWorksLT2022.bak` onto your server

Download the sample backup from Microsoft's official release:

**[AdventureWorksLT2022.bak](https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2022.bak)** (~7 MB) — part of the [sql-server-samples](https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks) repo.

Then restore it. The right approach depends on the kind of server you have:

<details open>
<summary><b>SQL Server (on-prem, local install, Azure SQL VM, containers)</b></summary>

The `.bak` must be on the **server's** filesystem, not the client's. Copy it to a path SQL can read (e.g. `C:\sqlbackups\` on Windows, `/var/opt/mssql/backup/` on Linux), then:

```sql
-- Adjust paths for your OS / install
RESTORE FILELISTONLY FROM DISK = N'C:\sqlbackups\AdventureWorksLT2022.bak';  -- see logical names

RESTORE DATABASE AdventureWorksLT2022
    FROM DISK = N'C:\sqlbackups\AdventureWorksLT2022.bak'
    WITH REPLACE, STATS = 10;
```

If SQL complains about the data/log paths in the `.bak`, add `MOVE` clauses using your server's data directory — for example `WITH MOVE 'AdventureWorksLT2022_Data' TO 'C:\SQLData\...'`.

Or run it from PowerShell in one line:
```powershell
Invoke-Sqlcmd -ServerInstance <your-server> -Username <login> -TrustServerCertificate `
    -Query "RESTORE DATABASE AdventureWorksLT2022 FROM DISK = N'C:\sqlbackups\AdventureWorksLT2022.bak' WITH REPLACE, STATS = 10" `
    -QueryTimeout 600
```

</details>

<details>
<summary><b>Azure SQL Database (PaaS)</b></summary>

Azure SQL DB does **not** support `RESTORE DATABASE FROM DISK`. Use one of these instead:

- **[Azure Data Studio / SSMS: Deploy Database to Azure SQL Database wizard](https://learn.microsoft.com/azure/azure-sql/database/migrate-to-database-from-sql-server)** — points at a local `.bacpac` / `.bak`
- **Import a `.bacpac`** via Azure Portal or `SqlPackage.exe`. Microsoft publishes an [AdventureWorksLT `.bacpac`](https://github.com/Microsoft/sql-server-samples/tree/master/samples/databases/adventure-works) you can import directly.
- Portal → your SQL server → *Import database* → point at the `.bacpac` in a storage account.

</details>

<details>
<summary><b>Just want to run the demo quickly? Use LocalDB or a Docker container</b></summary>

**SQL Server in Docker** (fastest, works on Mac/Linux/Windows):
```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=YourStrong!Passw0rd" \
    -p 1433:1433 --name mssql -d mcr.microsoft.com/mssql/server:2022-latest
docker cp AdventureWorksLT2022.bak mssql:/var/opt/mssql/backup/
docker exec -it mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong!Passw0rd' -C \
    -Q "RESTORE DATABASE AdventureWorksLT2022 FROM DISK = '/var/opt/mssql/backup/AdventureWorksLT2022.bak' WITH MOVE 'AdventureWorksLT2022_Data' TO '/var/opt/mssql/data/AdventureWorksLT2022.mdf', MOVE 'AdventureWorksLT2022_Log' TO '/var/opt/mssql/data/AdventureWorksLT2022_log.ldf'"
```

Then connect VSCode to `localhost,1433` as `sa` with the password above.

</details>

Already have `AdventureWorksLT2022` (or any DB with a `SalesLT` schema)? Skip this step.

#### Step 2 — Load the sample stored procedures

```powershell
# Clone the repo
git clone https://github.com/beniclark/sql-copilot-demo.git
cd sql-copilot-demo

# SQL authentication (prompts for password)
./scripts/load-demo-data.ps1 -ServerInstance <your-server-fqdn> -Username <login>

# …or Windows / Entra integrated auth
./scripts/load-demo-data.ps1 -ServerInstance localhost

# …or Azure SQL DB
./scripts/load-demo-data.ps1 `
    -ServerInstance myserver.database.windows.net `
    -Database AdventureWorksLT2022 `
    -Username sqladmin
```

The script tests the connection, verifies the DB exists, then executes every file in [`demo/sprocs/`](demo/sprocs/). All three use `CREATE OR ALTER`, so it's safe to re-run. See `./scripts/load-demo-data.ps1 -?` for full help.

Once it finishes, try:

```sql
EXEC SalesLT.usp_TopCustomersByRevenue @TopN = 5;
EXEC SalesLT.usp_ProductsInCategory    @CategoryName = 'Road Bikes';
EXEC SalesLT.usp_CustomerOrderHistory  @CustomerID = 29485;
```

### Presenter path: what `azd up` does for you

If you ran the full `azd up` flow above (for a fresh Azure VM), `scripts/bootstrap-sql.ps1` runs automatically on the VM via `az vm run-command` and:

1. Downloads `AdventureWorksLT2022.bak` from [Microsoft's sql-server-samples GitHub release](https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks).
2. Restores it as `AdventureWorksLT2022`, relocating files to `F:\data\` and `G:\log\`.
3. Creates the `demoadmin` SQL login and grants it `sysadmin`.

It does **not** load the sample sprocs — run `scripts/load-demo-data.ps1` afterward to do that:

```powershell
$fqdn = azd env get-value SQL_VM_FQDN
$pwd  = azd env get-value SQL_ADMIN_PASSWORD
./scripts/load-demo-data.ps1 -ServerInstance $fqdn -Username demoadmin -Password $pwd
```

> `scripts/bootstrap-sql.ps1` is hardcoded for in-VM execution (local `ServerInstance`, `F:\data\`/`G:\log\` paths, local `.bak` path). It is **not** intended to be run against a remote or existing server — attendees should use `load-demo-data.ps1` instead.

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
│   ├── postprovision.ps1     # prints connection banner
│   ├── bootstrap-sql.ps1     # runs ON the Azure VM; restores AdventureWorksLT + creates demoadmin
│   └── load-demo-data.ps1    # run from your laptop against any SQL Server to load sample sprocs
└── demo/
    ├── script.md             # presenter talk track
    ├── connection-profiles.md# VSCode MSSQL connection how-to
    ├── copilot-prompts.md    # NL→SQL, inline, explain, fix-it
    ├── sprocs/               # sample stored procedures (load after azd up)
    │   ├── usp_TopCustomersByRevenue.sql
    │   ├── usp_ProductsInCategory.sql
    │   └── usp_CustomerOrderHistory.sql
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
