# 21 — Page Builder

User-designed pages, composed from blocks. Lives at `/pages` (designer index) and `/pages/edit/:id` (builder).

- Backend: [routes/pages.js](../backend/src/routes/pages.js)
- Frontend: [features/pages/](../frontend/lib/features/pages/)
- Models: `Page`, `PageBlock` in [schema.prisma](../backend/prisma/schema.prisma)

## Concept

A **Page** is a row with a unique `code` and a `route` (e.g. `/welcome`, `/sales/overview`). It belongs nowhere in particular — it shows up in the sidebar (when `showInSidebar: true`) and renders at its `route`.

A page is composed of **PageBlocks**, ordered by `sortOrder`, optionally nested through `parentId`. Each block has a `type` (e.g. `text`, `image`, `button`, `card`, `table`, `chart`, `iframe`, `html`, `custom_entity_list`, `report`) and a free-form `config` JSON.

## Block types

| Type | Config |
|---|---|
| `text` | `{ text }` |
| `heading` | `{ text, level: 1..6 }` |
| `image` | `{ url, fit: 'cover'|'contain'|'fill' }` |
| `button` | `{ label, route, variant: 'filled'|'outlined'|'text' }` |
| `card` | `{ title, body }` |
| `container` | `{ direction: 'row'|'column', gap }` — child blocks reference this via `parentId` |
| `divider` | `{}` |
| `spacer` | `{ height }` |
| `list` | `{ items: [{label, sub?}, …] }` |
| `table` | `{ columns: [{key,label,type}], rows: [[…], …] }` |
| `chart` | `{ kind: 'bar'|'line'|'pie', data: [{label, value}, …] }` |
| `iframe` | `{ url, height }` |
| `html` | `{ html }` (sanitized server-side TBD) |
| `custom_entity_list` | `{ entityCode, pageSize? }` — embeds a paginated list of a custom entity |
| `report` | `{ reportCode, mode: 'table'|'chart' }` — embeds a report runner |

The list is open-ended — add more `type` keys as you grow.

## Permissions

The standard module has actions: `pages.view`, `pages.create`, `pages.edit`, `pages.delete`. Granted to **Super Admin** and **Company Admin** by default.

Each `Page` row may set its own `permissionCode` — a permission required to *view that page*. If null, anyone authed can see it. The `/pages/sidebar` endpoint filters by this.

## Endpoints

| Method | Path | Permission |
|---|---|---|
| GET | `/api/pages` | `pages.view` |
| GET | `/api/pages/sidebar` | auth (server filters by `permissionCode`) |
| GET | `/api/pages/by-route?route=/foo` | auth |
| GET | `/api/pages/:id` | `pages.view` |
| POST | `/api/pages` | `pages.create` |
| PUT | `/api/pages/:id` | `pages.edit` |
| DELETE | `/api/pages/:id` | `pages.delete` |
| POST | `/api/pages/:id/blocks` | `pages.edit` |
| PUT | `/api/pages/:id/blocks/:blockId` | `pages.edit` |
| DELETE | `/api/pages/:id/blocks/:blockId` | `pages.edit` |
| POST | `/api/pages/:id/reorder` | `pages.edit` (body: `{ order: [{id, parentId?}, …] }`) |

## Today vs. roadmap

**Today (Phase 4.1):**
- Designer at `/pages` (create / list / delete pages).
- Builder at `/pages/edit/:id` with:
  - Add-block palette of 15 types
  - **Drag handles** for reordering top-level blocks (calls `POST /api/pages/:id/reorder`)
  - **Move to container** popup on every block — assign to any `container`/`card` block, or back to top level (calls `PUT /api/pages/:id/blocks/:blockId` with `parentId`)
  - Children render indented under their parent
  - Block config edited as JSON in a single universal editor
- **PageRenderer** at `/p/:code` (also accepts a `route` parameter) fetches the page + blocks and renders each type as a real Flutter widget. Charts use a custom-painted bar/pie list (no extra dep).
- Custom pages auto-appear in the sidebar via `/api/pages/sidebar` → `MenuController` merge → linked to `/p/:code`.

**Phase 4.4 additions:**
- ✅ **Typed inspectors** for `text`, `heading`, `image`, `button`, `card`, `spacer`, `iframe`, `html`, `report`, `custom_entity_list`, `divider`. Block types not in the list fall back to the JSON editor automatically. See [features/pages/presentation/block_inspectors.dart](../frontend/lib/features/pages/presentation/block_inspectors.dart).
- ✅ **HTML sanitization** server-side via `sanitize-html` ([lib/html_sanitize.js](../backend/src/lib/html_sanitize.js)) on every PageBlock create/update where `type === 'html'`. Strips `<script>`, on-event attributes, and `javascript:` URLs. Whitelist of presentational tags + a small set of inline-style properties.

**Still open (deferred):**
- **Conditional visibility per block** (`config.visibleWhen: { permission, roleCode }`).
- **iframe rendering on web build** — placeholder text on desktop, real `<iframe>` on web.

## Designing safely

- The route validator forbids anything outside `/[a-zA-Z0-9_\-/]{0,120}`. Don't try to register `/users` (collides with a core route).
- The `code` is lowercase snake_case, like custom entities.
- Pages survive a `prisma db push` (data is preserved). They are also captured by the **full** template kind once that integration ships ([20-roadmap.md](20-roadmap.md)).
