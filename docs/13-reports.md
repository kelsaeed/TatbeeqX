# 13 — Reports

The reports module runs server-side, registry-backed query builders and renders the result either as a table or a bar chart.

- Page: `/reports`
- Backend: [routes/reports.js](../backend/src/routes/reports.js), [lib/reports.js](../backend/src/lib/reports.js)
- Frontend: [features/reports/](../frontend/lib/features/reports/)

## How it works

A row in the `reports` table holds:

| Field | Purpose |
|---|---|
| `code` | unique slug (e.g. `users.by_role`) |
| `name`, `description`, `category` | UI metadata |
| `builder` | a key into the registry in `lib/reports.js` |
| `config` | JSON params (e.g. `{ days: 30 }`) |

The `builder` is **not raw SQL**. It is the name of a function in `lib/reports.js` that returns `{ columns, rows }`. This keeps user-defined reports safe — even if a Company Admin creates a `reports` row, they cannot inject SQL.

```
GET /api/reports                  → list reports (filter ?category=…)
GET /api/reports/:id              → single config
POST /api/reports/:id/run         → executes the builder with config (overridable in body)
                                    returns { columns: [{key,label,type}], rows: [{}, …] }
```

Endpoints for managing reports (`POST/PUT/DELETE /api/reports`) gate on the standard `reports.create/edit/delete` permissions.

## Seeded reports

| Code | What it shows |
|---|---|
| `users.by_role` | count of users assigned to each role |
| `users.active_status` | active vs inactive count |
| `companies.summary` | companies with branch and user counts |
| `audit.actions_summary` | audit events grouped by action over `config.days` (default 30) |
| `audit.entities_summary` | audit events grouped by target entity over `config.days` |

## Adding a report

1. Add a builder function in [lib/reports.js](../backend/src/lib/reports.js):

   ```js
   export const builders = {
     // ...existing builders
     'sales.by_month': async ({ months = 12 } = {}) => {
       const rows = await prisma.$queryRaw`
         SELECT strftime('%Y-%m', createdAt) AS month, SUM(total) AS revenue
         FROM sales
         GROUP BY month
         ORDER BY month DESC
         LIMIT ${months}
       `;
       return {
         columns: [
           { key: 'month',   label: 'Month',   type: 'text'   },
           { key: 'revenue', label: 'Revenue', type: 'number' },
         ],
         rows,
       };
     },
   };
   ```

2. Either seed a row in `reports.js` (the seeder), or `POST /api/reports`:

   ```bash
   curl -X POST http://localhost:4000/api/reports \
     -H 'Authorization: Bearer ...' \
     -H 'Content-Type: application/json' \
     -d '{
       "code":"sales.by_month",
       "name":"Sales by month",
       "category":"sales",
       "builder":"sales.by_month",
       "config":{"months":12}
     }'
   ```

The new report appears at `/reports` grouped under its category. Opening it runs the builder and renders the result.

## Table ↔ chart toggle

If the result has at least one numeric column, the runner page shows a **Chart** toggle. Numeric columns become bars; the first text-typed column becomes the X axis. Built with `fl_chart`.

## Column types in the schema

Each `column` returned by a builder is `{ key, label, type }`. Types currently understood:

- `text` — left-aligned string
- `number` — right-aligned formatted number
- `integer` — right-aligned, no decimals
- `date` / `datetime` — formatted with the user's locale
- `bool` — checkmark / cross

The runner formats based on `type`. Add new types as you need them in [features/reports/presentation/report_runner_page.dart](../frontend/lib/features/reports/presentation/).
