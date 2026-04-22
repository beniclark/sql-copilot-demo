-- All orders placed by a given customer, with line-item counts.
-- Usage: EXEC SalesLT.usp_CustomerOrderHistory @CustomerID = 29485;
CREATE OR ALTER PROCEDURE SalesLT.usp_CustomerOrderHistory
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT soh.SalesOrderID,
           soh.OrderDate,
           soh.Status,
           soh.TotalDue,
           COUNT(sod.SalesOrderDetailID) AS LineItems
    FROM SalesLT.SalesOrderHeader soh
    LEFT JOIN SalesLT.SalesOrderDetail sod ON sod.SalesOrderID = soh.SalesOrderID
    WHERE soh.CustomerID = @CustomerID
    GROUP BY soh.SalesOrderID, soh.OrderDate, soh.Status, soh.TotalDue
    ORDER BY soh.OrderDate DESC;
END
GO
