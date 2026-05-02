# 24 — Quick permission presets

The user wanted shortcut buttons for the role/permission matrix: **View only** / **View + edit** / **View + edit + delete** / **Full** / **None**, applied per module. The backend supports this directly.

- Endpoint: `POST /api/roles/:id/presets`
- Permission: `roles.manage_roles`
- Backend: [routes/roles.js](../backend/src/routes/roles.js)

## Levels

| Level | Actions granted |
|---|---|
| `none` | (clears the module) |
| `view` | `view` |
| `view_edit` | `view`, `create`, `edit` |
| `view_edit_delete` | `view`, `create`, `edit`, `delete` |
| `full` | every available action: `view`, `create`, `edit`, `delete`, `approve`, `export`, `print`, `manage_settings`, `manage_users`, `manage_roles` |

The endpoint resolves each level to permission codes, looks up the matching `permission` rows for the requested modules, and rewrites the role's grants for those modules.

## Request shape

```json
POST /api/roles/12/presets
{
  "presets": [
    { "module": "users",     "level": "view_edit_delete" },
    { "module": "roles",     "level": "view" },
    { "module": "products",  "level": "full" },
    { "module": "audit",     "level": "view" }
  ],
  "replace": true
}
```

- `replace: true` (default) — for each module in the request, deletes the role's existing grants for that module before applying the level. Other modules untouched.
- `replace: false` — the level is *added* on top of any existing grants (skipDuplicates).

Returns the updated role DTO.

## Why server-side

This could have been done client-side (compute the permission ids, send `POST /api/roles/:id` with the new id list). It runs server-side because:

1. **Atomicity**: the change is one transaction; no half-applied state.
2. **Audit clarity**: a single `apply_preset` audit row records the intent (`{ presets: [...] }`) instead of an opaque list of permission ids.
3. **Forward compat**: when you add a new action (say `users.import`), `full` automatically picks it up — no client redeploy needed.

## Limitations

- Super Admin's role is computed implicitly (`isSuperAdmin: true` bypasses checks). The endpoint refuses to mutate the `super_admin` role.
- The `level` keys are fixed strings. Adding a new level (e.g. `read_only`) requires a backend change to `PRESET_ACTIONS` in `routes/roles.js`.
- The endpoint does not create *new* permissions — it only assigns existing ones. So if a module's `<module>.approve` permission has not been seeded, asking for `full` won't grant approve until the module is registered.

## UI today vs. roadmap

**Today**: backend works; the Roles page does not yet expose the preset buttons. You can hit the endpoint via curl or via the Database admin's **HTTP request** experiments while the UI catches up.

**Next slice**: add a 5-button row in the role's permission matrix per module — clicking applies the chosen level and refreshes the matrix.
