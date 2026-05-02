# 42 — Translation management

Phase 4.10 puts the ARB files behind an API + UI so a Super Admin can edit translations from the running TatbeeqX without SSHing to the host. Phase 4.11 replaces the JSON textarea with a per-key form editor.

- API endpoints: `GET/PUT /api/admin/translations[/:locale]`
- Lib: [`backend/src/lib/translations.js`](../backend/src/lib/translations.js)
- Listing page: `/translations` (Super Admin only) — [`features/translations/presentation/translations_page.dart`](../frontend/lib/features/translations/presentation/translations_page.dart)
- Per-key editor: `/translations/edit/:locale` — [`features/translations/presentation/translations_editor_page.dart`](../frontend/lib/features/translations/presentation/translations_editor_page.dart)

## What this does today

- **List ARB files** at `frontend/lib/l10n/`. Reports per-locale: file name, key count, byte size, last-modified, and whether the locale is in `supportedLocales`.
- **Read** a single ARB as JSON.
- **Write** a single ARB. Strips/restamps `@@locale` to match the path so authors can't accidentally save a mismatched marker. Writes a timestamped backup (`app_<locale>.arb.bak-<iso>`) before overwriting.
- **Create a new locale** — UI seeds it from the English ARB so the editor starts with all keys.

## What it does NOT do

**Saving an ARB does not regenerate the Dart code.** Flutter's gen_l10n step writes `app_localizations.dart` + per-locale files based on the ARBs at build time. Until the operator runs `flutter gen-l10n` and rebuilds the desktop / web bundle, the running app still shows whatever was compiled in.

The endpoint message is explicit:

> Saved. Run `flutter gen-l10n` and rebuild the app for changes to take effect.

This is a deliberate separation. Re-running gen_l10n from inside the API would require the Flutter SDK on the API host, which is a heavy ask for a Node service.

## Endpoints

| Method | Path | Permission |
|---|---|---|
| GET | `/api/admin/translations` | Super Admin |
| GET | `/api/admin/translations/:locale` | Super Admin |
| PUT | `/api/admin/translations/:locale` | Super Admin — body `{ data: <arb-json> }` |

Locale code regex: `^[a-z]{2}(?:_[A-Z]{2})?$` — accepts plain ISO-639 (`en`, `ar`, `fr`) plus optional `_<region>` (`en_US`, `pt_BR`).

## On-disk layout

```
frontend/lib/l10n/
  app_en.arb                              ← English template (must always exist)
  app_ar.arb                              ← Arabic
  app_fr.arb                              ← French
  app_de.arb                              ← created via /translations after Phase 4.10
  app_en.arb.bak-2026-05-01T10-30-00-000Z ← auto-created on overwrite
  gen/
    app_localizations.dart                ← gen_l10n output (committed, regenerated at build)
    app_localizations_en.dart
    ...
```

The `.bak-*` files accumulate. Add `frontend/lib/l10n/*.bak-*` to `.gitignore` if you don't want them in commits, and prune them periodically:

```bash
find frontend/lib/l10n -name '*.bak-*' -mtime +30 -delete
```

## Workflow

A typical translator workflow:

1. **Operator** opens `/translations` → clicks **Edit** on `ar`.
2. Edits the JSON, saves. Backend writes `app_ar.arb` and a `.bak-*` sidecar. Audit log records the change.
3. **Build engineer** pulls the repo, runs `cd frontend && flutter gen-l10n && flutter build windows`, ships the new binary to clients.
4. Clients restart, see the updated translations.

For shops where step 3 is hand-off to a build pipeline, wire the audit log to a notification channel — `entity: 'Translation', action: 'update'` is the trigger.

## Adding a brand-new locale

The UI's **New locale** button:

1. Asks for a locale code.
2. Reads the en ARB.
3. POSTs it as the new locale's content.

The new file lands on disk with English values everywhere. The translator then opens **Edit** and replaces them.

**One more step required**: add the new locale to `supportedLocales` in [`lib/core/i18n/locale_controller.dart`](../frontend/lib/core/i18n/locale_controller.dart) AND update `_languageLabel(code)` in [`features/dashboard/presentation/dashboard_shell.dart`](../frontend/lib/features/dashboard/presentation/dashboard_shell.dart). Until that's done, the app won't expose the new locale in the language switcher. The endpoint surfaces this via `isSupported: false` in the `GET /api/admin/translations` response.

## Tests

[`tests/translations.test.js`](../backend/tests/translations.test.js):

- `listLocales()` returns en/ar/fr with their key counts and `isSupported: true`.
- `readLocale('en')` parses the ARB and exposes the canonical `signIn` key.
- Invalid locale codes raise; missing locale returns 404.
- `writeLocale('en', { '@@locale': 'wrong', ... })` overwrites `@@locale` to `en` (the path wins).
- A `.bak-*` sidecar is created on overwrite.
- Bad input (null, array) is rejected.

## Caveats

- **The API and the Flutter source tree must be co-located.** `getL10nDir(cwd)` resolves to `<cwd>/../frontend/lib/l10n` — i.e. the standard repo layout `<repo>/backend/` + `<repo>/frontend/`. In a Docker compose deployment where the API container doesn't ship the frontend source, the endpoint will return empty / 404. Either bind-mount the ARB dir or run translations management from a dev workstation that has the source.
- **No locking.** Two concurrent saves could race on the `.bak-*` filename (uses ISO milliseconds). Acceptable for low-frequency edits; if you have multiple translators, add a UI lock.
- **No diff view.** The legacy raw-JSON dialog (still available via the listing page's overflow menu → "Edit raw JSON…") is just a textarea. The Phase 4.11 per-key editor doesn't show a side-by-side diff against the previous saved version — it shows English reference, current value, and a "modified" badge per row. For diff-style review, compare against the timestamped `.bak-*` sidecar.

## Per-key editor (Phase 4.11)

Click the **edit (per-key)** icon on any locale row in `/translations` to open the editor at `/translations/edit/<code>`.

The editor:

- Loads the target locale ARB plus the English ARB (the template) in parallel.
- Shows one card per translatable key, in the en file's order.
- For non-en locales: each card shows the **English reference value** (read-only) above the **editable target value**.
- For en: each card shows the value and a read-only description (from the `@key` metadata block).
- Per-row badges:
  - **modified** — value differs from the file on disk
  - **untranslated** — value is empty or identical to the English reference (non-en only)
  - **orphan** — key exists in this locale but not in en (stale translation)
- A header counter for non-en locales: `X of Y keys not yet translated`.
- Toolbar:
  - **Search** — substring match on key, English value, or current value.
  - **Untranslated only** filter (non-en only).
  - **Drop orphan keys on save** toggle (non-en only) — when on, orphan keys are removed from the saved ARB.
- **Save** → builds an ARB body and PUTs `/api/admin/translations/<locale>`. The same backend endpoint as the legacy textarea editor; same `.bak-*` sidecar behavior; same audit trail. Empty values are skipped (the next gen-l10n run will fall back to English for that key).
- **Discard** → reverts every field to its on-disk value.

What the editor does **NOT** do (deliberate v1 scope):

- **Add new keys.** ARBs are downstream of the source code's `t.foo` calls — adding a key here without a corresponding Dart accessor doesn't help.
- **Delete individual keys.** Removing a key would break any `t.removedKey` callers. The "drop orphan keys on save" toggle is the only deletion path, and it only affects keys in the target that en doesn't have.
- **Per-key autosave.** Save batches the whole ARB on click, matching the legacy editor.
- **Edit `@key` metadata blocks.** Description text is shown read-only when editing en. To change descriptions, use the raw-JSON dialog.
