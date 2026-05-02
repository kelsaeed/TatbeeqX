# 35 — Route-layer tests

Phase 4.6 adds end-to-end HTTP tests that exercise the live Express app via `supertest`. Combined with the existing lib-layer tests, the suite now stands at **83 tests / 8 files**.

- Test runner: `vitest`
- HTTP client: `supertest` (dev dependency, ESM-friendly)
- Test file: [`backend/tests/routes.test.js`](../backend/tests/routes.test.js)
- App factory: [`backend/src/lib/app.js`](../backend/src/lib/app.js) — extracted from `server.js` so tests can mount the app without binding a port

## What was extracted

`src/server.js` previously built the Express app inline and immediately called `app.listen`. Tests need the *configured* app without the port binding and without the cron loop. So the build is now:

```js
// src/lib/app.js
export function buildApp({ silent = false } = {}) {
  const app = express();
  // helmet, cors, json, morgan, /uploads, /api, error handlers
  return app;
}

// src/server.js
const app = buildApp();
app.listen(env.port, env.host, () => {
  startCronLoop();
  // ...
});
```

`silent: true` skips the morgan logger so the test output stays readable.

## Test strategy

The route tests run against the **live dev SQLite database** that the seeder already populated. They are deliberately:

- **Read-mostly**: the few writes (login → records a `LoginEvent` and bumps `lastLoginAt`) are additive and idempotent — they don't break fixture state for subsequent runs.
- **No teardown**: tests don't have to clean up because they don't disturb the seed.
- **Fast**: ~500 ms total because there's no DB spin-up cost.

The trade-off: you can't run these tests against a totally pristine DB without re-seeding first. If you need that, add `npm run db:reset && npm test` to your local script.

## What is covered

| Endpoint | Test |
|---|---|
| `GET /api/health` | publicly reachable, `{ ok: true, time }` shape |
| `POST /api/auth/login` | bad credentials → 401; seeded credentials → 200 with tokens; login records a `LoginEvent` (verified via `/login-events`) |
| `GET /api/auth/me` | rejects no-token with 401; returns user + permissions with token |
| `GET /api/permissions` | catalog non-empty, contains `users.view` |
| `GET /api/menus` | tree non-empty for super admin |
| `GET /api/templates/kinds` | exposes the six Phase 4.2 kinds |
| `POST /api/auth/refresh` | empty body → 400; bogus token → 401; valid token → 200 with new tokens |
| `POST /api/db/query` | read-only `SELECT 1` works; `UPDATE users …` blocked at validation layer |

## Running

```bash
cd backend
npm run db:seed     # only needed if you've blown away the DB
npm test
```

`npm run test:watch` runs vitest in watch mode for TDD on the lib layer; route tests work fine in watch too, but they all share the seeded DB so changes can leak between watched runs.

## Adding a new route test

1. Import `buildApp` and `supertest`:
   ```js
   import request from 'supertest';
   import { buildApp } from '../src/lib/app.js';
   const app = buildApp({ silent: true });
   ```
2. Get a token in `beforeAll` (the existing pattern):
   ```js
   const res = await request(app).post('/api/auth/login').send({ username, password });
   token = res.body.accessToken;
   ```
3. Call the endpoint with `.set('Authorization', \`Bearer ${token}\`)`.

For an endpoint that mutates state (e.g. creating a webhook subscription), prefer a **delete-after-create** pattern so the test cleans up after itself:

```js
const created = await request(app).post('/api/webhooks').set(auth).send({...});
try {
  // assertions
} finally {
  await request(app).delete(`/api/webhooks/${created.body.id}`).set(auth);
}
```

## What's still missing

- **Isolated test database.** The current suite shares the dev DB; mutating tests have to clean up themselves. A `globalSetup` hook that points `DATABASE_URL` at a temp file + runs `prisma db push` per-suite would fix this.
- **Per-feature smoke tests** for routes the existing suite doesn't touch yet (custom entities CRUD, page-block reorder, approval lifecycle, schedule run-now).
- **Negative permission tests** — confirm a non-Super-Admin gets 403 on Super-Admin endpoints.

These are tractable additions; tracked under "Phase 4.7 — test depth" in [20-roadmap.md](20-roadmap.md).
