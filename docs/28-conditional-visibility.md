# 28 — Conditional block visibility

Page-builder blocks can opt into per-viewer visibility. The check happens client-side in the `PageRenderer` against the current `AuthState` — Super Admins always pass, others are matched against their effective permissions.

- Backend: nothing — `visibleWhen` is a free-form key in the block's `config`. Sanitization for the `html` block runs as before.
- Frontend: [`features/pages/presentation/page_renderer.dart`](../frontend/lib/features/pages/presentation/page_renderer.dart) — exports `isBlockVisible(block, auth)`.

## Rule shape

All keys are optional. When present, they are ANDed together:

```json
{
  "visibleWhen": {
    "isLoggedIn": true,
    "isSuperAdmin": true,
    "permission": "users.view",
    "permissions": ["users.view", "roles.view"],
    "match": "any"
  }
}
```

- `isLoggedIn: true` — hide for unauthed viewers (rarely needed since the route is auth-guarded).
- `isSuperAdmin: true` — only Super Admin sees this block.
- `permission: "<code>"` — single permission required.
- `permissions: [...]` + `match: "any" | "all"` — multi-permission gate. Default match is `all`.

If `visibleWhen` is missing or non-object, the block is always visible.

## Examples

Show a "Reset DB" button only to Super Admin:

```json
{ "type": "button",
  "config": {
    "label": "Reset",
    "route": "/system",
    "visibleWhen": { "isSuperAdmin": true }
  }
}
```

Show a panel to anyone who can see *either* users or roles:

```json
{ "type": "card",
  "config": {
    "title": "Access management",
    "visibleWhen": { "permissions": ["users.view", "roles.view"], "match": "any" }
  }
}
```

## Important — security boundary

This is a **rendering filter**, not an authorization gate. A determined viewer can read the page's blocks via `GET /api/pages/by-route` and inspect every config. **Never put secrets in `visibleWhen`** — use it for cleaner UX, not for hiding sensitive content.

If you need real access control over content, gate the *page itself* with `Page.permissionCode` or split sensitive content into a separate page that only the right users have permission to load.

## Implementation

`PageRenderer.build()` calls `isBlockVisible(block, auth)` once per top-level block and once per child during recursion. The function reads `auth.user.isSuperAdmin`, `auth.isLoggedIn`, and `auth.can(code)` from the existing `AuthState`. No new providers, no extra HTTP traffic.
