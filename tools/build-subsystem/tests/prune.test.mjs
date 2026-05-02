// Phase 4.16 — pruner tests.
//
// Uses node:test (built into Node 20+) so we don't need a test-framework
// dep in tools/build-subsystem. Run with:
//
//   cd tools/build-subsystem && node --test tests/

import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import {
  pruneLineMarkers,
  pruneBlockMarkers,
  pruneSource,
  pruneBackendRoutes,
  pruneFrontendRouter,
  deleteOrphanedSources,
  prune,
  KNOWN_MODULES,
} from '../prune.mjs';

// ----- pruneLineMarkers --------------------------------------------------

test('pruneLineMarkers keeps unmarked lines verbatim', () => {
  const src = [
    "import { Router } from 'express';",
    "import auth from './auth.js';",
    "import users from './users.js';",
    'const router = Router();',
  ].join('\n');
  const out = pruneLineMarkers(src, new Set());
  assert.equal(out, src);
});

test('pruneLineMarkers drops lines whose marker is not in the allowed set', () => {
  const src = [
    "import auth from './auth.js';",
    "import themes from './themes.js';   // MOD: themes",
    "import pages from './pages.js';     // MOD: pages",
    "import database from './db.js';     // MOD: database",
  ].join('\n');
  const out = pruneLineMarkers(src, new Set(['pages']));
  assert.match(out, /import auth/);          // unmarked → kept
  assert.match(out, /import pages/);          // listed → kept
  assert.doesNotMatch(out, /import themes/);  // not listed → dropped
  assert.doesNotMatch(out, /import database/);
});

test('pruneLineMarkers handles trailing whitespace after marker', () => {
  const src = "import x from 'x'; // MOD: themes   \nimport y from 'y'; // MOD: themes";
  const out = pruneLineMarkers(src, new Set());
  assert.equal(out.trim(), '');
});

// ----- pruneBlockMarkers -------------------------------------------------

test('pruneBlockMarkers drops the entire bracketed region when not allowed', () => {
  const src = [
    'before',
    '// MOD-BEGIN: themes',
    '  GoRoute(...),',
    '  GoRoute(...),',
    '// MOD-END: themes',
    'after',
  ].join('\n');
  const out = pruneBlockMarkers(src, new Set());
  assert.match(out, /^before/m);
  assert.match(out, /^after/m);
  assert.doesNotMatch(out, /GoRoute/);
  assert.doesNotMatch(out, /MOD-(BEGIN|END)/);
});

test('pruneBlockMarkers strips marker lines but keeps body when allowed', () => {
  const src = [
    'before',
    '// MOD-BEGIN: pages',
    '  GoRoute(path: "/pages"),',
    '// MOD-END: pages',
    'after',
  ].join('\n');
  const out = pruneBlockMarkers(src, new Set(['pages']));
  assert.match(out, /GoRoute\(path: "\/pages"\)/);
  // marker lines themselves are removed even when block is kept,
  // so the file looks normal post-prune
  assert.doesNotMatch(out, /MOD-(BEGIN|END)/);
});

test('pruneBlockMarkers throws on nested MOD-BEGIN', () => {
  const src = [
    '// MOD-BEGIN: a',
    '// MOD-BEGIN: b',
    '// MOD-END: b',
    '// MOD-END: a',
  ].join('\n');
  assert.throws(() => pruneBlockMarkers(src, new Set()), /nested MOD-BEGIN/);
});

test('pruneBlockMarkers throws on mismatched MOD-END', () => {
  const src = [
    '// MOD-BEGIN: a',
    'body',
    '// MOD-END: b',
  ].join('\n');
  assert.throws(() => pruneBlockMarkers(src, new Set()), /mismatched MOD-END/);
});

test('pruneBlockMarkers throws on unterminated MOD-BEGIN', () => {
  const src = [
    '// MOD-BEGIN: a',
    'body',
  ].join('\n');
  assert.throws(() => pruneBlockMarkers(src, new Set()), /unterminated MOD-BEGIN/);
});

// ----- pruneSource (combined) -------------------------------------------

test('pruneSource composes block + line markers', () => {
  const src = [
    "import auth from './auth.js';",
    "import themes from './themes.js'; // MOD: themes",
    '// MOD-BEGIN: themes',
    '  GoRoute(path: "/themes"),',
    '// MOD-END: themes',
    "import pages from './pages.js'; // MOD: pages",
  ].join('\n');
  const out = pruneSource(src, new Set(['pages']));
  assert.match(out, /import auth/);
  assert.match(out, /import pages/);
  assert.doesNotMatch(out, /import themes/);
  assert.doesNotMatch(out, /GoRoute\(path: "\/themes"\)/);
});

// ----- file-level pruners on a temp staging dir --------------------------

function setupStaging() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'prune-test-'));
  const beIndex = path.join(dir, 'backend', 'src', 'routes', 'index.js');
  const feRouter = path.join(dir, 'frontend', 'lib', 'routing', 'app_router.dart');
  fs.mkdirSync(path.dirname(beIndex), { recursive: true });
  fs.mkdirSync(path.dirname(feRouter), { recursive: true });
  fs.writeFileSync(beIndex, [
    "import auth from './auth.js';",
    "import themes from './themes.js'; // MOD: themes",
    "import pages from './pages.js';   // MOD: pages",
    'const router = Router();',
    "router.use('/auth', auth);",
    "router.use('/themes', themes); // MOD: themes",
    "router.use('/pages', pages);   // MOD: pages",
  ].join('\n'));
  fs.writeFileSync(feRouter, [
    "import 'package:flutter/material.dart';",
    "import 'features/themes/...';  // MOD: themes",
    'routes: [',
    '  // MOD-BEGIN: themes',
    '  GoRoute(path: "/themes"),',
    '  // MOD-END: themes',
    '  GoRoute(path: "/dashboard"),',
    ']',
  ].join('\n'));
  // Route file + feature dir candidates for orphan-deletion test.
  fs.mkdirSync(path.join(dir, 'backend', 'src', 'routes'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'backend', 'src', 'routes', 'themes.js'), '// theme route');
  fs.mkdirSync(path.join(dir, 'frontend', 'lib', 'features', 'themes'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'frontend', 'lib', 'features', 'themes', 'page.dart'), '// theme page');
  return { dir, beIndex, feRouter };
}

