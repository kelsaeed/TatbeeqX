# 49 — User manual

End-user-facing guide to TatbeeqX. If you are a developer extending the platform, see [01-overview.md](01-overview.md) and [03-getting-started.md](03-getting-started.md) instead.

This page assumes the backend is running (a Super Admin or operator did the setup; see [SETUP.md](../SETUP.md) and [03-getting-started.md](03-getting-started.md)) and you have a username + password to sign in.

## Contents

1. [Signing in](#1-signing-in)
2. [Forgot your password?](#2-forgot-your-password)
3. [Two-factor authentication (2FA)](#3-two-factor-authentication-2fa)
4. [The dashboard tour](#4-the-dashboard-tour)
5. [Notifications](#5-notifications)
6. [Sessions & "log out everywhere"](#6-sessions--log-out-everywhere)
7. [First-run setup wizard (Super Admin only)](#7-first-run-setup-wizard-super-admin-only)
8. [Working with users, roles, and permissions](#8-working-with-users-roles-and-permissions)
9. [Custom entities — building your own tables](#9-custom-entities--building-your-own-tables)
10. [Reports](#10-reports)
11. [Approvals](#11-approvals)
12. [Workflows — automating the system](#12-workflows--automating-the-system)
13. [Webhooks (outbound)](#13-webhooks-outbound)
14. [Pages — the page builder](#14-pages--the-page-builder)
15. [Templates — capture & share a setup](#15-templates--capture--share-a-setup)
16. [Backups & restore](#16-backups--restore)
17. [Themes & branding](#17-themes--branding)
18. [Switching language](#18-switching-language)
19. [Audit log](#19-audit-log)
20. [Common questions](#20-common-questions)

---

## 1. Signing in

Open the app and you'll land on the **Sign in** page. Enter your **username** (or email) and **password**, then **Sign in**.

The default Super Admin credentials on a fresh install are:

```
username: superadmin
password: ChangeMe!2026
```

> **Change these on day one.** Open the avatar menu in the top-right after sign-in.

If 2FA is enabled on your account, you'll be prompted for a 6-digit code (or a recovery code) on the next screen.

## 2. Forgot your password?

On the sign-in page, click **Forgot password?**. Enter your username or email; if your account exists and the system has email configured, you'll receive a one-time reset link valid for **1 hour**.

If the page tells you "Email isn't configured on this server," ask your administrator. They can manually generate a reset token and share it with you out of band.

## 3. Two-factor authentication (2FA)

You can enable 2FA from the avatar menu → **Sessions** → 2FA panel. The flow:

1. Click **Enable 2FA**. The app shows a QR code.
2. Scan it with any authenticator app — Google Authenticator, Authy, 1Password, Bitwarden, Microsoft Authenticator all work.
3. Enter the 6-digit code from the app to confirm enrollment.
4. The system gives you **10 recovery codes** — save them somewhere safe (a password manager). Each can be used once if you lose your authenticator.

After enrollment, every sign-in asks for a code. To disable 2FA, you'll be asked for a current code (or recovery code) — proves you still have it.

## 4. The dashboard tour

After signing in, you land on the **Dashboard**. Top-level layout:

| Area | What's there |
|---|---|
| **Sidebar (left)** | Navigation, filtered by your permissions — you only see what you can access |
| **Top bar** | Company switcher, language switcher, notifications bell, your avatar (account menu) |
| **Main canvas** | The current page |

Sidebar items vary by your role. A typical operator sees:

- Dashboard, your business entities (e.g. Customers, Sales), Reports, Notifications.

A Super Admin additionally sees:

- Users, Roles, Companies, Branches, Audit Logs, Settings, Appearance, Database, Custom entities, Templates, Pages, System, System Logs, Login Activity, Approvals, Report Schedules, Webhooks, Workflows, Backups, Translations.

If a sidebar item is missing, you don't have its `<module>.view` permission. Ask an admin.

## 5. Notifications

The **bell icon** in the top bar shows unread notifications. Notifications come from:

- **Approvals** — when one of your approval requests is approved, rejected, or cancelled.
- **Workflows** — anything an admin set up via the workflow engine's `notify_user` action.
- **System** — backups, scheduled-report results, etc.

Click the bell to open a popover of the most recent. Tap a notification to mark it read; if it has a link, it'll also navigate you there. The full history with bulk actions lives at **Notifications** in the sidebar (or just visit `/notifications`).

Per-account, no broadcast — only you see your own notifications.

## 6. Sessions & "log out everywhere"

Open the avatar menu in the top-right:

- **Sessions** — lists every device currently signed in to your account, with IP and user-agent. Revoke any session you don't recognize.
- **Sign out** — ends just this device's session.
- **Sign out everywhere** — revokes every refresh token tied to your account. Use after a suspected compromise.

A password reset (self-serve or admin-driven) automatically signs you out everywhere as a precaution.

## 7. First-run setup wizard (Super Admin only)

The first time a Super Admin signs in to a fresh install, the app redirects to **/setup**. Pick a **business preset**:

| Preset | Starter tables it creates |
|---|---|
| Retail / POS | products, customers, suppliers, sales, payments |
| Restaurant | menu items, tables, orders, reservations, customers |
| Clinic | patients, appointments, treatments |
| Factory | products, raw materials, work orders, inventory movements, suppliers |
| Finance office | customers, invoices, accounts, transactions |
| Rental company | assets, customers, rentals, payments |
| Blank slate | nothing — you'll define everything yourself in **Custom entities** |

After applying a preset, the system creates real database tables, generates `<table>.{view,create,edit,delete,export,print}` permissions for each, and adds a sidebar entry pointing at `/c/<code>` for generic CRUD.

The setup wizard is one-time. To switch presets later, you'd manually drop tables — this is intentional, presets aren't a "theme" you flip casually.

## 8. Working with users, roles, and permissions

**Users** (sidebar → Users):

- **Create** — fill in username, email, full name, password. Optionally assign a company and branch. Optionally tick **Super Admin** (skip if you're unsure — it bypasses all permission checks).
- **Edit** — change anything except username (which is the unique anchor). To change a password, use **Set password** in the row menu.
- **Assign roles** — open the user, scroll to **Roles**, tick the ones to apply.
- **Per-user overrides** — a user inherits role permissions, but you can grant or revoke individual permission codes on top.

**Roles** (sidebar → Roles):

- **Create** — pick a code (`lower_snake`), a name, and a description. Five roles ship by default: `super_admin`, `chairman`, `company_admin`, `manager`, `employee`.
- **Permission matrix** — a grid of every module × every action. Tick what the role can do.
- **Quick presets per module** — chips show **none / view / view+edit / view+edit+delete / full**. One click bulk-toggles a module's permissions for the role.

A user's effective permissions =
**(union of role permissions) + per-user grants − per-user revokes**.

Super Admins skip the check entirely.

## 9. Custom entities — building your own tables

Sidebar → **Custom entities** (Super Admin / Company Admin).

To create a new table:

1. **New entity**.
2. **Code** — `lower_snake`, e.g. `leads`. Becomes the URL `/c/leads` and the permission prefix `leads.{view,create,...}`.
3. **Label / Singular** — display names (e.g. "Leads" / "Lead").
4. **Columns** — for each:
   - **Name** (column id), **Label** (display).
   - **Type** — `text`, `longtext`, `integer`, `number`, `bool`, `date`, `datetime`, `relation` (single FK to another entity), `relations` (many-to-many), `formula` (computed at read time).
   - Flags: required / unique / searchable / show-in-list.
   - For `relation` / `relations`: **target entity**.
   - For `formula`: an arithmetic expression over other columns.
   - Optional **field-level permissions** (`viewPermission` / `editPermission`) — restrict who can see or write the column.
5. **Save**.

The system runs `CREATE TABLE` on the underlying database, generates the standard 6 permissions for the entity (view/create/edit/delete/export/print), grants them to Super Admin + Company Admin, and adds a sidebar entry at `/c/<code>`.

Once created, navigating to `/c/<code>`:

- Shows a paginated, searchable list of rows.
- **New record** opens a form auto-built from your column definitions.
- **CSV import** — paste CSV text; bad rows return per-line errors without aborting the import.
- **CSV export** — streams the whole table as CSV.
- **Bulk delete** — tick rows, click delete.

## 10. Reports

Sidebar → **Reports**. Reports are stored in the database, run on demand. Each one is backed by a server-side **builder function** — no raw SQL is interpreted from user input, which is what keeps the system safe.

- **Run** a report. The result shows as a table; if the result has at least one numeric column, you can flip to a **bar chart** view.
- **Schedule** a report (Super Admin) at sidebar → **Report Schedules** — runs daily/weekly/monthly/cron, persists results, and prunes them after the configured retention.

Adding a new report needs developer involvement — see [13-reports.md](13-reports.md).

## 11. Approvals

Sidebar → **Approvals**. The approvals queue lets one user request that an action be approved by someone with the relevant `<entity>.approve` permission.

- **Create a request** — entity, title, optional description, optional payload (any JSON the requester wants to attach).
- **Approve / Reject** — anyone with `<entity>.approve` (or Super Admin) can decide. The decider can attach a note.
- **Cancel** — only the requester (or Super Admin) can cancel a still-pending request.

Every transition is audited. Approvers and requesters are notified:

- **In-app notification** to the requester when their request is decided.
- **Email** to the requester (when SMTP is configured and they have an email on file).
- **Webhook** to any subscribers listening for `approval.requested / approved / rejected / cancelled`.

## 12. Workflows — automating the system

Sidebar → **Workflows** (Super Admin / Company Admin). The workflow engine lets you say "when X happens, do Y" without writing code.

A workflow has:

- **Trigger** — one of:
  - **`record`** — fires when a row is created / updated / deleted in a custom entity. Optional **filter** (a condition on the row's fields).
  - **`event`** — subscribes to an existing system event (e.g. `approval.approved`, `backup.created`).
  - **`schedule`** — runs on a cron-like schedule (every N minutes, hourly, daily, weekly, monthly, or full 5-field cron).
  - **`webhook`** — exposes a public URL `POST /api/workflows/incoming/<code>` that fires the workflow when called with the right `X-Workflow-Secret` header.
- **Actions** — a list, run in order. Each action has a type, optional **name** (so later actions can reference its result), optional **condition**, and a **stopOnError** flag. Action types:
  - `set_field` — update fields on a custom record.
  - `create_record` — insert into a custom entity.
  - `http_request` — outbound HTTP (one shot, no retries — use `webhook` for retries).
  - `dispatch_event` — fire a system event (chains other workflows).
  - `create_approval` — create an `ApprovalRequest`.
  - `log` — write to system logs (debugging).
  - `notify_user` — send an in-app notification.
  - `send_email` — send an email (no-op when SMTP isn't configured).

The editor has a **visual chain builder** by default and an **Advanced (raw JSON)** toggle for power users. Expressions like `{{trigger.row.id}}` and `{{steps.<name>.<key>}}` template through to action params.

You can also **manually fire** a workflow from the workflows page (handy for testing) and view the **run history** with per-step results.

For deeper detail see [48-workflow-engine.md](48-workflow-engine.md).

## 13. Webhooks (outbound)

Sidebar → **Webhooks** (Super Admin). Subscribe an external URL to system events. Each delivery is HMAC-SHA256-signed; receivers verify with the per-subscription secret.

Built-in events: `approval.requested`, `approval.approved`, `approval.rejected`, `approval.cancelled`, `backup.created`, `webhook.test`, plus `record.created/updated/deleted` for any custom entity.

Failed deliveries retry 3 times with backoff. Recent attempts are visible per subscription. See [27-webhooks.md](27-webhooks.md) and the multi-language verifier helpers in [tools/webhook-verify/](../tools/webhook-verify/).

## 14. Pages — the page builder

Sidebar → **Pages** (Super Admin). Build custom pages out of blocks: text, headings, images, cards, buttons, forms, tables, charts, html, iframes, containers, dividers, spacers, and more.

- **Drag-and-drop** to reorder.
- **Conditional visibility** per block (show only when a permission / role / setting matches).
- **Live preview** at `/p/<code>`.
- A page can also appear in the sidebar by toggling **Show in sidebar**.
- **Buttons** can navigate (a route) **OR fire a workflow** (set the workflow code + optional payload).

Pages live in the database, so you can capture them in a **Template** and replay on another install.

## 15. Templates — capture & share a setup

Sidebar → **Templates** (Super Admin). A template is a snapshot of:

- **Theme** — the active theme's data
- **Business** — custom entities + their column configs + the chosen business type
- **Pages** — every custom page + its blocks (parent/child links preserved)
- **Reports** — report definitions
- **Queries** — saved SQL queries
- **Workflows** — workflow definitions
- **Subsystem metadata** — branding overrides + module list (for the Phase 4.12 build-subsystem CLI)

You can capture **theme only**, **business only**, **pages only**, **reports only**, **queries only**, or **full** (everything). Templates can be **applied** locally, **exported as JSON**, or **imported** from JSON. This is how you ship "an installation" between machines — or how a vendor packages a customer's install for redistribution.

## 16. Backups & restore

Sidebar → **Backups** (Super Admin).

- **Create backup** — snapshots the database. SQLite backups are file copies; Postgres / MySQL use native `pg_dump` / `mysqldump`.
- **Encryption** — when `BACKUP_ENCRYPTION_KEY` is set in the server env, backups are written as `MCEB v2` AES-256-GCM streams. Without the key set, plaintext.
- **Restore** — pick a backup; the system restores into the live DB. **Be very careful** — a restore overwrites everything since the snapshot.
- **Download** — pulls the backup file; admins can also generate **HMAC-signed download URLs** that anyone with the link can use until they expire (useful for off-site sync receivers).
- **Retention** — an hourly cron prunes old backups by age + count, with a min-keep floor. Configurable via system settings.

The off-site sync receiver lives in [tools/backup-sync/](../tools/backup-sync/) and supports S3-compatible providers (B2, Wasabi, MinIO, R2, AWS) or `restic`.

## 17. Themes & branding

Sidebar → **Appearance** (Super Admin). Edit:

- Mode (light / dark)
- Color palette (primary, secondary, accent, surface, sidebar, top bar, text colors)
- Typography (font family, base size)
- Component radii (buttons, cards, tables)
- Shadows + gradients (with from/to colors and direction)
- Background image (uploaded), logo, favicon
- Login style (split / centered / minimal) + login overlay
- Glass / transparency settings

Themes can be **global** (apply to everyone) or **company-specific** (one company sees a different theme). The active theme loads at app boot — no rebuild required.

For per-customer subsystem builds, branding overrides (`appName`, `logoUrl`, `primaryColor`) ship inside the template and apply automatically. See [44-subsystem-builds.md](44-subsystem-builds.md).

## 18. Switching language

Top bar → **Language** dropdown. Bundled locales: **English**, **Arabic** (RTL), **French**.

To add a new language or edit existing translations: sidebar → **Translations** (Super Admin). Edit per-key in a structured editor (search, untranslated-only filter, drop-orphans toggle). Saves write to the server's ARB files; a `flutter gen-l10n` rebuild is required for changes to take effect on already-installed binaries.

## 19. Audit log

Sidebar → **Audit Logs**. Every mutation in the system writes a row with: actor (user id), action, entity, entityId, ip, user-agent, optional metadata JSON, and a timestamp.

Filter by user, entity, action, or date range. Export to CSV.

## 20. Common questions

**Q: I see "Permission denied" but I'm sure I should have access.**
Open the avatar menu → check that you're signed in as the right user. Then have an admin verify your roles + per-user overrides on the **Users** page.

**Q: The sidebar item I want isn't showing.**
You don't have `<module>.view`. Ask an admin to grant it (either through your role or as a per-user override).

**Q: Reset my password without admin help?**
Use **Forgot password?** on the sign-in page. If the system tells you email isn't configured, you'll need an admin to generate a reset token for you.

**Q: I lost my 2FA device.**
Use one of the recovery codes you saved at enrollment — they work in place of a TOTP code (one-time each). If you've used them all, ask an admin to **Reset 2FA** on your account from the Users page.

**Q: How do I delete my account?**
Self-deletion isn't supported — ask an admin. The audit history is preserved even after a user is removed.

**Q: My session expired in the middle of work.**
Refresh tokens are valid for 7 days by default. If you're away longer than that, you'll be redirected to sign-in; nothing in-flight gets corrupted because every mutation is server-side.

**Q: Is data backed up automatically?**
Only when an admin configures the backup retention policy or schedules a cron. There is no implicit nightly backup. See section 16.

**Q: Where do I report a bug?**
Open an issue on the GitHub repo using the **Bug report** template. For security issues, use **Report a vulnerability** in the Security tab — never open a public issue. See [SECURITY.md](../SECURITY.md).

---

For deeper docs on individual subsystems, browse [docs/README.md](README.md) — it's organised by topic.
