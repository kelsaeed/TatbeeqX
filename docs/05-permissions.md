# 05 — Permissions

## The model

Every permission is a row in the `permissions` table with a unique `code` of the form:

```
<module>.<action>
```

Examples: `users.view`, `roles.edit`, `themes.manage_settings`, `audit.export`.

Built-in actions:

| Action | Meaning |
|---|---|
| `view` | Read endpoints. Also gates whether a sidebar entry appears. |
| `create` | POST endpoints |
| `edit` | PUT/PATCH endpoints |
| `delete` | DELETE endpoints |
| `approve` | Workflow transitions (used in chairman flows) |
| `export` | Export endpoints (CSV/Excel) |
| `print` | Print/PDF endpoints |
| `manage_settings` | High-privilege module configuration (e.g. theme settings) |
| `manage_users` | Used by the Users module for user-management actions |
| `manage_roles` | Used by the Roles module to edit the role/permission matrix |

## Effective permissions

A user has many roles. Each role has many permissions. A user can additionally have **per-user grants** and **per-user revokes** in the `user_permission_overrides` table.

```
effective(user) = (∪ permissions assigned to user.roles)
                + per-user grants (where allow=true)
                - per-user revokes (where allow=false)
```

**Super Admin shortcut**: if `user.isSuperAdmin === true`, the resolver returns *all* permissions and the middleware skips the lookup.

Implemented in [backend/src/lib/permissions.js](../backend/src/lib/permissions.js). Used by:

- `requirePermission(code)` middleware on every protected route
- `GET /api/auth/me` so the frontend can render UI conditionally
- `GET /api/menus`, which filters menu items by the user's `<module>.view` permissions

## Default catalog (seed)

The seed builds the catalog from the `MODULES` table in [backend/prisma/seed.js](../backend/prisma/seed.js). Each entry maps a module to the list of actions it exposes:

| Module | Actions |
|---|---|
| `dashboard` | view |
| `companies` | view, create, edit, delete, approve, export, print |
| `branches` | view, create, edit, delete, export, print |
| `users` | view, create, edit, delete, approve, export, print, manage_users |
| `roles` | view, create, edit, delete, manage_roles |
| `permissions` | view |
| `audit` | view, export |
| `settings` | view, manage_settings |
| `themes` | view, manage_settings |
| `reports` | view, create, edit, delete, export, print |
| `database` | view |
| `custom_entities` | view |
| `templates` | view |

Plus, for each applied business-preset entity, six more: `<entity>.{view, create, edit, delete, export, print}`.

## Default grants per role

| Permission | super_admin | chairman | company_admin | manager | employee |
|---|---|---|---|---|---|
| `dashboard.view` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `companies.view` / `create` / `edit` / `approve` / `export` / `print` | ✓ | view, approve, export, print | view, create, edit, approve, export, print | view, create, edit, approve, export, print | — |
| `companies.delete` | ✓ | — | — | — | — |
| `branches.*` | ✓ | view, export, print | all | view, create, edit, export, print | — |
| `users.*` | ✓ | view, export, print | all | view, create, edit, export, print, approve | — |
| `roles.*` | ✓ | view | all | view | — |
| `permissions.view` | ✓ | ✓ | ✓ | ✓ | — |
| `audit.view` / `export` | ✓ | both | both | view | — |
| `settings.view` / `manage_settings` | ✓ | view | both | view | — |
| `themes.view` | ✓ | ✓ | ✓ | ✓ | — |
| `themes.manage_settings` | ✓ | — | — | — | — |
| `reports.*` | ✓ | view, export, print | all | view, create, edit, export, print | — |
| `database.view` | ✓ | — | ✓ | — | — |
| `custom_entities.view` | ✓ | — | ✓ | — | — |
| `templates.view` | ✓ | — | ✓ | — | — |

(Computed by the `grants` functions in `seed.js` — that table is the canonical view.)

## How a route is gated

```js
// backend/src/routes/users.js
router.post(
  '/',
  requireAuth,
  requirePermission('users.create'),
  validate.createUser,
  async (req, res) => {
    const created = await prisma.user.create(...);
    await audit(req, 'create', 'user', created.id, null, created);
    res.json(created);
  }
);
```

`requirePermission` reads the requester's effective permissions, short-circuits for Super Admin, otherwise enforces.

## How the sidebar is filtered

`GET /api/menus` returns only menu items whose `permissionCode` is in the requester's effective permission set. The Flutter sidebar shows whatever the API returns. To add a custom sidebar entry, add a row in `menu_items` with a `permissionCode` and the user must have that permission.

## Per-user overrides

Use the Users page → user → **Permissions** tab to grant or revoke a single permission for one user without touching the role. This is the right place when one employee needs a one-off privilege without inflating their role.

```sql
INSERT INTO user_permission_overrides (userId, permissionId, allow) VALUES (?, ?, 1);  -- grant
INSERT INTO user_permission_overrides (userId, permissionId, allow) VALUES (?, ?, 0);  -- revoke
```