test('pruneBackendRoutes drops lines whose marker is not in allowed', () => {
  const { dir, beIndex } = setupStaging();
  try {
    const result = pruneBackendRoutes(dir, new Set(['pages']));
    assert.equal(result.changed, true);
    const after = fs.readFileSync(beIndex, 'utf8');
    assert.match(after, /import auth/);
    assert.match(after, /import pages/);
    assert.doesNotMatch(after, /import themes/);
    assert.doesNotMatch(after, /router\.use\('\/themes'/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('pruneFrontendRouter strips block + inline markers in app_router.dart', () => {
  const { dir, feRouter } = setupStaging();
  try {
    const result = pruneFrontendRouter(dir, new Set(['pages']));
    assert.equal(result.changed, true);
    const after = fs.readFileSync(feRouter, 'utf8');
    assert.doesNotMatch(after, /features\/themes/);
    assert.doesNotMatch(after, /GoRoute\(path: "\/themes"\)/);
    assert.match(after, /GoRoute\(path: "\/dashboard"\)/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('deleteOrphanedSources removes route files + feature dirs of dropped modules', () => {
  const { dir } = setupStaging();
  try {
    const result = deleteOrphanedSources(dir, new Set(['pages'])); // themes is dropped
    assert.ok(result.droppedBackend.includes('routes/themes.js'));
    assert.ok(result.droppedFrontend.includes('features/themes'));
    assert.equal(fs.existsSync(path.join(dir, 'backend', 'src', 'routes', 'themes.js')), false);
    assert.equal(fs.existsSync(path.join(dir, 'frontend', 'lib', 'features', 'themes')), false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('prune end-to-end — applies all stages and reports a summary', () => {
  const { dir } = setupStaging();
  try {
    const summary = prune(dir, { modules: ['pages'] });
    assert.deepEqual(summary.declared, ['pages']);
    assert.equal(summary.backendRoutes.changed, true);
    assert.equal(summary.frontendRouter.changed, true);
    assert.ok(summary.orphans.droppedBackend.length > 0);
    assert.ok(summary.orphans.droppedFrontend.length > 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('prune is a no-op when no modules are declared (nothing in template) — drops everything optional', () => {
  const { dir } = setupStaging();
  try {
    const summary = prune(dir, {}); // no modules → empty allowed
    assert.deepEqual(summary.declared, []);
    // Both files had only optional markers; everything optional gets dropped.
    assert.equal(summary.backendRoutes.changed, true);
    assert.equal(summary.frontendRouter.changed, true);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('KNOWN_MODULES exposes the union of backend + frontend prune catalogs', () => {
  // Sanity — the pruner has an opinion on these regardless of usage.
  for (const code of ['themes', 'database', 'custom-entities', 'templates', 'pages', 'system', 'webhooks', 'translations']) {
    assert.ok(KNOWN_MODULES.has(code), `${code} should be a known module`);
  }
});

// ----- Sanity guards (Phase 4.16 v1 cleanup) ----------------------------

test('prune force-keeps `business` when template.businessType is unset (Setup wizard would 404 otherwise)', () => {
  const { dir, beIndex } = setupStaging();
  // Re-create with a `business` line to exercise the guard.
  fs.writeFileSync(beIndex, [
    "import auth from './auth.js';",
    "import business from './business.js'; // MOD: business",
    "import themes from './themes.js';     // MOD: themes",
    "router.use('/auth', auth);",
    "router.use('/business', business);    // MOD: business",
    "router.use('/themes', themes);        // MOD: themes",
  ].join('\n'));
  try {
    // Template declares NO modules and NO businessType → guard should
    // force-keep `business` even though it's not in modules.
    const summary = prune(dir, {});
    assert.equal(summary.forceKept.length, 1);
    assert.equal(summary.forceKept[0].module, 'business');
    assert.match(summary.forceKept[0].reason, /Setup wizard/);
    const after = fs.readFileSync(beIndex, 'utf8');
    assert.match(after, /import business/);
    assert.match(after, /router\.use\('\/business'/);
    assert.doesNotMatch(after, /import themes/); // still pruned
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('prune does NOT force-keep `business` when template.businessType is set (Setup is already done)', () => {
  const { dir, beIndex } = setupStaging();
  fs.writeFileSync(beIndex, [
    "import auth from './auth.js';",
    "import business from './business.js'; // MOD: business",
    "router.use('/business', business);    // MOD: business",
  ].join('\n'));
  try {
    const summary = prune(dir, { businessType: 'retail' });
    assert.equal(summary.forceKept.length, 0);
    const after = fs.readFileSync(beIndex, 'utf8');
    assert.doesNotMatch(after, /import business/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('prune does NOT redundantly force-keep `business` when it is already declared in modules', () => {
  const { dir } = setupStaging();
  try {
    // No businessType, but business is explicitly listed → guard fires
    // but adds nothing new to the allowed set.
    const summary = prune(dir, { modules: ['business'] });
    // forceKept should be empty because the module was already in `allowed`.
    assert.equal(summary.forceKept.length, 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
