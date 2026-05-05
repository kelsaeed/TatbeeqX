# Contributing to TatbeeqX

Thanks for considering a contribution. This file explains how to run the project locally, the conventions the codebase follows, and what a good PR looks like.

## Quick start

You'll need:

- **Node.js 20+** (for the backend)
- **Flutter 3.41+** (for the frontend; Windows desktop is the primary target, web also works)
- A POSIX-ish shell. Windows PowerShell + Git Bash both work.

```bash
# 1. Clone
git clone https://github.com/kelsaeed/TatbeeqX
cd TatbeeqX

# 2. Backend — installs deps, runs migrations, seeds data, starts on :4040
cd backend
cp .env.example .env
npm install
npm run db:reset    # one-shot: migrate + seed; safe to re-run
npm run dev

# 3. Frontend — second terminal
cd frontend
flutter pub get
flutter run -d windows   # or: -d chrome / -d macos / -d linux
```

Default Super Admin login (change it on first run):

```
username: superadmin
password: ChangeMe!2026
```

## Project layout

- `backend/` — Express API, Prisma schema, seeders, vitest tests
- `frontend/` — Flutter app (Riverpod + go_router + dio)
- `tools/` — operations utilities (subsystem builds, off-site backup sync, multi-language webhook verifier helpers)
- `docs/` — design docs, phase notes, runbooks; start at [docs/README.md](docs/README.md)

A new feature usually touches: a Prisma model + migration, a `routes/<feature>.js`, a Flutter feature folder, and a docs page.

## Tests

- **Backend**: `cd backend && npm test` — vitest, isolated per-run DB (see `tests/setup.js`). 26 test files / 310 tests as of Phase 4.17 v2.
- **Frontend**: `cd frontend && flutter analyze` — must be zero issues. `flutter test` runs widget tests when present.

CI runs both on every push to `main` and every PR. See [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Code conventions

- **Comments explain *why*, not *what***. Names should carry the *what*. Save comments for non-obvious constraints, workarounds, or invariants — not for restating the next line.
- **No native Flutter plugins** — this is a hard rule. The repo intentionally avoids them so Windows builds don't need Developer Mode. Token storage uses `dart:io`, not `shared_preferences`.
- **`bcryptjs`, not `bcrypt`** — pure JS, no native build tools required.
- **Permission codes are `<module>.<action>`** — actions in use: `view`, `create`, `edit`, `delete`, `approve`, `export`, `print`, `run`, `manage_settings`, `manage_users`, `manage_roles`.
- **Prisma `upsert` cannot null a unique-side column** — use `findFirst` then `update`/`create`. The seeder + settings code already does this; follow the pattern.
- **SQLite `PRAGMA` returns BigInt** — coerce with `Number(...)` before serializing.

More gotchas live in [docs/17-pitfalls.md](docs/17-pitfalls.md) and [docs/19-memory.md](docs/19-memory.md).

## What a good PR looks like

- **Scope** — one logical change. Refactor + feature in the same PR makes review harder than it needs to be.
- **Tests** — backend changes need a vitest covering the happy path + at least one failure mode. UI changes need at least a manual test plan in the PR body.
- **Docs** — if you change the API, update [docs/07-api-reference.md](docs/07-api-reference.md). If you change architecture, update the relevant docs page.
- **CI green** — both jobs pass locally before pushing. CI catches it too, but it's faster to fix locally.
- **Commits** — keep them readable. Squash if you have a "WIP" trail; multiple commits are fine when each tells a separate story.

## Reporting bugs / proposing features

Use the issue templates at [.github/ISSUE_TEMPLATE/](.github/ISSUE_TEMPLATE/). For security issues, follow [SECURITY.md](SECURITY.md) — please don't open a public issue.

## Phase tracking

Active phase status lives in [docs/18-phases.md](docs/18-phases.md). The project root [MEMORY.md](MEMORY.md) is the durable mirror. Update both when you ship a phase.

## License

By contributing, you agree your contribution is licensed under the project's [MIT License](LICENSE).
