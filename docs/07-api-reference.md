# 07 — API reference

Base URL (dev): `http://localhost:4040/api`
Base URL (LAN client): `http://<host-lan-ip>:4040/api`

All endpoints (other than `/auth/login`, `/auth/refresh`, `/themes/active`, `/health`) require a valid `Authorization: Bearer <accessToken>` header. The Flutter `ApiClient` attaches this automatically and refreshes on 401.

## Auth

| Method | Path | Notes |
|---|---|---|
| POST | `/auth/login` | body: `{ identifier, password }` (username **or** email) → `{ user, accessToken, refreshToken, permissions[] }` |
| POST | `/auth/refresh` | body: `{ refreshToken }` → new `{ accessToken, refreshToken }` |
| GET  | `/auth/me` | current user + roles + effective permissions |
| POST | `/auth/change-password` | body: `{ currentPassword, newPassword }` |
| POST | `/auth/logout` | revokes current refresh token |

## Users

| Method | Path | Permission |
|---|---|---|
| GET | `/users` | `users.view` (supports `?page`, `?pageSize`, `?q`, `?roleId`, `?companyId`) |
| GET | `/users/:id` | `users.view` |
| POST | `/users` | `users.create` |
| PUT | `/users/:id` | `users.edit` |
| DELETE | `/users/:id` | `users.delete` |
| POST | `/users/:id/roles` | `users.manage_users` — body `{ roleIds: [] }` |
| POST | `/users/:id/permissions` | `users.manage_users` — body `{ grants: [], revokes: [] }` |

## Roles

| Method | Path | Permission |
|---|---|---|
| GET | `/roles` | `roles.view` |
| GET | `/roles/:id` | `roles.view` (includes permission ids) |
| POST | `/roles` | `roles.create` |
| PUT | `/roles/:id` | `roles.edit` |
| DELETE | `/roles/:id` | `roles.delete` (system roles cannot be deleted) |
| POST | `/roles/:id/permissions` | `roles.manage_roles` — body `{ permissionIds: [] }` |

## Permissions

| Method | Path | Permission |
|---|---|---|
| GET | `/permissions` | `permissions.view` (full catalog grouped by module) |

## Companies / Branches

| Method | Path | Permission |
|---|---|---|
| GET / POST / PUT / DELETE | `/companies` | `companies.*` |
| GET / POST / PUT / DELETE | `/branches` | `branches.*` (filter by `?companyId=`) |

## Menus

| Method | Path | Permission |
|---|---|---|
| GET | `/menus` | requires auth — server filters by user permissions |

## Audit

| Method | Path | Permission |
|---|---|---|
| GET | `/audit` | `audit.view` (`?entity`, `?action`, `?actorId`, `?from`, `?to`, `?page`, `?pageSize`) |
| GET | `/audit/export` | `audit.export` (CSV) |

## Settings

| Method | Path | Permission |
|---|---|---|
| GET | `/settings` | `settings.view` |
| PUT | `/settings` | `settings.manage_settings` (body: `{ key, value, scope }`) |

## Themes

| Method | Path | Permission |
|---|---|---|
| GET | `/themes/active` | **public** — read by every client at boot |
| GET | `/themes` | `themes.view` |
| POST | `/themes` | `themes.manage_settings` |
| PUT | `/themes/:id` | `themes.manage_settings` |
| DELETE | `/themes/:id` | `themes.manage_settings` |
| POST | `/themes/:id/activate` | `themes.manage_settings` |
| POST | `/themes/:id/duplicate` | `themes.manage_settings` |
| POST | `/themes/:id/reset` | `themes.manage_settings` |

## Dashboard

| Method | Path | Permission |
|---|---|---|
| GET | `/dashboard/summary` | `dashboard.view` |
| GET | `/dashboard/audit-by-day` | `dashboard.view` (`?days=14`) |
| GET | `/dashboard/audit-by-module` | `dashboard.view` (`?days=30`) |

## Reports

| Method | Path | Permission |
|---|---|---|
| GET | `/reports` | `reports.view` (`?category=`) |
| GET | `/reports/:id` | `reports.view` |
| POST | `/reports/:id/run` | `reports.view` — body `{ params }` |
| POST | `/reports` | `reports.create` |
| PUT | `/reports/:id` | `reports.edit` |
| DELETE | `/reports/:id` | `reports.delete` |

Available builders (keys into [backend/src/lib/reports.js](../backend/src/lib/reports.js)):
- `users.by_role`
- `users.active_status`
- `companies.summary`
- `audit.actions_summary`
- `audit.entities_summary`

## Uploads

| Method | Path | Permission |
|---|---|---|
| POST | `/uploads/image` | auth required — multipart `file` field, max 5 MB, PNG/JPEG/WebP/GIF/SVG/ICO |

Response: `{ url: "/uploads/<filename>" }`. Files served by the static handler at `/uploads/<filename>`.

## Business presets

| Method | Path | Permission |
|---|---|---|
| GET | `/business/presets` | auth — list all presets |
| GET | `/business/state` | auth — `{ applied, code, entityCount }` |
| POST | `/business/apply` | super-admin only — body `{ code }` |

## Database admin (Super Admin)

| Method | Path |
|---|---|
| GET | `/db/tables` (with row counts + DDL) |
| GET | `/db/tables/:name` (columns, FKs, indexes) |
| GET | `/db/tables/:name/preview?limit=50` |
| POST | `/db/query` (body `{ sql, allowWrite? }`) |
| GET / POST / PUT / DELETE | `/db/queries` (saved queries) |

## Custom entities (Super Admin)

| Method | Path |
|---|---|
| GET | `/custom-entities` |
| POST | `/custom-entities` |
| PUT | `/custom-entities/:id` |
| DELETE | `/custom-entities/:id` |

Generic CRUD (any authed user with the right permission):

| Method | Path | Permission |
|---|---|---|
| GET | `/c/:code` | `<code>.view` |
| POST | `/c/:code` | `<code>.create` |
| PUT | `/c/:code/:id` | `<code>.edit` |
| DELETE | `/c/:code/:id` | `<code>.delete` |

## Templates (Super Admin)

| Method | Path |
|---|---|
| GET | `/templates` |
| GET | `/templates/:id` |
| POST | `/templates/capture` (body `{ name, kind: "theme"|"business"|"full" }`) |
| POST | `/templates/:id/apply` |
| POST | `/templates/import` (body `{ data }`) |
| DELETE | `/templates/:id` |

## Health

| Method | Path |
|---|---|
| GET | `/health` (public) |

## Static

`/uploads/<filename>` is served directly by Express (no `/api` prefix). The Flutter `LocalFileUploadField` builds the full URL by stripping `/api` from the configured base.
