-- Products in a named category, sorted by price descending.
-- Usage: EXEC SalesLT.usp_ProductsInCategory @CategoryName = 'Road Bikes';
CREATE OR ALTER PROCEDURE SalesLT.usp_ProductsInCategory
    @CategoryName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.ProductID,
           p.Name,
           p.ProductNumber,
           p.Color,
           p.ListPrice,
           pc.Name AS CategoryName
    FROM SalesLT.Product p
    JOIN SalesLT.ProductCategory pc ON pc.ProductCategoryID = p.ProductCategoryID
    WHERE pc.Name = @CategoryName
    ORDER BY p.ListPrice DESC;
END
GO
