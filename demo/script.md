# Presenter Talk Track — VSCode as a SQL Development Tool

> Total running time: ~20 minutes + Q&A. Adjust depth per segment to fit the room.

## Before the demo
- [ ] `azd up` has completed (do this ~30 min before showtime; allow time for the AdventureWorksLT restore).
- [ ] VSCode open on a blank window, MSSQL extension + GitHub Copilot installed, signed in.
- [ ] Copy the server FQDN and passwords somewhere quickly accessible:
  ```powershell
  azd env get-values | Select-String 'SQL_VM_FQDN|SQL_ADMIN_LOGIN|SQL_ADMIN_PASSWORD|ENTRA_ADMIN_UPN'
  ```
- [ ] Close any existing editors. Start with a clean workspace.

---

## Opening (1 min)

> "Everyone raise your hand if you've used SQL Server Management Studio. Now keep it up if you've also written TypeScript, Python, or anything non-SQL in the last week.
>
> That's the problem we're solving today. Most data engineers and full-stack developers live in VSCode 90% of the day, then context-switch to SSMS the moment they touch a database. In the next 20 minutes I'll show you that you don't have to."

## Segment 1 — Install VSCode + MSSQL extension (2 min)

1. Show Extensions marketplace (Ctrl+Shift+X).
2. Search "SQL Server", point to publisher "Microsoft" (`ms-mssql.mssql`) — **5M+ downloads**.
3. Click install. Explain it brings:
   - Connection manager
   - Object Explorer (tables/views/procs)
   - Query editor with IntelliSense
   - Results grid with CSV/JSON/Excel export

## Segment 2 — Connect to Azure SQL Server (3 min)

Walk through both auth modes from `demo/connection-profiles.md`.

1. **Entra ID first.** Ctrl+Shift+P → `MS SQL: Add Connection`. Emphasize: no password stored anywhere, MFA in your existing browser session.
2. Open the saved profile in the sidebar; the tree pops open.
3. Quickly show **SQL auth** as a fallback option — useful for legacy systems.

> "Under the hood this is the same TDS protocol SSMS uses. It's not a transpiler or a wrapper."

## Segment 3 — Browse like SSMS (2 min)

- Expand **Databases → AdventureWorksLT2022 → Tables → SalesLT.Customer**.
- Right-click → **Select Top 1000** — audience sees the SSMS reflex still works.
- Expand **Views** and **Programmability → Stored Procedures** to show they're all there.
- Hover any column — IntelliSense pops a quick info card with the data type.

## Segment 4 — Run a query, view results, export CSV (3 min)

1. Open `demo/queries/01-browse.sql`. Press **Ctrl+Shift+E** (or the "Run" icon).
2. Point out the results grid:
   - Column sort by click
   - Filter by column header
   - Copy with headers
3. Open `demo/queries/04-export-example.sql`, run it.
4. In the results grid, click the **Save as CSV** icon in the top-right of the grid toolbar.
5. Open the CSV in a new VSCode tab — all in one window.

## Segment 5 — GitHub Copilot ⚡ the big reveal (7 min)

Follow `demo/copilot-prompts.md`. Structure:

### Natural language → SQL (2 min)
Open an empty `scratch.sql`, connect it to `AdventureWorksLT2022`. In Copilot Chat:
- `#mssql Write a query that returns the top 10 customers by lifetime order total from AdventureWorksLT. Include full name, company, total orders, and total spend.`

Walk through the result. Highlight:
- **Correct JOIN path** across `Customer` / `SalesOrderHeader`.
- Uses `SUM(TotalDue)`, a real column Copilot learned from the connection schema.

### Inline completion (1.5 min)
In a fresh file, type `-- Products that have never been ordered` and press Enter. Accept with Tab. Run it.

### Explain existing SQL (1.5 min)
Open `demo/queries/02-joins-aggregates.sql`, select the first query, run `@workspace /explain`. Great onboarding story.

### Fix-it demo (2 min)
Paste the broken query from `demo/copilot-prompts.md` section D. Ask Copilot to fix it. Talk through the two bugs it finds (missing GROUP BY; LEFT-JOIN-becomes-INNER via WHERE).

## Wrap-up & Q&A (2 min)

> "The whole flow — install, connect, browse, query, export, Copilot — runs on Windows, macOS, and Linux. It works against SQL Server, Azure SQL Database, Managed Instance, and Synapse. And you get an AI pair programmer that knows your schema for free."

Close with:
- "One VSCode window. Three auth modes. Zero context switches."
- Point to `README.md` and the repo; offer to stay after for one-on-one questions.
- **Run `azd down --purge --force`** as soon as you leave the room so the VM bill stops.

## Anticipated Q&A

| Question | Answer |
|---|---|
| Can I debug T-SQL / step through a stored proc? | Yes, via the [SQL Database Projects extension](https://marketplace.visualstudio.com/items?itemName=ms-mssql.sql-database-projects-vscode). |
| Does it support Always On / AGs? | Read from any replica you connect to — same as SSMS. |
| Source control for stored procs? | Use **SQL Database Projects** + your repo. Git diffs on `.sql` files. |
| Will my team's SSMS snippets still work? | Copy them into VSCode User Snippets; same T-SQL, same syntax. |
| Copilot on private/offline data? | Copilot Chat for Business does not retain prompts; for fully offline, use Copilot Enterprise with your own private LLM. |
| What about query plans? | Right-click an editor tab → "Explain Query Plan" shows a visual plan. |
