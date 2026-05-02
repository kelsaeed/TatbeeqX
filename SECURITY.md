# Security Policy

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Instead, report privately via GitHub's coordinated disclosure flow:

1. Go to the [Security tab](https://github.com/kelsaeed/TatbeeqX/security) of the repo.
2. Click **"Report a vulnerability"**.
3. Describe the issue, the affected version (commit SHA or release tag), reproduction steps, and the impact you observed.

A maintainer will respond within **7 days** with an acknowledgement and a rough timeline for the fix. Please give us a reasonable window before any public disclosure (typically 90 days, shorter if the vulnerability is being actively exploited).

## Scope

In scope:

- The backend API in `backend/` (auth, permissions, data access, file uploads, SQL runner safety, webhooks, workflow engine, backups).
- The Flutter frontend in `frontend/` (auth state handling, token storage, deep links, page-renderer XSS surfaces).
- The build/operation tools in `tools/` (subsystem builds, off-site backup sync, signed-URL handling).

Out of scope:

- Vulnerabilities that require physical access to a host already running the backend.
- Issues in third-party dependencies — please report those upstream first; we'll bump the dep once a fix is published.
- Findings that depend on misconfiguration explicitly called out in [SETUP.md](SETUP.md) or [docs/17-pitfalls.md](docs/17-pitfalls.md) (e.g. `CORS_ORIGIN=*` on a public deployment, `JWT_*_SECRET` left at the default value).

## Hardening notes

The project has a documented security baseline:

- **Auth**: JWT access (15min) + revocable refresh tokens with rotation + reuse detection + per-IP login rate limiting + timing-safe password compare + per-row login event audit + sessions UI + log-out-everywhere.
- **2FA**: TOTP + recovery codes (Phase 4.16 follow-up).
- **Password reset**: admin-token, hash-stored, single-use, 24h TTL, no SMTP dependency (Phase 4.16 follow-up).
- **Backups**: AES-256-GCM at rest with key rotation; HMAC-signed download URLs.
- **Webhooks**: HMAC-SHA256 signed deliveries with retry + replay-safe.
- **Workflow engine** (Phase 4.17): admin-defined automation runs system-privileged; incoming webhook trigger uses constant-time secret compare on `X-Workflow-Secret`.
- **SQL runner**: read-only by default, blocks auth tables even in write mode, hard 10k-char limit, per-query audit.

If you find a hole in any of these, that's exactly the kind of report we want.

## Known limitations (not vulnerabilities, but worth knowing)

- No SSO/OAuth — username/password + 2FA only today.
- No global per-route rate limiting (only login is rate-limited).
- No KMS/vault integration for `BACKUP_ENCRYPTION_KEY` — env var only.
- No SMTP — password reset is admin-token-only by design.

These are tracked as open work, not issues.
