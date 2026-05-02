# 10 — Business presets

A **business preset** is a recipe that turns a fresh install into a domain-specific app: it creates SQL tables, registers them as custom entities, creates permissions, grants them to default roles, and adds sidebar entries — all in one call.

## Built-in presets

Defined in [backend/src/lib/business_presets.js](../backend/src/lib/business_presets.js):

| Preset | Code | Starter entities |
|---|---|---|
| Retail / POS | `retail` | products, customers, suppliers, sales, payments |
| Restaurant | `restaurant` | menu_items, tables, orders, reservations, customers |
| Clinic | `clinic` | patients, appointments, treatments |
| Factory | `factory` | products, raw_materials, work_orders, inventory_movements, suppliers |
| Finance office | `finance` | customers, invoices, accounts, transactions |
| Rental company | `rental` | assets, customers, rentals, payments |
| Blank slate | `blank` | none |

Each preset entry is a registry record:

```js
{
  code: 'retail',
  name: 'Retail / POS',
  description: 'Products, customers, suppliers, sales, payments.',
  icon: 'storefront',
  entities: [
    { code: 'products', label: 'Products', tableName: 'products',
      columns: [
        { name: 'sku',   label: 'SKU',   type: 'text', required: true, unique: true },
        { name: 'name',  label: 'Name',  type: 'text', required: true, searchable: true, showInList: true },
        { name: 'price', label: 'Price', type: 'number', required: true, showInList: true },
        ...
      ]
    },
    ...
  ]
}
```

Column types: `text`, `longtext`, `integer`, `number`, `bool`, `date`, `datetime`, `relation`. Mapped to SQLite types in [`custom_entity_engine.js`](../backend/src/lib/custom_entity_engine.js).

## Applying a preset

### From the UI (Setup Wizard)

A fresh install lands a Super Admin on `/setup`. The wizard calls `POST /api/business/apply` with the chosen code. The redirect lives in [app_router.dart](../frontend/lib/routing/app_router.dart) and reads from `setupControllerProvider`.

### From the API

```bash
curl -X POST http://localhost:4000/api/business/apply \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"code": "retail"}'
```

Super Admin only. Returns `{ applied: true, code, entityCount }`.

### From the seeder (before first run)

```ini
# backend/.env
SEED_BUSINESS_TYPE=retail
```

Then `npm run db:reset`. The seeder calls `applyPreset` once it finishes seeding the foundation rows.

## What the apply step does

1. For each entity in the preset, runs `CREATE TABLE IF NOT EXISTS <tableName> (id INTEGER PRIMARY KEY AUTOINCREMENT, <columns>, createdAt TEXT, updatedAt TEXT)` via `prisma.$executeRawUnsafe`.
2. Inserts a row into `custom_entities` with the column config JSON.
3. For each entity creates `<code>.{view, create, edit, delete, export, print}` permissions.
4. Grants all six to the **Super Admin** and **Company Admin** roles.
5. Inserts a `menu_items` row pointing to `/c/<code>` gated on `<code>.view`.
6. Writes `settings.system.business_type = '<code>'`.

After it finishes, the sidebar (driven by `MenuController.load()`) refreshes and the new entries appear.

## State

Read with `GET /api/business/state`:

```json
{ "applied": true, "code": "retail", "entityCount": 5 }
```

`applied: false` triggers the Setup Wizard redirect.

## Adding your own preset

1. Add an entry to the registry in [`backend/src/lib/business_presets.js`](../backend/src/lib/business_presets.js).
2. Pick a unique `code`. `tableName` and column `name` values must match `^[a-z][a-z0-9_]{0,62}$`.
3. Re-seed or restart the backend — presets are read at request time so a process restart is enough.

A preset is just a JSON-ish blob in code. It does not ship its own SQL — the engine generates SQL from the column types.

## Re-applying a preset

Re-applying is safe (`CREATE TABLE IF NOT EXISTS`, permission upserts). It will not drop columns. To evolve a custom entity's schema, use the [Database admin](12-database-admin.md) page to run `ALTER TABLE`, then update the entity's column config — see the pitfalls list for the rationale.
