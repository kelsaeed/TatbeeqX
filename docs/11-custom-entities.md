# 11 — Custom entities

A **custom entity** is a user-defined table designed in the UI — not by writing Prisma models. The system creates the SQL table, generates CRUD endpoints, creates permissions, and adds a sidebar entry. The list/form UI is auto-built from the column config.

Where it lives:

- Page: `/custom-entities` (Super Admin only)
- Per-entity page: `/c/:code` (any user with `<code>.view`)
- Backend: [routes/custom_entities.js](../backend/src/routes/custom_entities.js), [routes/custom_records.js](../backend/src/routes/custom_records.js), [lib/custom_entity_engine.js](../backend/src/lib/custom_entity_engine.js)
- Frontend: [features/custom_entities/](../frontend/lib/features/custom_entities/) (designer), [features/custom/](../frontend/lib/features/custom/) (generic list + form dialog)

## Data model

```
custom_entities
  id
  code         unique, lowercase snake_case (e.g. "products")
  tableName    real SQL table name (validated `^[a-z][a-z0-9_]{0,62}$`)
  label        display label
  icon         optional icon key
  config       JSON: { columns: [ ColumnDef, ... ] }
```

`ColumnDef`:

```ts
{
  name: string;           // column name, snake_case, validated
  label: string;          // display label
  type: 'text' | 'longtext' | 'integer' | 'number' | 'bool' | 'date' | 'datetime' | 'relation';
  required?: boolean;
  unique?: boolean;
  searchable?: boolean;   // included in list `q` search
  showInList?: boolean;   // visible column on the list page
  defaultValue?: any;
  // for type: 'relation'
  relationEntity?: string;   // `code` of another entity
  relationDisplay?: string;  // column to display when picking
}
```

## Creating an entity from the UI

`/custom-entities → New entity`:

1. Pick a `code` (lowercase, snake_case).
2. Pick a `tableName` (defaults to the code).
3. Add columns. Mark each as required / unique / searchable / show-in-list as needed.
4. Save.

The backend then:

1. Validates the table and column names with `validateTableName`.
2. Runs `CREATE TABLE IF NOT EXISTS <tableName> (id INTEGER PRIMARY KEY AUTOINCREMENT, <columns mapped to SQLite types>, createdAt TEXT, updatedAt TEXT)`.
3. Inserts the `custom_entities` row.
4. Creates six permissions: `<code>.view, .create, .edit, .delete, .export, .print`.
5. Grants those to **Super Admin** and **Company Admin**.
6. Inserts a `menu_items` row for `/c/<code>` gated on `<code>.view`.
7. Triggers `MenuController.load()` on the next sidebar refresh.

## Generic CRUD (`/api/c/:code`)

Routes live in [routes/custom_records.js](../backend/src/routes/custom_records.js). They:

- Look up the entity by `code` from `custom_entities`.
- Resolve the real `tableName`.
- Build raw SQL using parametrized queries against that table.
- Permission-gate each method on `<code>.{view|create|edit|delete}`.
- Audit each mutation with `entity = <code>`, `entityId = <pk>`.

| Method | Path | Behavior |
|---|---|---|
| GET | `/api/c/:code` | Paginated list. `?page`, `?pageSize`, `?q` (matches any column where `searchable: true`). |
| GET | `/api/c/:code/:id` | Single record |
| POST | `/api/c/:code` | Insert. Body must satisfy `required` and `unique` constraints. |
| PUT | `/api/c/:code/:id` | Update |
| DELETE | `/api/c/:code/:id` | Delete |

## Generic UI

`/c/:code` renders:

- A page header with the entity label.
- A `paginated_search_table` with one column per `showInList: true` column.
- A "New" button that opens [custom_record_dialog.dart](../frontend/lib/features/custom/presentation/custom_record_dialog.dart). The dialog auto-builds inputs from the column types:
  - `text` → single-line `TextFormField`
  - `longtext` → multi-line `TextFormField`
  - `integer` / `number` → numeric input
  - `bool` → switch
  - `date` / `datetime` → date picker
  - `relation` → dropdown populated from the related entity's records (showing `relationDisplay` column)

Validation enforces `required` and `unique` client-side; the backend re-checks before insert/update.

## Editing the schema later

**Edits to the registration row update only the form/list config — they do not ALTER the SQL table.** This is intentional for safety: ALTER is destructive and the user might lose data without realizing.

To add or drop columns on an existing custom table:

1. Open `/database` (Database admin).
2. Run `ALTER TABLE <tableName> ADD COLUMN <name> <type>;` (or `DROP COLUMN`).
3. Go back to `/custom-entities`, edit the entity, update its column config to match.

This two-step is annoying. It is on the [roadmap](20-roadmap.md) to make `PUT /api/custom-entities/:id` diff the columns and run the necessary `ALTER TABLE` automatically.

## Identifier safety

Two validators in [`custom_entity_engine.js`](../backend/src/lib/custom_entity_engine.js):

- `validateTableName(name)` — strict (`^[a-z][a-z0-9_]{0,62}$`) — applied to anything *the user* names: entity codes, table names, column names.
- `validateIdent(name)` — permissive (`^[A-Za-z_][A-Za-z0-9_]{0,62}$`) — applied to the names the *Database admin* surfaces from Prisma's PascalCase tables (User, AuditLog, etc.).

Two validators because Prisma tables look like `User` and the explorer must be able to inspect them, but we never want a user-created table to be called `User`.
