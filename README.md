# Ola for Business — ER Diagram (Metafore SOR)

Interactive entity-relationship diagram for the **Ola for Business** B2B CRM —
4 entities, 5 relationships, designed for the Metafore SOR (Supabase / Postgres).
Ola's corporate arm selling ride accounts to enterprises (Infosys, TCS, …).

**Live (dynamic) diagram:** https://adityaanand0707.github.io/ola-er-diagram/

**Entities:** `account` · `contact` · `opportunity` · `case`
**Relationships (1:N, crow's-foot):**
- `account → contact` (account has many contacts)
- `account → opportunity` (account has many opportunities)
- `account → case` (account has many cases)
- `contact → case` (contact raises cases)
- `account → account` (self-hierarchy: holding company → subsidiary)

- Hover a table or a `fk` row to highlight its relationship.
- Drag table headers to rearrange · scroll to zoom · drag the canvas to pan · **Fit** to re-center.
- **Download SQL** / **Copy** buttons export the schema, identical to `ola_for_business_schema.sql`.

| File | What it is |
|------|------------|
| [`index.html`](index.html) | Interactive diagram (this is what GitHub Pages serves). |
| [`static.html`](static.html) | No-JavaScript fallback (renders in SharePoint / email previews). |
| [`ola_for_business_schema.sql`](ola_for_business_schema.sql) | Reference Supabase/Postgres DDL. |

> **Supabase upload:** not required as a manual step — Metafore Maker generates these
> tables from the Maker BRD on ingest. The `.sql` is a reference / documentation copy.

> Demo schema for a Salesforce → Metafore migration. Mock data only — no real or personal data.
