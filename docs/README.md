# Documentation — TatbeeqX

This folder is the documentation hub. It is the place to look first when you (or a future Claude session) need to understand what the system is, how it is wired, and where it stands.

If you are starting a brand-new session, read these in order:

1. [01-overview.md](01-overview.md) — what the system is, who it is for, and the design goals
2. [02-tech-stack.md](02-tech-stack.md) — runtimes, dependencies, conventions
3. [03-getting-started.md](03-getting-started.md) — first-time setup and how to run it
4. [18-phases.md](18-phases.md) — phase status (where we are right now)

The rest is reference.

## Index

### Foundation
- [01-overview.md](01-overview.md) — system description + architecture
- [02-tech-stack.md](02-tech-stack.md) — stack and conventions
- [03-getting-started.md](03-getting-started.md) — install + run

### Access control
- [04-roles.md](04-roles.md) — the 5 default roles
- [05-permissions.md](05-permissions.md) — permission codes, model, effective resolution

### Surface area
- [06-modules.md](06-modules.md) — the 13 core modules
- [07-api-reference.md](07-api-reference.md) — REST endpoints
- [08-database-schema.md](08-database-schema.md) — Prisma tables

### Subsystems
- [09-theme-builder.md](09-theme-builder.md) — dynamic theming
- [10-business-presets.md](10-business-presets.md) — retail / restaurant / clinic / factory / finance / rental / blank
- [11-custom-entities.md](11-custom-entities.md) — user-defined tables with auto-CRUD
- [12-database-admin.md](12-database-admin.md) — table explorer + SQL runner
- [13-reports.md](13-reports.md) — report builders and chart toggle
- [14-templates.md](14-templates.md) — capture / apply / import / export
- [15-uploads.md](15-uploads.md) — file upload endpoint and UI integration
- [21-page-builder.md](21-page-builder.md) — custom pages composed from blocks
- [22-system-config.md](22-system-config.md) — DB connections, init SQL, server info
- [23-logs.md](23-logs.md) — audit / system / login event viewers
- [24-quick-presets.md](24-quick-presets.md) — view / view+edit / view+edit+delete / full / none per module
- [25-workflows.md](25-workflows.md) — approval queue + per-entity decide gate
- [26-scheduled-reports.md](26-scheduled-reports.md) — recurring report runs + cron loop
- [27-webhooks.md](27-webhooks.md) — outbound HTTP notifications, HMAC-signed
- [28-conditional-visibility.md](28-conditional-visibility.md) — page-block `visibleWhen` rules
- [29-claim-handlers.md](29-claim-handlers.md) — server-side approval-decision hooks
- [30-deploy-docker.md](30-deploy-docker.md) — `docker compose` topology
- [31-i18n.md](31-i18n.md) — locale switcher + RTL foundation
- [32-i18n-strings.md](32-i18n-strings.md) — gen_l10n ARB workflow
- [33-backups.md](33-backups.md) — DB backup/restore endpoints + UI
- [34-builder-analytics.md](34-builder-analytics.md) — `/api/pages/analytics` summary
- [35-route-tests.md](35-route-tests.md) — supertest-based HTTP integration tests
- [36-native-backups.md](36-native-backups.md) — `pg_dump` / `mysqldump` for cloud primaries
- [37-encrypted-backups.md](37-encrypted-backups.md) — optional AES-256-GCM via `BACKUP_ENCRYPTION_KEY`
- [38-test-isolation.md](38-test-isolation.md) — per-suite test DB via vitest `globalSetup`
- [39-key-rotation.md](39-key-rotation.md) — `BACKUP_ENCRYPTION_KEY` rotation endpoint
- [40-offsite-sync.md](40-offsite-sync.md) — off-site backup sync receiver tool
- [41-cross-host-sync.md](41-cross-host-sync.md) — HTTPS download with HMAC-signed URLs
- [42-translation-management.md](42-translation-management.md) — ARB editor over the API + UI
- [44-subsystem-builds.md](44-subsystem-builds.md) — branded, locked-down customer binaries
- [45-mobile-shell.md](45-mobile-shell.md) — iOS + Android shells (Phase 4.14)

### Operations
- [16-deployment.md](16-deployment.md) — LAN today, cloud later
- [17-pitfalls.md](17-pitfalls.md) — known gotchas and their fixes

### Project state
- [18-phases.md](18-phases.md) — phase status and **current phase**
- [19-memory.md](19-memory.md) — durable project memory (mirrors `MEMORY.md`)
- [20-roadmap.md](20-roadmap.md) — what is next

## Conventions

- **Source of truth**: code wins over docs. If a doc disagrees with the code, fix the doc.
- **Single project memory**: long-lived facts live in `MEMORY.md` at the project root and are mirrored in [19-memory.md](19-memory.md). Update both together.
- **Phase status**: tracked only in [18-phases.md](18-phases.md). Don't duplicate.
- **API/database tables**: the canonical lists are [07-api-reference.md](07-api-reference.md) and [08-database-schema.md](08-database-schema.md).

## Default credentials

```
username: superadmin
password: ChangeMe!2026
```

Change immediately after first login. Override at seed time via `SEED_SUPERADMIN_USERNAME`, `SEED_SUPERADMIN_EMAIL`, `SEED_SUPERADMIN_PASSWORD` in `backend/.env`.
