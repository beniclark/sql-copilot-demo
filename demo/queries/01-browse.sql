-- 01-browse.sql
-- Demo step 1: browsing the database, no joins.
-- Audience learning goal: show that VSCode results grid feels familiar to SSMS.

USE AdventureWorksLT2022;
GO

-- Peek at the schema: every table in SalesLT
SELECT s.name AS [schema], t.name AS [table]
FROM   sys.tables t
JOIN   sys.schemas s ON s.schema_id = t.schema_id
WHERE  s.name = 'SalesLT'
ORDER  BY t.name;

-- Top 10 customers
SELECT TOP 10
       CustomerID, Title, FirstName, LastName, CompanyName, EmailAddress
FROM   SalesLT.Customer
ORDER  BY CustomerID;

-- Top 10 products
SELECT TOP 10
       ProductID, Name, ProductNumber, Color, ListPrice, StandardCost
FROM   SalesLT.Product
ORDER  BY ListPrice DESC;
