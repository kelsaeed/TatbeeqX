# 06 — Modules

A *module* is a self-contained feature: backend route file + frontend feature folder + a permission set + (optionally) a sidebar entry. The 13 core modules are seeded by [backend/prisma/seed.js](../backend/prisma/seed.js). Custom-entity modules are added at runtime by applying a business preset or creating an entity.

## Core modules

| Code | Sidebar route | Backend route file | Frontend feature folder | Notes |
|---|---|---|---|---|
| `dashboard` | `/dashboard` | `routes/dashboard.js` | `features/dashboard/` | Cards + charts (audit-by-day, audit-by-entity) |
| `companies` | `/companies` | `routes/companies.js` | `features/companies/` | Multi-company root |
| `branches` | `/branches` | `routes/branches.js` | `features/companies/` | Branches belong to a company |
| `users` | `/users` | `routes/users.js` | `features/users/` | Users + roles tab + per-user permission overrides |
| `roles` | `/roles` | `routes/roles.js` | `features/roles/` | Role list + permission matrix |
| `permissions` | (no sidebar) | `routes/permissions.js` | (folded into roles) | Catalog endpoint only |
| `audit` | `/audit` | `routes/audit.js` | `features/audit/` | Filterable, paginated audit-log viewer |
| `settings` | `/settings` | `routes/settings.js` | `features/settings/` | Key/value system settings |
| `themes` | `/themes` | `routes/themes.js` | `features/themes/` | Theme builder (Super Admin) |
| `reports` | `/reports` | `routes/reports.js` | `features/reports/` | Report runner + chart toggle |
| `database` | `/database` | `routes/database.js` | `features/database/` | Table explorer + SQL runner (Super Admin) |
| `custom_entities` | `/custom-entities` | `routes/custom_entities.js`, `routes/custom_records.js` | `features/custom_entities/`, `features/custom/` | Define tables in UI; auto CRUD at `/c/<code>` |
| `templates` | `/templates` | `routes/templates.js` | `features/templates/` | Capture/apply theme + business setup |

Auxiliary surfaces with no module row: `auth`, `menus`, `business`, `uploads`. Their endpoints live under their own route files but they are not menu-driven.

## Business preset modules (at runtime)

When a preset is applied (or you create a custom entity), the system creates:

- A row in the `custom_entities` table
- A real SQL table named `<entity.tableName>`
- Six permissions: `<code>.{view, create, edit, delete, export, print}`
- A `menu_items` row for `/c/<code>` gated on `<code>.view`

Example presets — see [10-business-presets.md](10-business-presets.md):
- **Retail**: products, customers, suppliers, sales, payments
- **Restaurant**: menu_items, tables, orders, reservations, customers
- **Clinic**: patients, appointments, treatments
- **Factory**: products, raw_materials, work_orders, inventory_movements, suppliers
- **Finance office**: customers, invoices, accounts, transactions
- **Rental**: assets, customers, rentals, payments
- **Blank**: no entities — define your own

## Adding a new core module

If you want a *first-class* module (not a custom entity):

1. Add a Prisma model and migration.
2. Create `backend/src/routes/<module>.js` and register it in `routes/index.js`.
3. Append the module to the `MODULES` array in `seed.js` with its actions and (optional) menu entry. Re-run `npm run db:reset` (or hand-insert via SQL).
4. Create `frontend/lib/features/<module>/` with the four standard subfolders (`data`, `application`, `domain`, `presentation`).
5. Add the route to `frontend/lib/routing/app_router.dart`.

The dashboard sidebar populates itself from `/api/menus`, so once the menu row exists and the user has `<module>.view`, the link appears automatically.

## Module-vs-entity decision

| Use a **core module** when | Use a **custom entity** when |
|---|---|
| You need custom UI | A generic list + form is enough |
| You need custom backend logic (calculations, integrations) | Plain CRUD against one table is enough |
| You want compile-time guarantees on the schema | The user should be able to add columns from the UI |
| You are shipping it to all installs | It is specific to one customer's setup |
