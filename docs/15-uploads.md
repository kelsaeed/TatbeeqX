# 15 — File uploads

The system has one upload endpoint (image-only, by design) that the Theme Builder and any other module can use to store branding assets.

- Endpoint: `POST /api/uploads/image`
- Backend: [routes/uploads.js](../backend/src/routes/uploads.js)
- Storage: `backend/uploads/` (gitignored), served as static at `/uploads/<filename>`
- Frontend widget: [`LocalFileUploadField`](../frontend/lib/shared/widgets/local_file_upload_field.dart)

## Endpoint contract

```
POST /api/uploads/image
Authorization: Bearer <accessToken>
Content-Type: multipart/form-data; boundary=...

[part: file = <binary>]
```

Response:

```json
{ "url": "/uploads/1714560000000-logo.png" }
```

Constraints:
- **Auth required**: any authenticated user can upload.
- **Mime allowlist**: PNG, JPEG, WebP, GIF, SVG, ICO. Others rejected with 415.
- **Size limit**: 5 MB. Larger payloads rejected with 413.
- **Filename collision**: the filename is prefixed with `Date.now()-` to avoid collisions.

## Where files live

```
backend/
  uploads/
    1714560000000-logo.png
    1714560034567-favicon.ico
```

`uploads/` is gitignored. On the host running `npm run dev`/`npm start`, the Express static middleware serves the directory at `/uploads/...` (no `/api` prefix).

## Frontend widget

`LocalFileUploadField` is the integrated picker. Because the app intentionally avoids native plugins, **it does not open a file dialog**. Instead:

1. The user pastes a Windows path (e.g. `C:\Users\me\Pictures\logo.png`) into the secondary input.
2. Clicks **Upload**.
3. The widget reads the file via `dart:io File`, builds a multipart request, and POSTs to `/api/uploads/image`.
4. On success, the returned URL is written into the primary input (the URL field that is being edited — logo URL, favicon URL, background image URL, …).

This avoids `file_picker` (a plugin) and therefore avoids the Windows Developer Mode requirement. See [02-tech-stack.md](02-tech-stack.md) for why.

## Wiring a new module to upload

```dart
// somewhere in your form widget
LocalFileUploadField(
  label: 'Receipt logo',
  initialValue: settings.receiptLogoUrl,
  onChanged: (url) => controller.update(receiptLogoUrl: url),
)
```

## Resolving the URL on the client

The backend returns a relative URL (`/uploads/<file>`). The Flutter widgets that render images compute the full URL by stripping the trailing `/api` from `AppConfig.apiBaseUrl`:

```dart
final assetBase = AppConfig.apiBaseUrl.endsWith('/api')
  ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 4)
  : AppConfig.apiBaseUrl;
final fullUrl = '$assetBase$path';   // e.g. http://192.168.1.10:4040/uploads/x.png
```

This matters when the LAN client points at a non-localhost host: relative URLs would break `Image.network`.

## What is not allowed

- **Non-image files.** The current endpoint is image-only. Add a `POST /api/uploads/document` (or similar) if you need PDFs or spreadsheets — and bump the size limit.
- **Reading other users' uploads.** Files are publicly readable from `/uploads/` if you know the filename. The filename is prefixed with `Date.now()` and not enumerated through any endpoint, but the system **does not enforce per-user access** on the static path. Don't store sensitive data here.

## Cleanup

Right now, deleting a theme that referenced an uploaded logo does **not** delete the file from disk. Files accumulate. The [roadmap](20-roadmap.md) tracks adding a periodic GC that compares files in `uploads/` against URLs referenced anywhere in `themes` / `settings` / `custom_entities` rows.
