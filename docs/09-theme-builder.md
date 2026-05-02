# 09 — Theme Builder

## Where it lives

- Page: `/themes` (Super Admin only)
- Backend: [backend/src/routes/themes.js](../backend/src/routes/themes.js)
- Frontend: [frontend/lib/features/themes/](../frontend/lib/features/themes/)
- Theme application: [`AppThemeBuilder.build`](../frontend/lib/core/theme/theme_data_builder.dart) factory + `ThemeController` (Riverpod) + `app.dart`

## What you can change

| Group | Settings |
|---|---|
| Mode | `light` or `dark` |
| Colors | primary, secondary, accent, background, surface, sidebar, sidebar text, top bar, top bar text, text primary, text secondary |
| Typography | font family, base font size |
| Shape | button radius, card radius, table radius |
| Effects | shadows on/off, gradients on/off (with from/to colors and direction) |
| Layout | login style (`split` / `centered` / `cover`), dashboard layout (`cards` / `compact` / `wide`) |
| Branding | app name, logo URL, favicon URL, background image URL |

All editable from the UI. The integrated [LocalFileUploadField](../frontend/lib/shared/widgets/local_file_upload_field.dart) lets the user paste a Windows path, click **Upload**, and the resulting `/uploads/<file>` URL is stored.

## Boot flow

```
main.dart
  ↓ opens TokenStorage
  ↓ runs ProviderScope
app.dart (ConsumerWidget)
  ↓ watches themeControllerProvider
ThemeController.build()
  ↓ GET /api/themes/active        ← public endpoint, returns the row with isActive=true
  ↓ caches ThemeSettings
MaterialApp.router
  ↓ uses AppThemeBuilder.build(settings)
```

When the Super Admin clicks **Activate** on a theme, `themeControllerProvider` refreshes and `MaterialApp` rebuilds — no app restart needed. Changes propagate live to every open client on next refresh.

## Multi-theme strategy

- Many themes can exist. Exactly one has `isActive: true`. One has `isDefault: true` and cannot be deleted (resetting the active theme returns to it).
- Themes are global (`companyId: null`) or scoped to a company. Per-company theming is supported but not yet wired into a company-switcher in the UI; for now the active global theme wins.
- **Duplicate / Reset / Delete** actions live on the theme card.

## Default theme

Seeded as "Default Professional":

```js
{
  mode: 'light',
  primary: '#1F6FEB',
  secondary: '#0EA5E9',
  accent: '#22C55E',
  background: '#F4F6FA',
  surface: '#FFFFFF',
  sidebar: '#0F172A',
  sidebarText: '#E2E8F0',
  topbar: '#FFFFFF',
  topbarText: '#0F172A',
  textPrimary: '#0F172A',
  textSecondary: '#475569',
  buttonRadius: 10,
  cardRadius: 14,
  tableRadius: 10,
  fontFamily: 'Inter',
  fontSizeBase: 14,
  shadows: true,
  gradients: false,
  loginStyle: 'split',
  dashboardLayout: 'cards',
  appName: 'TatbeeqX',
}
```

## Live preview

The Theme Builder page shows a live preview pane: cards, buttons, inputs, table headers, sidebar swatch, top bar swatch, login hero. Saving applies the settings system-wide.

## Background image rendering

When `backgroundImageUrl` is set:
- The dashboard renders it behind the page content with a soft overlay.
- The login screen overlays it on the hero half (in `split` style).

The image is loaded via standard `Image.network`. Hosted at `/uploads/<file>` on the backend.
