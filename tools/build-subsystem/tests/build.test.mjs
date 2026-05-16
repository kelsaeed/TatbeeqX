// Regression tests for build.mjs staging.
//
// Uses node:test (built into Node 20+) — same as prune.test.mjs.
// Run with:  cd tools/build-subsystem && node --test tests/*.test.mjs
// (a bare `node --test tests/` is misparsed as a script path on
// Node 24 / Windows — pass explicit file globs.)
//
// Guards the dangerous defect fixed 2026-05-16: the staging copy used
// to drag the vendor's own backend/prisma/dev.db (studio rows + bcrypt
// hashes + JWT secrets) into every shipped customer bundle, while the
// bundle's .env pointed at a different, fresh DB. Dead weight + a real
// data/secret leak.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { copyTree, SQLITE_DB_FILES } from '../build.mjs';

test('copyTree drops SQLite db + sidecars, keeps prisma schema/migrations, honors skipDirs', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-copytree-'));
  const src = path.join(root, 'src');
  const dest = path.join(root, 'dest');
  fs.mkdirSync(path.join(src, 'prisma', 'migrations', '0001_init'), { recursive: true });
  // The leak: these must NOT survive the copy.
  fs.writeFileSync(path.join(src, 'prisma', 'dev.db'), 'studio rows + secrets');
  fs.writeFileSync(path.join(src, 'prisma', 'dev.db-wal'), 'wal');
  fs.writeFileSync(path.join(src, 'prisma', 'dev.db-shm'), 'shm');
  fs.writeFileSync(path.join(src, 'prisma', 'dev.db-journal'), 'journal');
  // The keep: required for `prisma migrate deploy` + seed on first boot.
  fs.writeFileSync(path.join(src, 'prisma', 'schema.prisma'), 'datasource db {}');
  fs.writeFileSync(path.join(src, 'prisma', 'seed.js'), '// seed');
  fs.writeFileSync(
    path.join(src, 'prisma', 'migrations', '0001_init', 'migration.sql'),
    'CREATE TABLE x;',
  );
  fs.mkdirSync(path.join(src, 'node_modules'), { recursive: true });
  fs.writeFileSync(path.join(src, 'node_modules', 'junk.js'), 'x');

  copyTree(src, dest, { skipDirs: ['node_modules'], skipFilePatterns: SQLITE_DB_FILES });

  for (const leak of ['dev.db', 'dev.db-wal', 'dev.db-shm', 'dev.db-journal']) {
    assert.equal(
      fs.existsSync(path.join(dest, 'prisma', leak)),
      false,
      `${leak} must NOT be copied into a bundle (studio data/secret leak)`,
    );
  }
  assert.equal(
    fs.existsSync(path.join(dest, 'prisma', 'schema.prisma')),
    true,
    'schema.prisma must be preserved',
  );
  assert.equal(fs.existsSync(path.join(dest, 'prisma', 'seed.js')), true);
  assert.equal(
    fs.existsSync(path.join(dest, 'prisma', 'migrations', '0001_init', 'migration.sql')),
    true,
    'migrations must be preserved (needed by `prisma migrate deploy`)',
  );
  assert.equal(
    fs.existsSync(path.join(dest, 'node_modules')),
    false,
    'skipDirs must still be honored alongside skipFilePatterns',
  );

  fs.rmSync(root, { recursive: true, force: true });
});

test('importing build.mjs does not trigger a build', () => {
  // If the import at the top of this file had run main(), the process
  // would have exited (missing --template/--out). Reaching here is the
  // assertion.
  assert.ok(true);
});
