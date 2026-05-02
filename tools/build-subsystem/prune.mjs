// Phase 4.16 — code-gen pruning for subsystem builds.
//
// Given a staged copy of the repo + the template's `modules` array,
// surgically remove imports/route entries/feature dirs for any module
// not in the list. Operates on:
//
//   - backend/src/routes/index.js  (line-marker stripping)
//   - frontend/lib/routing/app_router.dart  (line + block-marker stripping)
//   - backend/src/routes/<module>.js  (file deletion when orphaned)
//   - frontend/lib/features/<module>/  (dir deletion when orphaned)
//
// Marker conventions (set up in source by Phase 4.16 first):
//
//   import x from './x.js';   // MOD: themes
//   router.use('/x', x);      // MOD: themes
//
// Multi-line blocks in app_router.dart use begin/end markers:
//
//   // MOD-BEGIN: themes
//   GoRoute(...),
//   // MOD-END: themes
//
// Lines without markers are *infra/core* and never touched. The
// always-kept set (auth, dashboard, users, etc.) doesn't need
// markers — those lines stay regardless of `template.modules`.
//
// The pruner is conservative: if a marker references a module not
// listed AND not always-kept, the line/block is dropped. Anything
// else is preserved verbatim.

import fs from 'node:fs';
import path from 'node:path';

const INLINE_MARKER = /\/\/ MOD: ([a-z0-9-]+)\s*$/;
const BLOCK_BEGIN = /^\s*\/\/ MOD-BEGIN: ([a-z0-9-]+)\s*$/;
const BLOCK_END = /^\s*\/\/ MOD-END: ([a-z0-9-]+)\s*$/;

// Module → file/dir mapping. Backend route files live one-per-module
// in routes/, named with snake_case versions of the module code.
// Frontend feature dirs live in lib/features/ also snake_case.
const MODULE_TO_BACKEND_FILES = {
  'themes': ['routes/themes.js'],
  'database': ['routes/database.js'],
  'custom-entities': ['routes/custom_entities.js', 'routes/custom_records.js'],
  'business': ['routes/business.js'],
  'templates': ['routes/templates.js'],
  'pages': ['routes/pages.js'],
  'system': ['routes/system.js'],
  'system-logs': ['routes/system_logs.js'],
  'login-events': ['routes/login_events.js'],
  'approvals': ['routes/approvals.js'],
  'report-schedules': ['routes/report_schedules.js'],
  'webhooks': ['routes/webhooks.js'],
};

const MODULE_TO_FRONTEND_DIRS = {
  'themes': ['features/themes'],
  'database': ['features/database'],
  'custom-entities': ['features/custom_entities', 'features/custom'],
  'templates': ['features/templates'],
  'pages': ['features/pages'],
  'system': ['features/system'],
  'system-logs': ['features/system_logs'],
  'login-events': ['features/login_events'],
  'approvals': ['features/approvals'],
  'report-schedules': ['features/report_schedules'],
  'webhooks': ['features/webhooks'],
  'translations': ['features/translations'],
};

// All modules pruner knows how to handle. Anything in template.modules
// that's not in this list is silently passed through (it could be a
// custom-entity-derived module like `custom:products` that has no
// pre-built feature dir to drop).
export const KNOWN_MODULES = new Set([
  ...Object.keys(MODULE_TO_BACKEND_FILES),
  ...Object.keys(MODULE_TO_FRONTEND_DIRS),
]);

/**
 * Strip lines whose `// MOD: <code>` marker isn't in the allowed set.
 * Pure: takes source text + allowed set, returns new source text.
 *
 * @param {string} source
 * @param {Set<string>} allowed
 * @returns {string}
 */
export function pruneLineMarkers(source, allowed) {
  const lines = source.split('\n');
  const out = [];
  for (const line of lines) {
    const m = line.match(INLINE_MARKER);
    if (m && !allowed.has(m[1])) continue;
    out.push(line);
  }
  return out.join('\n');
}

/**
 * Strip multi-line blocks bounded by `// MOD-BEGIN: <code>` /
 * `// MOD-END: <code>` markers when `<code>` isn't in allowed.
 * Mismatched begin/end pairs throw — better to fail loudly than to
 * ship a half-pruned file.
 *
 * @param {string} source
 * @param {Set<string>} allowed
 * @returns {string}
 */
export function pruneBlockMarkers(source, allowed) {
  const lines = source.split('\n');
  const out = [];
  let skipping = null; // currently-skipped module code, or null
  let lineNo = 0;
  for (const line of lines) {
    lineNo++;
    const begin = line.match(BLOCK_BEGIN);
    const end = line.match(BLOCK_END);
    if (begin) {
      if (skipping) throw new Error(`prune: nested MOD-BEGIN at line ${lineNo} (already inside ${skipping})`);
      if (!allowed.has(begin[1])) {
        skipping = begin[1];
        continue; // drop the BEGIN marker itself
      }
      // Even when keeping, drop the marker line so the file looks normal.
      continue;
    }
    if (end) {
      if (!skipping) {
        // End marker for a kept block — drop the marker, keep the lines we already emitted.
        continue;
      }
      if (skipping !== end[1]) throw new Error(`prune: mismatched MOD-END at line ${lineNo} (expected ${skipping}, got ${end[1]})`);
      skipping = null;
      continue; // drop the END marker
    }
    if (skipping) continue; // inside a dropped block
    out.push(line);
  }
  if (skipping) throw new Error(`prune: unterminated MOD-BEGIN: ${skipping}`);
  return out.join('\n');
}

