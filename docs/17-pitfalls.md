# 17 — Common pitfalls

Things that have actually broken — and what fixed them.

## Login fails / spinner forever

**Symptom**: The login screen says `Cannot reach the server at http://localhost:4040/api`, or the spinner spins indefinitely.

**Cause**: The backend is not running.

**Fix**: Open a terminal and start it.
```bash
cd backend
npm run dev
```
If it is already running, check that nothing else is on PORT 4040 (`netstat -ano | findstr :4040`).

## "Building with plugins requires symlink support"

**Symptom**: `flutter run -d windows` fails with this error.

**Cause**: A native Flutter plugin slipped back into `pubspec.yaml`.

**Fix**: Remove the plugin. The Windows desktop build is intentionally plugin-free so users do not need Developer Mode. Use `dart:io` instead of `path_provider`/`shared_preferences`/`file_picker`. The repo already does this — see [`TokenStorage`](../frontend/lib/core/storage/) and [`LocalFileUploadField`](../frontend/lib/shared/widgets/local_file_upload_field.dart).

## `prisma generate` fails with `EPERM rename ... query_engine.dll.tmp`

**Symptom**: Generation fails on Windows with a permission/rename error.

**Cause**: The dev server is running and has the engine DLL locked.

**Fix**: Stop the backend (`Ctrl+C` in its terminal), re-run `npx prisma generate`, then restart the backend.

## `prisma migrate dev` fails with "non-interactive environment"

**Symptom**: Running `prisma migrate dev` from this shell hangs or errors.

**Cause**: `prisma migrate dev` expects an interactive TTY for naming migrations.

**Fix**: Either:
- Use a real terminal interactively, or
- For ad-hoc schema changes, use `npx prisma db push --accept-data-loss --skip-generate` then `npx prisma generate`. (`db push` does not record a migration, so reserve it for development.)

## "Argument `companyId` must not be null" when seeding/saving settings

**Symptom**: Prisma `upsert` throws when the unique key includes a nullable column (`[companyId, key]` on `settings`).

**Cause**: Prisma's `upsert` does not accept `null` on a unique side, even when the underlying DB does.

**Fix (already applied in seeder, settings route, business state)**: replace `upsert` with:
```js
const existing = await prisma.settings.findFirst({ where: { companyId, key } });
if (existing) {
  await prisma.settings.update({ where: { id: existing.id }, data: { value } });
} else {
  await prisma.settings.create({ data: { companyId, key, value } });
}
```

## PRAGMA returns BigInt

**Symptom**: `JSON.stringify` throws `Do not know how to serialize a BigInt`.

**Cause**: SQLite `PRAGMA` queries return numeric columns as BigInt.

**Fix**: Coerce with `Number(...)` before serializing. The introspect helpers in [`db_introspect.js`](../backend/src/lib/db_introspect.js) do this — copy the pattern if you write a new PRAGMA-based query.

## Custom entity column edits don't ALTER the SQL table

**Symptom**: You edit a custom entity's columns from the UI, but the SQL table doesn't get the new column.

**Cause**: Intentional. `PUT /api/custom-entities/:id` updates the registration row (which drives form rendering and list columns) but does not alter the real table.

**Fix (manual today)**:
1. Open `/database`.
2. Run `ALTER TABLE <tableName> ADD COLUMN <name> <type>;` (or `DROP COLUMN`).
3. Edit the entity's column config in `/custom-entities` to match.

This will become automatic in a future revision (see [20-roadmap.md](20-roadmap.md)).

## Setup wizard loop

**Symptom**: Super Admin keeps landing on `/setup` even after applying a preset.

**Cause**: The redirect in [app_router.dart](../frontend/lib/routing/app_router.dart) reads from `setupControllerProvider`, which caches `business.applied`. If the cache is stale, the redirect repeats.

**Fix**: After applying a preset, the preset endpoint refreshes the controller. If you bypassed the UI (e.g. seeded via `SEED_BUSINESS_TYPE`), reload the app once.

## SQL runner blocks `users` even with Write mode

**Symptom**: An admin tries to run `UPDATE users SET ...` from `/database`, gets `Operation blocked: protected table`.

**Cause**: Intentional. [`sql_runner.js`](../backend/src/lib/sql_runner.js) blocks any statement touching the auth tables, even with `allowWrite: true`. This is non-negotiable.

**Fix**: Use the Users module (or a one-off script that bypasses the runner). The auth tables are managed through their dedicated endpoints, not through arbitrary SQL.

## Sidebar shows the same item twice

**Symptom**: A duplicate menu entry appears.

**Cause**: A code change renamed a `menu_items.code` and the seeder created a new row instead of updating the old. Or a custom entity was created twice with the same code.

**Fix**: Open `/database`, list the rows in `menu_items`, delete the duplicate. (Or `npm run db:reset` if you can.)

## Token storage on Windows reads stale credentials

**Symptom**: After changing the user's password or deleting the user, the desktop client still logs in.

**Cause**: The stored token at `%APPDATA%\TatbeeqX\auth.json` is still valid until its expiry.

**Fix**: Delete that file, or click **Logout** in the app (which calls `/auth/logout` and clears local storage). Access tokens are short-lived; refresh tokens are revocable on logout.

## Image upload returns 415

**Symptom**: `POST /api/uploads/image` rejects a file.

**Cause**: The MIME is outside the allowlist (PNG, JPEG, WebP, GIF, SVG, ICO) or the file is over 5 MB.

**Fix**: Convert/resize the image. To accept new types, edit the `multer` filter in [`routes/uploads.js`](../backend/src/routes/uploads.js).

## "Cannot find module 'bcrypt'" on Windows after `npm install`

**Symptom**: Native `bcrypt` failing to build on Windows because the build tools aren't present.

**Cause**: The repo uses `bcryptjs` (pure JS, no native build) precisely to avoid this. If you see this error, somebody changed it back to `bcrypt`.

**Fix**: Switch back to `bcryptjs` in `package.json` and the imports.
