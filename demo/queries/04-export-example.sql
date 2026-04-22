-- 04-export-example.sql
-- Demo step 4: a query whose result set we'll export to CSV from the VSCode grid.
-- Right-click the result grid -> "Save as CSV".

USE AdventureWorksLT2022;
GO

SELECT  soh.SalesOrderID,
        soh.OrderDate,
        c.FirstName + ' ' + c.LastName       AS CustomerName,
        c.CompanyName,
        p.Name                                AS Product,
        sod.OrderQty,
        sod.UnitPrice,
        sod.LineTotal
FROM    SalesLT.SalesOrderHeader        soh
JOIN    SalesLT.SalesOrderDetail        sod ON sod.SalesOrderID = soh.SalesOrderID
JOIN    SalesLT.Customer                c   ON c.CustomerID     = soh.CustomerID
JOIN    SalesLT.Product                 p   ON p.ProductID      = sod.ProductID
ORDER BY soh.OrderDate DESC, soh.SalesOrderID;