/**
 * Combined prune: applies block-marker stripping first (so inline
 * markers inside dropped blocks aren't double-processed), then inline.
 */
export function pruneSource(source, allowed) {
  return pruneLineMarkers(pruneBlockMarkers(source, allowed), allowed);
}

/**
 * Prune backend/src/routes/index.js in place.
 */
export function pruneBackendRoutes(stagingDir, allowed) {
  const file = path.join(stagingDir, 'backend', 'src', 'routes', 'index.js');
  if (!fs.existsSync(file)) return { changed: false, reason: 'index.js not found' };
  const before = fs.readFileSync(file, 'utf8');
  const after = pruneSource(before, allowed);
  if (after === before) return { changed: false };
  fs.writeFileSync(file, after, 'utf8');
  return { changed: true, droppedLines: before.split('\n').length - after.split('\n').length };
}

/**
 * Prune frontend/lib/routing/app_router.dart in place.
 */
export function pruneFrontendRouter(stagingDir, allowed) {
  const file = path.join(stagingDir, 'frontend', 'lib', 'routing', 'app_router.dart');
  if (!fs.existsSync(file)) return { changed: false, reason: 'app_router.dart not found' };
  const before = fs.readFileSync(file, 'utf8');
  const after = pruneSource(before, allowed);
  if (after === before) return { changed: false };
  fs.writeFileSync(file, after, 'utf8');
  return { changed: true, droppedLines: before.split('\n').length - after.split('\n').length };
}

/**
 * Delete orphaned backend route files + frontend feature dirs.
 * Only deletes things in the dropped-modules set — never touches
 * always-kept paths.
 */
export function deleteOrphanedSources(stagingDir, allowed) {
  const droppedBackend = [];
  const droppedFrontend = [];

  for (const [code, files] of Object.entries(MODULE_TO_BACKEND_FILES)) {
    if (allowed.has(code)) continue;
    for (const rel of files) {
      const p = path.join(stagingDir, 'backend', 'src', rel);
      if (fs.existsSync(p)) {
        fs.rmSync(p, { force: true });
        droppedBackend.push(rel);
      }
    }
  }
  for (const [code, dirs] of Object.entries(MODULE_TO_FRONTEND_DIRS)) {
    if (allowed.has(code)) continue;
    for (const rel of dirs) {
      const p = path.join(stagingDir, 'frontend', 'lib', rel);
      if (fs.existsSync(p)) {
        fs.rmSync(p, { recursive: true, force: true });
        droppedFrontend.push(rel);
      }
    }
  }
  return { droppedBackend, droppedFrontend };
}

// Sanity guards run before pruning. Each returns null if it has no
// objection, or `{ module, reason }` describing a module that must be
// force-kept. The `prune()` function adds those modules to the allowed
// set and surfaces them in the summary so operators see what was
// "saved from pruning" and why.
const PRUNE_GUARDS = [
  // The Setup wizard hits POST /api/business. If the template's
  // businessType isn't set, the customer install will land on Setup
  // first thing — dropping the route would 404 the wizard. Once
  // setup is done (businessType saved to the system.business_type
  // setting at template-capture time), the route is no longer needed
  // and can be safely pruned.
  function setupWizardGuard(template) {
    const hasBusinessType = typeof template?.businessType === 'string' && template.businessType.trim().length > 0;
    if (hasBusinessType) return null;
    return {
      module: 'business',
      reason: 'template.businessType is unset — Setup wizard needs /api/business mounted on first run',
    };
  },
];

/**
 * Top-level pruner. Reads template.modules, builds the allowed set
 * (template-listed + sanity-guard force-keeps), and applies all the
 * prune steps. Returns a summary the build CLI can log.
 *
 * @param {string} stagingDir - the staged repo copy
 * @param {{modules?: string[], businessType?: string}} template
 */
export function prune(stagingDir, template) {
  const declared = Array.isArray(template?.modules)
    ? template.modules.filter((m) => typeof m === 'string')
    : [];
  const allowed = new Set(declared);

  // Run sanity guards — modules they flag get force-added to allowed
  // even when not declared. This protects against operator footguns
  // like dropping `business` before Setup has been run.
  const forceKept = [];
  for (const guard of PRUNE_GUARDS) {
    const verdict = guard(template);
    if (verdict && !allowed.has(verdict.module)) {
      allowed.add(verdict.module);
      forceKept.push(verdict);
    }
  }

  const backendRoutes = pruneBackendRoutes(stagingDir, allowed);
  const frontendRouter = pruneFrontendRouter(stagingDir, allowed);
  const orphans = deleteOrphanedSources(stagingDir, allowed);

  return {
    declared,
    forceKept,
    backendRoutes,
    frontendRouter,
    orphans,
  };
}
