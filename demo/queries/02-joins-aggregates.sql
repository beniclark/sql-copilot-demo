-- 02-joins-aggregates.sql
-- Demo step 2: joins + GROUP BY. Show IntelliSense kicking in.

USE AdventureWorksLT2022;
GO

-- Revenue by product category
SELECT  pc.Name                              AS Category,
        COUNT(DISTINCT soh.SalesOrderID)     AS Orders,
        SUM(sod.LineTotal)                   AS Revenue
FROM    SalesLT.SalesOrderHeader       soh
JOIN    SalesLT.SalesOrderDetail       sod ON sod.SalesOrderID   = soh.SalesOrderID
JOIN    SalesLT.Product                p   ON p.ProductID        = sod.ProductID
JOIN    SalesLT.ProductCategory        pc  ON pc.ProductCategoryID = p.ProductCategoryID
GROUP BY pc.Name
ORDER BY Revenue DESC;

-- Month-over-month order totals
SELECT  DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS Month,
        COUNT(*)     AS OrderCount,
        SUM(TotalDue) AS TotalRevenue
FROM    SalesLT.SalesOrderHeader
GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)
ORDER BY Month;
