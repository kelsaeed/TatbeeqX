# 04 — Roles

Five roles are seeded by `backend/prisma/seed.js` with `isSystem: true`. System roles cannot be deleted from the UI, but their permission grants can be edited (except Super Admin's, which is computed dynamically as "all").

| Code | Name | Bypass checks? | Default grants |
|---|---|---|---|
| `super_admin` | Super Admin | **yes** (`isSuperAdmin` flag on the user record) | all permissions implicitly |
| `chairman` | Chairman | no | `view`, `approve`, `export`, `print` on every module |
| `company_admin` | Company Admin | no | everything except `themes.manage_settings`, `themes.create/edit/delete`, and `companies.delete` |
| `manager` | Manager | no | `view/create/edit/export/print/approve` on operational modules; only `view` on roles, permissions, themes, audit, settings |
| `employee` | Employee | no | `dashboard.view` only |

## Detailed responsibilities

### Super Admin
- Owns the **Theme Builder** (`/themes`).
- Owns **Database admin** (`/database`) and the SQL runner.
- Owns **Custom Entities** (`/custom-entities`) and the **Setup Wizard** (`/setup`).
- Owns **Templates** (`/templates`).
- Can edit any user's roles, including granting Super Admin status.
- The user record itself has `isSuperAdmin: true` — the permission middleware short-circuits without consulting roles.

### Chairman
- Cross-company visibility for monitoring and audits.
- Cannot create/edit/delete records.
- Can `approve` workflows and `export`/`print` reports.

### Company Admin
- Day-to-day administrator within a company. Manages users, roles, branches, settings.
- Can read theme settings but cannot change them.
- Cannot delete a company (only Super Admin can).

### Manager
- Limited management: views, edits, creates operational data (custom entities included once the business preset is applied).
- Read-only on system surfaces (roles, permissions, audit, settings, themes).

### Employee
- Lands on the dashboard. Sees the dashboard and nothing else by default.
- The Company Admin grants additional permissions per-user via per-user grants/revokes (see [05-permissions.md](05-permissions.md)).

## Adding custom roles

Custom roles are created from the UI (`/roles → New role`). They:
- get a unique `code` (lowercase, snake_case)
- can be assigned any subset of the permissions catalog through the role's permission matrix
- are not `isSystem`, so they can be deleted again

When a business preset is applied, its entity permissions (`<entity>.{view,create,edit,delete,export,print}`) are auto-granted to **Super Admin** and **Company Admin**. To grant them to **Manager** or a custom role, edit that role's matrix.

## Resolving a user's roles

A user can have multiple roles via the `user_roles` join table. The user's effective permissions are computed as:

```
effective = (∪ permissions of every assigned role)
          + per-user grants
          - per-user revokes
```

See [05-permissions.md](05-permissions.md) for the model and [permissions.js](../backend/src/lib/permissions.js) for the implementation.

## Source

Roles are defined in [backend/prisma/seed.js](../backend/prisma/seed.js) under `const ROLES = [...]`. Their `grants` field is either the literal `'all'` or a function evaluated against each permission row at seed time.
