-- Top N customers ranked by total revenue.
-- Usage: EXEC SalesLT.usp_TopCustomersByRevenue @TopN = 5;
CREATE OR ALTER PROCEDURE SalesLT.usp_TopCustomersByRevenue
    @TopN INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@TopN)
        c.CustomerID,
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.CompanyName,
        SUM(soh.TotalDue) AS TotalRevenue,
        COUNT(DISTINCT soh.SalesOrderID) AS OrderCount
    FROM SalesLT.Customer c
    JOIN SalesLT.SalesOrderHeader soh ON soh.CustomerID = c.CustomerID
    GROUP BY c.CustomerID, c.FirstName, c.LastName, c.CompanyName
    ORDER BY TotalRevenue DESC;
END
GO
