// Phase 4.12 — locked-down subsystem builds.
//
// When `SUBSYSTEM_LOCKDOWN=1` is set in the environment (typically by the
// `tools/build-subsystem/` build script, baked into a customer-shipped
// .env), the backend signals to the frontend that this is a customer
// install: super-admin surfaces should be hidden from the UI, the
// sidebar should show only the modules the template declared, and the
// branding overrides should apply.
//
// Lockdown is **organizational**, not adversarial. The vendor's
// super-admin still has full access (for support); the lockdown stops
// the customer from seeing surfaces they shouldn't be using. Backend
// permission checks (`requireSuperAdmin`, `requirePermission`) continue
// to enforce access — this lib just adds a metadata channel for the
// frontend.
//
// Design note: the `modules` + `branding` payload is read from a
// `subsystem_info` settings row on each request, so re-applying a
// template (even at runtime) updates the customer-facing identity
// without restart.

import { prisma } from './prisma.js';

const SUBSYSTEM_INFO_KEY = 'system.subsystem_info';

export function isLockdown() {
  return process.env.SUBSYSTEM_LOCKDOWN === '1';
}

// Default modules array — when a customer install hasn't applied a
// template yet, what should the sidebar show? We surface the core
// permissioned modules (every install needs these) and let the
// template's `modules` array EXTEND, not REPLACE, the core set.
const CORE_MODULES = [
  'dashboard',
  'users',
  'roles',
  'companies',
  'branches',
  'audit',
  'settings',
  'reports',
  'backups',
];

// Modules that are super-admin-only and should be hidden from the
// sidebar in lockdown mode — even if a vendor super-admin is logged in
// (the sidebar can be cluttered for support purposes; the surfaces are
// still reachable by typing the URL or via `/api/...`).
const HIDDEN_IN_LOCKDOWN = new Set([
  'system',
  'system-logs',
  'database',
  'custom-entities',
  'templates',
  'pages',
  'translations',
  'themes',
]);

function readBrandingFromSetting(value) {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value);
    if (parsed && typeof parsed === 'object') return parsed;
  } catch (_) { /* fall through */ }
  return null;
}

// Returns the public subsystem info — safe to expose without auth so
// the frontend can fetch it before the user logs in (used to brand the
// login screen and decide which routes to register).
export async function getSubsystemInfo() {
  const lockdown = isLockdown();
  let modules = CORE_MODULES;
  let branding = null;

  try {
    const setting = await prisma.setting.findFirst({
      where: { companyId: null, key: SUBSYSTEM_INFO_KEY },
    });
    if (setting?.value) {
      const parsed = readBrandingFromSetting(setting.value);
      if (parsed) {
        if (Array.isArray(parsed.modules)) {
          // Template declares modules; merge with core so navigation
          // basics always work.
          modules = Array.from(new Set([...CORE_MODULES, ...parsed.modules.filter((m) => typeof m === 'string')]));
        }
        if (parsed.branding && typeof parsed.branding === 'object') {
          branding = parsed.branding;
        }
      }
    }
  } catch (_) { /* settings table missing on first boot — fine */ }

  // In lockdown, strip super-admin-only modules from the visible set.
  if (lockdown) {
    modules = modules.filter((m) => !HIDDEN_IN_LOCKDOWN.has(m));
  }

  return {
    lockdown,
    modules,
    branding,
    // Surfaces hidden in lockdown — the frontend uses this list to
    // suppress route registration AND for the sidebar filter. Returned
    // explicitly (not implicit) so the frontend logic mirrors the
    // backend's idea of what's locked.
    hiddenModules: lockdown ? Array.from(HIDDEN_IN_LOCKDOWN) : [],
  };
}

// Persist the subsystem info — used by the template-apply pipeline
// (Phase 4.12 commit 2) to record which modules + branding the active
// template declares. Survives restart by living in the `settings` table.
export async function setSubsystemInfo({ modules, branding }) {
  const payload = JSON.stringify({
    modules: Array.isArray(modules) ? modules : [],
    branding: branding && typeof branding === 'object' ? branding : null,
  });
  const existing = await prisma.setting.findFirst({
    where: { companyId: null, key: SUBSYSTEM_INFO_KEY },
  });
  if (existing) {
    await prisma.setting.update({
      where: { id: existing.id },
      data: { value: payload },
    });
  } else {
    await prisma.setting.create({
      data: { companyId: null, key: SUBSYSTEM_INFO_KEY, value: payload, type: 'json' },
    });
  }
}

// Defensive middleware. Most routes already gate on `requireSuperAdmin`
// which keeps customers out (they can't be super-admin in lockdown
// builds — see Phase 4.12 plan). This middleware exists for routes
// where we want to forbid even vendor support from poking at customer
// installs (none today, but keeps the pattern available for future
// tightening).
export function requireNotLockdown() {
  return (_req, res, next) => {
    if (isLockdown()) {
      return res.status(403).json({ error: { message: 'This surface is disabled in subsystem builds.' } });
    }
    next();
  };
}
