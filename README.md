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
