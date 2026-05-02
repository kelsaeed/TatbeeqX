// Phase 4.8 — vitest globalSetup.
//
// Copies the seeded dev DB to a per-run temp file and points
// DATABASE_URL at it BEFORE the test files import Prisma. This means the
// route-layer tests can mutate freely without leaving traces in the dev
// DB across runs. Each `npm test` invocation starts from a clean copy of
// whatever state `npm run db:seed` last left.
//
// Why a globalSetup file (not just a beforeAll)? Prisma reads
// DATABASE_URL once when the singleton client is constructed. By the
// time a `beforeAll` runs, the import chain has already pulled in
// `lib/prisma.js` and frozen the URL. globalSetup runs in a separate
// phase, before any test file imports.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

let tempPath;

export async function setup() {
  // Source: the dev DB the seeder writes to.
  const src = path.resolve(process.cwd(), 'prisma', 'dev.db');
  if (!fs.existsSync(src)) {
    throw new Error(
      `Test bootstrap failed: source DB not found at ${src}. ` +
      `Run 'npm run db:seed' first.`,
    );
  }

  // Destination: a per-run temp file. Use the same naming convention the
  // backup tests expect.
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'mc-test-'));
  tempPath = path.join(tmpDir, 'test.db');
  fs.copyFileSync(src, tempPath);

  // Prisma's SQLite URL is `file:<path>` — and the path is relative to the
  // schema file's directory (i.e. `backend/prisma`). We pass an absolute
  // path so Prisma resolves it unambiguously regardless of cwd.
  process.env.DATABASE_URL = `file:${tempPath}`;
  process.env.MC_TEST_DB_PATH = tempPath;
}

export async function teardown() {
  if (!tempPath) return;
  try {
    fs.unlinkSync(tempPath);
    fs.rmdirSync(path.dirname(tempPath));
  } catch (_) {
    // best-effort cleanup; the OS will reap /tmp eventually
  }
}
