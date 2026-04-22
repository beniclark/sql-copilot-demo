# Sample stored procedures

Three small demo procedures in the `SalesLT` schema of `AdventureWorksLT2022`.

| File | What it does |
|---|---|
| `usp_TopCustomersByRevenue.sql` | Top N customers ranked by total revenue. |
| `usp_ProductsInCategory.sql` | Products in a named category (e.g. `'Road Bikes'`). |
| `usp_CustomerOrderHistory.sql` | All orders + line-item counts for a given customer. |

All three use `CREATE OR ALTER`, so they're safe to run repeatedly.

## Load them

From your laptop (after `azd up`):

```powershell
$fqdn = azd env get-value SQL_VM_FQDN
$pwd  = azd env get-value SQL_ADMIN_PASSWORD
Get-ChildItem demo/sprocs/*.sql | ForEach-Object {
    Invoke-Sqlcmd -ServerInstance $fqdn -Database AdventureWorksLT2022 `
        -Username demoadmin -Password $pwd -TrustServerCertificate `
        -InputFile $_.FullName
}
```

Or in VSCode: open each `.sql` file, connect the tab to `AdventureWorksLT2022`, press **Ctrl+Shift+E**.

## Try them

```sql
EXEC SalesLT.usp_TopCustomersByRevenue @TopN = 5;
EXEC SalesLT.usp_ProductsInCategory    @CategoryName = 'Road Bikes';
EXEC SalesLT.usp_CustomerOrderHistory  @CustomerID = 29485;
```
