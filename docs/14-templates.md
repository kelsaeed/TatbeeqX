# 14 — Templates

A **template** is a captured snapshot of part of the system that you can apply to another install (or to the same install at a later date) by pasting JSON.

- Page: `/templates` (Super Admin only)
- Backend: [routes/templates.js](../backend/src/routes/templates.js), [lib/templates.js](../backend/src/lib/templates.js)
- Frontend: [features/templates/](../frontend/lib/features/templates/)

## Six flavors (Phase 4.2)

| Kind | Captures |
|---|---|
| `theme` | Active theme: name + the full settings JSON |
| `business` | Custom entities registry + their column configs + `business_type` setting |
| `pages` | Every custom page + its blocks (preserves parent/child block links via local ids) |
| `reports` | Every report row (`code`, `name`, `category`, `builder`, `config`) |
| `queries` | Every saved SQL query (`name`, `description`, `sql`, `isReadOnly`) |
| `full` | All of the above |

Canonical list at `GET /api/templates/kinds`. The supported list is also exported as `SUPPORTED_KINDS` from [`backend/src/lib/templates.js`](../backend/src/lib/templates.js).

## Storage

Stored in `system_templates`:

```
id   code             name              kind      data (JSON)
1    full-2026-q1     Q1 baseline       full      { theme, entities, businessType, pages, reports, queries }
2    light-blue       Light blue theme  theme     { theme: {...} }
3    landing-pages    Landing pages     pages     { pages: [{ blocks: […] }, …] }
4    seed-reports     Seeded reports    reports   { reports: [...] }
5    saved-sql        Saved SQL         queries   { queries: [...] }
```

The `data.kind` field is the source of truth on import. Older v1 templates (only `theme`/`business`/`full`) keep working — `version: 2` payloads are emitted by the current capture path.

## Endpoints

| Method | Path | Notes |
|---|---|---|
| GET | `/api/templates` | list all |
| GET | `/api/templates/:id` | single (the UI uses this to copy JSON to clipboard) |
| POST | `/api/templates/capture` | body `{ name, kind: 'theme'|'business'|'full' }` — captures the *current* state |
| POST | `/api/templates/:id/apply` | applies the template to the live system |
| POST | `/api/templates/import` | body `{ data }` — import a JSON pasted from another install |
| DELETE | `/api/templates/:id` | remove |

All Super Admin only.

## Capture

`POST /api/templates/capture` reads the current state and writes a `system_templates` row:

- For `theme`: copies the row with `isActive: true` (excluding `id`, timestamps, `isActive`, `isDefault`).
- For `business`: gathers every `custom_entities` row and the `settings.system.business_type` value.
- For `full`: both.

## Apply

`POST /api/templates/:id/apply` is the reverse:

- **Theme**: creates a *new* theme row (so the old active theme is preserved) and sets it active. The old theme is left in the table; you can switch back.
- **Business**:
  - For each entity in the snapshot:
    - If the SQL table already exists, it is *not* recreated. The registration row is updated (or inserted) so the column config matches the snapshot.
    - If the SQL table does not exist, `CREATE TABLE` is run.
  - Permissions for each entity are upserted; menu rows are upserted.
  - `settings.system.business_type` is overwritten.
- **Full**: both.

Apply is idempotent for the structural pieces (CREATE TABLE IF NOT EXISTS, permission upserts, menu upserts).

## Import

`POST /api/templates/import` body `{ data }` accepts the same JSON shape returned by `GET /api/templates/:id`. The UI lets you paste it into a textarea — a save creates a `system_templates` row that you can then **Apply**.

## Export

`GET /api/templates/:id` returns the full JSON. The UI's **Copy JSON** button serializes it and writes to the clipboard. Paste it into another install's `/templates → Import JSON`.

## Why three kinds

Real-world flows:

- A consultant builds a clinic's setup, captures `business`, and ships it to the next clinic.
- A designer perfects a theme, captures `theme`, and applies it across all installs.
- A new install bootstraps a customer-specific config — capture once with `full` and ship.

## Apply behavior — per kind

- **Theme**: creates a *new* theme row (so the old active theme is preserved) and sets it active.
- **Business**: re-runs `registerCustomEntity` for each entity (creates the SQL table if missing, upserts permissions + menu rows). Existing tables are not dropped.
- **Pages**: upserts pages by `code` (or `route`); deletes old blocks and recreates them. Block parent links are preserved via `localId`/`parentLocalId` two-pass insert.
- **Reports**: upserts by `code`. `builder` must match a registered key in [`lib/reports.js`](../backend/src/lib/reports.js); unknown builders will fail when the report is run, but the row will still be created.
- **Queries**: upserts by `name`. SQL is stored verbatim — applying does not run it.

## Caveats

- Apply does **not** copy data rows from custom entities. It only re-creates *structure*.
- Apply does **not** copy users, roles, or permissions beyond the per-entity permissions it generates. Auth is install-specific.
- Reports are captured by their `builder` key — the builder function itself must already exist in `lib/reports.js` on the target install.
