# Ola Electric — ER Diagram (Metafore SOR)

Interactive entity-relationship diagram for the Ola Electric app schema —
10 entities, 15 relationships, designed for the Metafore SOR (Supabase / Postgres).

**Live (dynamic) diagram:** https://adityaanand0707.github.io/ola-er-diagram/

- Hover a table or a `fk` row to highlight its relationship (`1:N`, crow's-foot).
- Drag table headers to rearrange · scroll to zoom · drag the canvas to pan · **Fit** to re-center.
- **Download SQL** / **Copy** buttons export the schema, byte-identical to `ola_supabase_schema.sql`.

| File | What it is |
|------|------------|
| [`index.html`](index.html) | Interactive diagram (this is what GitHub Pages serves). |
| [`static.html`](static.html) | No-JavaScript fallback (renders in SharePoint / email previews). |
| [`ola_er_diagram.svg`](ola_er_diagram.svg) | Standalone SVG of the diagram. |
| [`ola_supabase_schema.sql`](ola_supabase_schema.sql) | Paste-ready Supabase/Postgres DDL. |

> Synthetic schema for a Salesforce → Metafore migration demo. No real or personal data.
