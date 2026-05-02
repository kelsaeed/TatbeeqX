# 32 — Translated UI strings

Builds on the i18n foundation in [31-i18n.md](31-i18n.md). The locale switcher, `flutter_localizations` delegates, and persisted user choice were already in place; Phase 4.6 wired actual `gen_l10n` ARB-driven translations.

- Config: [`frontend/l10n.yaml`](../frontend/l10n.yaml)
- Sources: [`frontend/lib/l10n/app_en.arb`](../frontend/lib/l10n/app_en.arb), [`app_ar.arb`](../frontend/lib/l10n/app_ar.arb), [`app_fr.arb`](../frontend/lib/l10n/app_fr.arb)
- Generated (committed): [`frontend/lib/l10n/gen/`](../frontend/lib/l10n/gen/) — `app_localizations.dart` + per-locale files
- Wiring: `app.dart` adds `AppLocalizations.delegate` to `localizationsDelegates`

## What is translated today

After Phase 4.11's bulk migration (~330 strings across 32 files), the user-facing surface is comprehensively localized:

- **Login screen** (Phase 4.6) — title, "Sign in to continue", username/password labels, hero copy, tagline.
- **Sidebar labels** (Phase 4.7) — sourced from `MenuItem.labels` JSON, populated by the seed's `MENU_LABELS` map. `MenuItemNode.labelFor(localeCode)` resolves with English fallback.
- **Topbar** (Phase 4.7) — `Sign out`, `Account`, `Switch company`, `No company`, `— Global theme —`, `Language`, role label.
- **Roles UI labels** (Phase 4.10) — `Role.labels` JSON column drives the role-card display; flips with locale.
- **Dialog titles, table column headers, snackbars, validation messages** (Phase 4.11) across: users, companies, branches, roles, settings, audit, login_events, system_logs, backups, dashboard, reports, webhooks, approvals, setup, custom records, custom entities, templates, themes (page-level), pages (page-level), system (page-level), database (page-level), report_schedules, translations.
- **ICU plural rules** for count-style labels (`permissionsCount`, `usersCount`, `branchesCount`, `starterTablesCount`, `columnsCount`) — including Arabic dual/few/many forms.
- **Common dictionary** (`save`, `cancel`, `delete`, `edit`, `create`, `loading`, `noData`, `required`, `apply`, `activate`, `duplicate`, `resetLabel`, `run`, `importLabel`, `exportLabel`, `add`, `remove`, `close`, `back`, …) — usable from any new feature page.

ARB size: 49 → ~225 keys × 3 locales (en/ar/fr) = ~675 entries.

## Power-user surfaces deliberately left in English

Phase 4.11 explicitly scope-cut these for ROI reasons. They're Super Admin-only editor surfaces with technical field labels that translate poorly and are seen by very few users:

- [`block_inspectors.dart`](../frontend/lib/features/pages/presentation/block_inspectors.dart) — 15+ block-edit dialogs (text/heading/image/button/card/table/chart/iframe/html/spacer/etc.) with field labels like "Height (logical pixels)", "Render as", "Fit", "Body", "Style".
- [`page_builder_page.dart`](../frontend/lib/features/pages/presentation/page_builder_page.dart) — `_blockTypeLabels` map (block-type names) and the add-block panel.
- [`theme_builder_page.dart`](../frontend/lib/features/themes/presentation/theme_builder_page.dart) — color pickers, typography controls, glass settings, login-style picker. Top-level page header is migrated; the deep panels are not.
- [`sql_runner_panel.dart`](../frontend/lib/features/database/presentation/sql_runner_panel.dart) — query runner internals (Save / Load / Write mode chips, result preview headers).
- [`page_renderer.dart`](../frontend/lib/features/pages/presentation/page_renderer.dart) — runtime rendering error messages.

If a translator working in a non-English shop needs these covered, file a follow-up — the migration pattern is mechanical at this point.

## What is **not** translated yet

- Some dynamic block-builder field labels (see "Power-user surfaces" above).
- Sidebar labels for **custom entities** still come from the server's `MenuItem.label` and aren't locale-aware (see Caveats below).
- Dynamic strings from the API (audit log entity names, error messages from Prisma, etc.) come back in English.

The fast path for adopting a translation in new code:

```dart
// before
Text('Save')
// after
Text(AppLocalizations.of(context).save)
```

## Adding a new string

1. Add it to `app_en.arb` (the template). Optionally add an `@<key>` description block.
2. Add the same key to `app_ar.arb` and `app_fr.arb` with the localized value. Missing keys fall back to English at runtime; the build still succeeds.
3. Run `flutter gen-l10n` (or `flutter pub get`, which triggers it because `generate: true` is on in `pubspec.yaml`).
4. Reference it: `AppLocalizations.of(context).<key>`.

## Adding a new locale

1. Add a row to `supportedLocales` in [`lib/core/i18n/locale_controller.dart`](../frontend/lib/core/i18n/locale_controller.dart).
2. Update `_languageLabel(code)` in `dashboard_shell.dart` for the dropdown caption.
3. Add `lib/l10n/app_<code>.arb` mirroring `app_en.arb`.
4. `flutter gen-l10n`.

## RTL behaviour

Picking Arabic flips `Directionality` to RTL. Most widgets (Material's defaults plus our `EdgeInsetsDirectional` usages) flip automatically. A few places still use `EdgeInsets.fromLTRB(...)` or `Alignment.topLeft` — those represent intentional visual positions and don't need to flip. If you spot one that should, replace:

- `EdgeInsets.fromLTRB(...)` → `EdgeInsetsDirectional.fromSTEB(...)`
- `Alignment.topLeft` → `AlignmentDirectional.topStart`

## Generation config

`l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
output-dir: lib/l10n/gen
```

`output-dir: lib/l10n/gen` keeps generated files inside the package (vs. the old synthetic-package mechanism, which is deprecated). The generated files are committed because gen_l10n's "synthetic package" mode is slated for removal.

## Caveats

- **Sidebar labels come from the server**, not from the ARBs. They live in `menu_items.label` and are seeded in `prisma/seed.js`. Translating them would require either localized `menu_items` rows or a key mapping; not done yet.
- **Dynamic strings from the API** (audit log entity names, error messages from Prisma, etc.) come back in English regardless of locale. They are out of scope for client-side i18n.
- **Date/number formatting** does follow the locale — `DateFormat` and `NumberFormat` from `intl` honour the active locale automatically when you pass `Locale.toString()` to them, or omit the locale and it uses the platform default at the time the widget builds.
