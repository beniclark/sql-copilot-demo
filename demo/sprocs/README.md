# Sample stored procedures

Three small demo procedures in the `SalesLT` schema of `AdventureWorksLT2022`.

| File | What it does |
|---|---|
| `usp_TopCustomersByRevenue.sql` | Top N customers ranked by total revenue. |
| `usp_ProductsInCategory.sql` | Products in a named category (e.g. `'Road Bikes'`). |
| `usp_CustomerOrderHistory.sql` | All orders + line-item counts for a given customer. |

All three use `CREATE OR ALTER`, so they're safe to run repeatedly.

## Load them

Easiest: use the loader script against any SQL Server you already have.

```powershell
# SQL auth (prompts for password)
./scripts/load-demo-data.ps1 -ServerInstance <your-server-fqdn> -Username <login>

# Integrated auth
./scripts/load-demo-data.ps1 -ServerInstance localhost
```

The script verifies the connection, checks the target DB exists, then runs every `.sql` file in this folder. See the top-level [README](../../README.md#loading-data-into-the-database) for more options.

Or from VSCode: open each `.sql` file, connect the tab to your database, press **Ctrl+Shift+E**.

## Try them

```sql
EXEC SalesLT.usp_TopCustomersByRevenue @TopN = 5;
EXEC SalesLT.usp_ProductsInCategory    @CategoryName = 'Road Bikes';
EXEC SalesLT.usp_CustomerOrderHistory  @CustomerID = 29485;
```
