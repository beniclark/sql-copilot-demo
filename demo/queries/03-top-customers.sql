-- 03-top-customers.sql
-- Demo step 3: a query the audience may have written by hand in SSMS.
-- Use this as the "before" example before asking Copilot to generate it.

USE AdventureWorksLT2022;
GO

SELECT TOP 10
        c.CustomerID,
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.CompanyName,
        COUNT(DISTINCT soh.SalesOrderID) AS Orders,
        SUM(soh.TotalDue)                AS LifetimeSpend
FROM    SalesLT.Customer         c
JOIN    SalesLT.SalesOrderHeader soh ON soh.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.CompanyName
ORDER BY LifetimeSpend DESC;
