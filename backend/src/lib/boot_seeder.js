// Phase 4.12 — first-boot seeder for subsystem builds.
//
// When `BOOT_SEED_PATH` is set in the environment (typically by the
// `tools/build-subsystem/` build script, which writes the path to the
// template JSON it bundled into the binary), the backend applies that
// template once on first boot. The marker is the same
// `system.subsystem_info` settings row that `applyTemplateData` writes
// — its presence means a template has already been applied.
//
// Idempotent: if the marker exists, this is a no-op. So it's safe to
// leave `BOOT_SEED_PATH` set across restarts.

import fs from 'node:fs';
import { prisma } from './prisma.js';
import { applyTemplateData } from './templates.js';
import { logSystem } from './system_log.js';
import { isLockdown } from './subsystem.js';

const SUBSYSTEM_KEY = 'system.subsystem_info';

export async function bootSeedIfNeeded() {
  const path = process.env.BOOT_SEED_PATH;
  if (!path) return { ran: false, reason: 'BOOT_SEED_PATH not set' };
  if (!fs.existsSync(path)) {
    await logSystem('warn', 'boot_seed', `BOOT_SEED_PATH points to missing file: ${path}`).catch(() => {});
    return { ran: false, reason: `seed file missing: ${path}` };
  }

  // Already seeded? The subsystem_info row is the marker — written by
  // applyTemplateData when the template carries `modules` or `branding`.
  // Templates without those fields don't leave a marker; we use a
  // separate setting key (`system.boot_seed_applied`) as a fallback so
  // we never re-apply on restart.
  const subsysRow = await prisma.setting.findFirst({
    where: { companyId: null, key: SUBSYSTEM_KEY },
  }).catch(() => null);
  const markerRow = await prisma.setting.findFirst({
    where: { companyId: null, key: 'system.boot_seed_applied' },
  }).catch(() => null);
  if (subsysRow || markerRow) {
    return { ran: false, reason: 'already seeded (marker present)' };
  }

  let raw;
  try {
    raw = fs.readFileSync(path, 'utf8');
  } catch (err) {
    await logSystem('error', 'boot_seed', `Could not read ${path}: ${err.message}`).catch(() => {});
    return { ran: false, reason: `read error: ${err.message}` };
  }

  let data;
  try {
    data = JSON.parse(raw);
  } catch (err) {
    await logSystem('error', 'boot_seed', `Invalid JSON in ${path}: ${err.message}`).catch(() => {});
    return { ran: false, reason: `parse error: ${err.message}` };
  }

  try {
    const summary = await applyTemplateData(data);
    // Phase 4.13 — handover the admin user. When the template carries a
    // `lockdownAdmin` block (baked by `tools/build-subsystem`'s
    // `--admin-password` flag), the customer-side handover sequence
    // runs on the very first boot:
    //   1. Disable the seeded `superadmin` user.
    //   2. Upsert the customer's Company Admin with the bcrypt hash
    //      computed by the CLI (no plaintext lands on disk).
    //   3. Assign the `company_admin` role.
    // Only when SUBSYSTEM_LOCKDOWN=1 — applying a captured template via
    // the API in a non-locked install must not silently disable the
    // operator's super-admin.
    if (isLockdown() && data.lockdownAdmin && typeof data.lockdownAdmin === 'object') {
      summary.adminHandover = await applyLockdownAdmin(data.lockdownAdmin);
    }
    // Always plant the marker, even if the template had no subsystem
    // metadata, so we don't re-apply on the next boot.
    await prisma.setting.upsert({
      where: { id: markerRow?.id ?? -1 },
      update: { value: new Date().toISOString() },
      create: {
        companyId: null,
        key: 'system.boot_seed_applied',
        value: new Date().toISOString(),
        type: 'string',
      },
    }).catch(async () => {
      // upsert with id=-1 fails when no row exists; fall back to create
      await prisma.setting.create({
        data: {
          companyId: null,
          key: 'system.boot_seed_applied',
          value: new Date().toISOString(),
          type: 'string',
        },
      });
    });
    await logSystem('info', 'boot_seed', 'Subsystem template applied at first boot', {
      path,
      summary,
    }).catch(() => {});
    return { ran: true, summary };
  } catch (err) {
    await logSystem('error', 'boot_seed', `Apply failed: ${err.message}`).catch(() => {});
    return { ran: false, reason: `apply error: ${err.message}` };
  }
}

async function applyLockdownAdmin(spec) {
  const { username, fullName, email, passwordHash } = spec;
  if (!username || !passwordHash) {
    throw new Error('lockdownAdmin requires both username and passwordHash');
  }

  // Disable the default super-admin account.
  let superadminDisabled = false;
  const seededSuper = await prisma.user.findUnique({ where: { username: 'superadmin' } });
  if (seededSuper && seededSuper.isActive) {
    await prisma.user.update({
      where: { id: seededSuper.id },
      data: { isActive: false },
    });
    superadminDisabled = true;
  }

  // Upsert the customer's Company Admin.
  const existing = await prisma.user.findUnique({ where: { username } });
  let admin;
  if (existing) {
    admin = await prisma.user.update({
      where: { id: existing.id },
      data: {
        passwordHash,
        fullName: fullName || existing.fullName,
        email: email || existing.email,
        isActive: true,
        isSuperAdmin: false,
      },
    });
  } else {
    admin = await prisma.user.create({
      data: {
        username,
        email: email || `${username}@subsystem.local`,
        fullName: fullName || 'Administrator',
        passwordHash,
        isActive: true,
        isSuperAdmin: false,
      },
    });
  }

  // Grant company_admin role (idempotent).
  const role = await prisma.role.findUnique({ where: { code: 'company_admin' } });
  let roleGranted = false;
  if (role) {
    const existingAssignment = await prisma.userRole.findFirst({
      where: { userId: admin.id, roleId: role.id },
    });
    if (!existingAssignment) {
      await prisma.userRole.create({ data: { userId: admin.id, roleId: role.id } });
      roleGranted = true;
    }
  }

  return {
    superadminDisabled,
    adminUsername: username,
    adminId: admin.id,
    roleGranted,
  };
}
