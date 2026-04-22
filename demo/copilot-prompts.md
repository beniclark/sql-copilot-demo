# GitHub Copilot Prompts — NL → SQL, schema Q&A, fix-it

Run these in a `.sql` file that's connected to **AdventureWorksLT2022**. The MSSQL extension feeds Copilot the current connection schema so the suggestions are grounded in the real tables.

## Segment A — Natural language → SQL (Copilot Chat)

Open Copilot Chat (Ctrl+Alt+I) and try these prompts, one by one:

1. `#mssql Write a query that returns the top 10 customers by lifetime order total from AdventureWorksLT. Include full name, company, total orders, and total spend.`
2. `#mssql Show monthly revenue for 2008, broken down by product category. Use SalesLT.SalesOrderHeader / SalesOrderDetail / Product / ProductCategory.`
3. `#mssql Find products that have never been ordered.`
4. `#mssql For each salesperson in SalesLT.Customer (column SalesPerson), show how many distinct customers they have and their total customer revenue. Order by revenue desc.`

> **Talk track:** point out that Copilot infers the correct JOIN path because the MSSQL extension is exposing the schema via `#mssql` context. No manual schema copy/paste.

## Segment B — Inline completion

1. Create a new file `scratch.sql`, set language to SQL, connect to `AdventureWorksLT2022`.
2. Type the comment and press Enter — Copilot should suggest the query:
   ```sql
   -- Top 5 products by quantity sold, including product name and category
   ```
3. Accept with **Tab**. Run it.
4. Another one to try:
   ```sql
   -- List customers in Washington state who bought more than 3 distinct products
   ```

## Segment C — Explain existing code

1. Open `demo/queries/02-joins-aggregates.sql`.
2. Select the first query.
3. Ctrl+Alt+I → `@workspace /explain`
4. Discuss how Copilot walks the JOINs and GROUP BY clause in plain English — useful for onboarding engineers.

## Segment D — Fix-a-broken-query

Paste this deliberately broken query into chat with prompt `#mssql Fix this query:`:

```sql
SELECT TOP 10
       c.CustomerId,
       c.FirstName + ' ' + c.LastName,
       SUM(soh.TotalDue)
FROM   SalesLT.Customer c
LEFT   JOIN SalesLT.SalesOrderHeader soh on soh.CustomerId = c.CustomerId
WHERE  soh.OrderDate > '2008-01-01'
ORDER  BY SUM(soh.TotalDue) DESC;
```

Copilot should:
- Add the missing `GROUP BY` clause.
- Point out that the `LEFT JOIN` combined with the `WHERE` on the right-side table effectively makes it an `INNER JOIN`, and suggest moving the date filter into the `ON`.
- Alias the computed column.

## Segment E — Generate test data / DDL

Last 60 seconds of the demo, close the loop:

- `#mssql Generate a CREATE TABLE statement for a new SalesLT.ProductReview table that references Product, stores a 1-5 rating, a review body, and a review date. Include appropriate FK and a check constraint.`
- `#mssql Generate 10 INSERT statements for my new SalesLT.ProductReview table using real ProductIDs.`

Run them, then query the new table — tangible proof that Copilot accelerates schema evolution, not just read queries.
