# 38 — Isolated per-suite test DB

Phase 4.8 adds a vitest `globalSetup` hook that copies the seeded dev DB into a per-run temp file and points `DATABASE_URL` at it before any test file imports. Tests can now mutate freely without leaving traces in the dev DB across runs.

- Setup: [`backend/tests/setup.js`](../backend/tests/setup.js)
- Vitest config: [`backend/vitest.config.js`](../backend/vitest.config.js)
- Loaded via `globalSetup` so it runs before Prisma's singleton client construction

## Why globalSetup, not beforeAll

Prisma reads `DATABASE_URL` once when the client is constructed (`new PrismaClient()` inside `lib/prisma.js`). Any URL change after that point is ignored. By the time a test file's `beforeAll` runs, the import chain has already loaded `lib/prisma.js` (transitively, via the route under test) and frozen the URL.

`globalSetup` runs in a separate vitest phase **before any test file is imported**, which is the only way to inject `process.env.DATABASE_URL` early enough.

## What it does

```js
// tests/setup.js
export async function setup() {
  // 1. Confirm the source dev DB exists (seeder must have run).
  const src = path.resolve(process.cwd(), 'prisma', 'dev.db');

  // 2. Copy it to a per-run temp file in the OS tempdir.
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'mc-test-'));
  tempPath = path.join(tmpDir, 'test.db');
  fs.copyFileSync(src, tempPath);

  // 3. Inject an absolute file: URL so Prisma's CWD-relative resolution
  //    can't bite us.
  process.env.DATABASE_URL = `file:${tempPath}`;
  process.env.MC_TEST_DB_PATH = tempPath;
}

export async function teardown() {
  // Best-effort cleanup; OS reaps /tmp eventually.
  fs.unlinkSync(tempPath);
  fs.rmdirSync(path.dirname(tempPath));
}
```

## Verifying isolation

After `npm test`, the dev DB should have no `test_perm_*` users (the fixture suite for [`routes_permissions.test.js`](../backend/tests/routes_permissions.test.js) creates one per run):

```bash
cd backend
node -e "import('./src/lib/prisma.js').then(async ({prisma}) => { \
  const u = await prisma.user.findMany({where: {username: {startsWith: 'test_perm_'}}}); \
  console.log('dev DB test users:', u.length); \
  await prisma.\$disconnect(); \
})"
# → dev DB test users: 0
```

If that command ever returns a non-zero count, the isolation is broken. Likely cause: someone used `prisma.user.create(...)` in a test without consulting `process.env.DATABASE_URL` (i.e. they instantiated their own Prisma client with a hard-coded URL).

## When the source DB needs reseeding

The setup copies whatever state the dev DB is in. If you've manually mutated the dev DB and want a clean test start:

```bash
npm run db:reset    # blow away dev.db, re-migrate, re-seed
npm test            # tests run against a fresh copy of the freshly seeded DB
```

`npm run db:seed` alone is enough if the schema hasn't changed.

## Trade-offs vs. a fully spun-up test DB

This approach copies the source DB rather than running migrations against a fresh `:memory:` SQLite. Trade-offs:

| Approach | Pros | Cons |
|---|---|---|
| **Copy seeded dev DB (chosen)** | fast (`copyFileSync` is ~milliseconds); identical schema to prod; no migration time per run | requires the seeder to have run at least once; resets to whatever the seed last produced, not to "empty" |
| `prisma db push` to a fresh temp DB per run | guarantees clean state regardless of dev DB | adds ~2–3 s per `npm test`; needs prisma CLI on PATH |
| `:memory:` with manual schema | fastest | impossible — Prisma SQLite engine doesn't support `:memory:` cleanly across reconnects |

When the test suite outgrows the copy-and-mutate model (e.g. for tests that need a known-empty DB), switch to the `prisma db push` strategy by extending `setup.js` to invoke `npx prisma db push --skip-generate` against the temp file. Today's tests are read-mostly + self-cleaning, so the copy approach is sufficient.

## CI

In CI the steps are:

```bash
npm ci
npm run db:reset    # produces a known-state dev DB
npm test            # globalSetup copies + isolates
```

The temp DB lives under `$TMPDIR` (or `os.tmpdir()`) and gets cleaned in `teardown()`. CI runners usually wipe `$TMPDIR` between jobs anyway.

## Caveats

- **`MC_TEST_DB_PATH` is exposed** so tests can inspect the temp file directly if they need to (e.g. for backup tests). Don't rely on the path layout — only use it for debugging.
- **The setup throws if the seeder hasn't run.** This is a deliberate fail-fast — running tests against a missing source DB would silently give Prisma a non-existent `file:` path and produce confusing "table not found" errors.
- **Cron loop is not started in tests** because `buildApp()` (used by tests) doesn't invoke `startCronLoop()` — only `server.js` does. So scheduled jobs don't fire from test runs.
