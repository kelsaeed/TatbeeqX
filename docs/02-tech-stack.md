# 02 — Tech stack

## Backend

- **Runtime**: Node.js 20+
- **Framework**: Express 4
- **ORM**: Prisma (SQLite dev provider; switch to `postgresql` or `mysql` when going online)
- **Auth**: JSON Web Tokens (access + refresh) with `jsonwebtoken`; passwords hashed with `bcryptjs`
- **Uploads**: `multer` writing to `backend/uploads/`; mounted as static at `/uploads`
- **Security/observability**: `helmet`, `cors`, `morgan`
- **Env loading**: `dotenv` via `src/config/env.js`

Lib helpers live under `backend/src/lib/`:
- `prisma.js` — singleton client
- `jwt.js` — access/refresh sign + verify
- `password.js` — hash + compare
- `permissions.js` — effective permission resolver (`roles ∪ grants − revokes`)
- `audit.js` — `audit(req, action, entity, entityId, before, after)`
- `http.js` — small response/error helpers
- `reports.js` — registry of report builders, each returns `{ columns, rows }`
- `sql_runner.js` — safe execution of arbitrary SQL (read-only by default; protected tables list)
- `custom_entity_engine.js` — generic CRUD against user-defined SQL tables; `validateTableName` (strict) and `validateIdent` (permissive for inspecting Prisma's PascalCase tables)
- `business_presets.js` — preset registry: retail, restaurant, clinic, factory, finance, rental, blank
- `db_introspect.js` — table list / columns / indexes / FKs
- `templates.js` — capture / apply / import / export of theme + business setup

## Frontend

- **Framework**: Flutter 3.41 (Windows desktop primary; web also enabled)
- **State**: Riverpod (`flutter_riverpod`)
- **Routing**: `go_router` with auth-guard redirect
- **HTTP**: `dio` with interceptors (token attach, refresh on 401, error mapping)
- **Charts**: `fl_chart`
- **Storage**: **plain `dart:io`** (`%APPDATA%\TatbeeqX\auth.json`) — **no `shared_preferences`, no native plugin**

> **No native Flutter plugins.** This is **deliberate** to avoid the Windows symlink requirement. Users do not need to enable Developer Mode. If a plugin sneaks back into `pubspec.yaml`, the `flutter run -d windows` build fails with `Building with plugins requires symlink support`.

## Conventions

### Backend
- **One file per route**, registered in `routes/index.js`.
- **Permission gate** every mutating route with `requirePermission('<module>.<action>')`. Super Admins bypass automatically.
- **Audit** every mutating route via `audit(req, action, entity, entityId, before, after)`. The `before/after` JSON is what the audit viewer renders.
- **Validation** with `express-validator` schemas in `middleware/validate.js`.
- **Compound unique with nullable column** — Prisma upsert can't set a null on the unique side. Always use `findFirst` then `update`/`create` instead. (Already applied in seeder, settings, business state.)

### Frontend
- One feature folder per module under `lib/features/<module>/` with `data/`, `application/`, `domain/`, `presentation/` subfolders.
- A repository class per feature (`*_repository.dart`) wrapping `ApiClient` calls.
- A controller class per feature (`*_controller.dart`) using `AsyncNotifier` or `StateNotifier`.
- Reusable widgets live in `lib/shared/widgets/` (e.g., `paginated_search_table.dart`, `local_file_upload_field.dart`, `page_header.dart`).
- Theme is read from `themeControllerProvider`; widgets that need theme-aware styling pull settings from there, not from hard-coded constants.

### Code style
- `analysis_options.yaml` is set to the default Flutter lints.
- Backend uses ES modules (`"type": "module"`).
- No semantic versioning yet — single mainline.

## Required tooling

| Tool | Min version | Notes |
|---|---|---|
| Node.js | 20.x | LTS recommended |
| npm | 10.x | comes with Node 20 |
| Flutter | 3.41 | run `flutter doctor` to verify |
| Visual Studio Build Tools | 2022 | needed for `flutter run -d windows` |
| Git | 2.x | optional but recommended |

VS Code with the Dart, Flutter, and ESLint extensions is the recommended IDE.
