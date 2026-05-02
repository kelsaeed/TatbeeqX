// Phase 4.12 — first-boot seeder.
//
// Verifies that `BOOT_SEED_PATH` triggers a one-shot template apply at
// server start, with idempotency across restarts.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { prisma } from '../src/lib/prisma.js';
import { bootSeedIfNeeded } from '../src/lib/boot_seeder.js';

const SUBSYSTEM_KEY = 'system.subsystem_info';
const APPLIED_KEY = 'system.boot_seed_applied';

async function clearMarkers() {
  await prisma.setting.deleteMany({
    where: { companyId: null, key: { in: [SUBSYSTEM_KEY, APPLIED_KEY] } },
  });
}

function tmpSeedFile(content) {
  const p = path.join(os.tmpdir(), `mc-bootseed-${Date.now()}-${Math.random().toString(36).slice(2)}.json`);
  fs.writeFileSync(p, typeof content === 'string' ? content : JSON.stringify(content));
  return p;
}

describe('bootSeedIfNeeded', () => {
  beforeEach(async () => {
    delete process.env.BOOT_SEED_PATH;
    await clearMarkers();
  });

  afterEach(async () => {
    delete process.env.BOOT_SEED_PATH;
    await clearMarkers();
  });

  it('is a no-op when BOOT_SEED_PATH is unset', async () => {
    const result = await bootSeedIfNeeded();
    expect(result.ran).toBe(false);
    expect(result.reason).toMatch(/not set/);
  });

  it('warns and skips when BOOT_SEED_PATH points to a missing file', async () => {
    process.env.BOOT_SEED_PATH = path.join(os.tmpdir(), 'definitely-does-not-exist.json');
    const result = await bootSeedIfNeeded();
    expect(result.ran).toBe(false);
    expect(result.reason).toMatch(/missing/);
  });

  it('applies the template once and writes a marker', async () => {
    const seed = tmpSeedFile({
      kind: 'full',
      version: 3,
      modules: ['custom:products'],
      branding: { appName: 'Factory Test' },
    });
    process.env.BOOT_SEED_PATH = seed;
    try {
      const result = await bootSeedIfNeeded();
      expect(result.ran).toBe(true);
      expect(result.summary.subsystem).toBe(true);

      // Subsystem info row written.
      const subsysRow = await prisma.setting.findFirst({
        where: { companyId: null, key: SUBSYSTEM_KEY },
      });
      expect(subsysRow).not.toBeNull();
      expect(JSON.parse(subsysRow.value).branding).toEqual({ appName: 'Factory Test' });

      // The applied-marker is also written so a template without subsystem
      // metadata still skips re-apply.
      const markerRow = await prisma.setting.findFirst({
        where: { companyId: null, key: APPLIED_KEY },
      });
      expect(markerRow).not.toBeNull();
    } finally {
      try { fs.unlinkSync(seed); } catch (_) { /* best-effort */ }
    }
  });

  it('skips on second invocation (idempotent across restarts)', async () => {
    const seed = tmpSeedFile({
      kind: 'full',
      version: 3,
      modules: ['custom:products'],
    });
    process.env.BOOT_SEED_PATH = seed;
    try {
      const first = await bootSeedIfNeeded();
      expect(first.ran).toBe(true);
      const second = await bootSeedIfNeeded();
      expect(second.ran).toBe(false);
      expect(second.reason).toMatch(/marker/);
    } finally {
      try { fs.unlinkSync(seed); } catch (_) { /* best-effort */ }
    }
  });

  it('reports a parse error for malformed JSON', async () => {
    const seed = tmpSeedFile('this is not valid json {{');
    process.env.BOOT_SEED_PATH = seed;
    try {
      const result = await bootSeedIfNeeded();
      expect(result.ran).toBe(false);
      expect(result.reason).toMatch(/parse error/);
    } finally {
      try { fs.unlinkSync(seed); } catch (_) { /* best-effort */ }
    }
  });
});

// Phase 4.13 — lockdownAdmin handover.
//
// The build-subsystem CLI hashes the customer's admin password with
// bcrypt before writing seed.json. The boot seeder picks up the hash
// on first boot, disables the seeded `superadmin`, creates the Company
// Admin user, and assigns the `company_admin` role.
describe('bootSeedIfNeeded — lockdownAdmin handover', () => {
  let touchedUserIds = [];

  async function snapshotSuperadmin() {
    const su = await prisma.user.findUnique({ where: { username: 'superadmin' } });
    return su ? { id: su.id, isActive: su.isActive } : null;
  }

  async function restoreSuperadmin(snap) {
    if (!snap) return;
    await prisma.user.update({ where: { id: snap.id }, data: { isActive: snap.isActive } });
  }

  beforeEach(async () => {
    delete process.env.BOOT_SEED_PATH;
    delete process.env.SUBSYSTEM_LOCKDOWN;
    await clearMarkers();
    touchedUserIds = [];
  });

  afterEach(async () => {
    delete process.env.BOOT_SEED_PATH;
    delete process.env.SUBSYSTEM_LOCKDOWN;
    await clearMarkers();
    if (touchedUserIds.length > 0) {
      await prisma.userRole.deleteMany({ where: { userId: { in: touchedUserIds } } });
      await prisma.user.deleteMany({ where: { id: { in: touchedUserIds } } });
    }
  });

  it('disables superadmin + creates the admin + grants company_admin in lockdown', async () => {
    process.env.SUBSYSTEM_LOCKDOWN = '1';
    const passwordHash = await bcrypt.hash('TestPwd!2026', 10);
    const username = `factory_${Date.now()}`;
    const seed = tmpSeedFile({
      kind: 'full',
      version: 3,
      lockdownAdmin: { username, fullName: 'Test Admin', email: 'test@example.com', passwordHash },
    });

    const superSnap = await snapshotSuperadmin();
    process.env.BOOT_SEED_PATH = seed;
    try {
      const result = await bootSeedIfNeeded();
      expect(result.ran).toBe(true);
      expect(result.summary.adminHandover).toBeDefined();
      expect(result.summary.adminHandover.superadminDisabled).toBe(true);
      expect(result.summary.adminHandover.adminUsername).toBe(username);
      expect(result.summary.adminHandover.roleGranted).toBe(true);

      const su = await prisma.user.findUnique({ where: { username: 'superadmin' } });
      expect(su.isActive).toBe(false);

      const admin = await prisma.user.findUnique({
        where: { username },
        include: { userRoles: { include: { role: true } } },
      });
      expect(admin).not.toBeNull();
      expect(admin.isSuperAdmin).toBe(false);
      expect(admin.userRoles.some((ur) => ur.role.code === 'company_admin')).toBe(true);
      // Hash survives intact — boot seeder must not re-hash.
      expect(admin.passwordHash).toBe(passwordHash);
      touchedUserIds.push(admin.id);
    } finally {
      try { fs.unlinkSync(seed); } catch (_) { /* best-effort */ }
      await restoreSuperadmin(superSnap);
    }
  });

  it('does NOT touch superadmin when SUBSYSTEM_LOCKDOWN is unset', async () => {
    delete process.env.SUBSYSTEM_LOCKDOWN;
    const passwordHash = await bcrypt.hash('TestPwd!2026', 10);
    const seed = tmpSeedFile({
      kind: 'full',
      version: 3,
      lockdownAdmin: { username: `unused_${Date.now()}`, passwordHash },
    });

    const superSnap = await snapshotSuperadmin();
    process.env.BOOT_SEED_PATH = seed;
    try {
      const result = await bootSeedIfNeeded();
      expect(result.ran).toBe(true);
      expect(result.summary.adminHandover).toBeUndefined();

      const su = await prisma.user.findUnique({ where: { username: 'superadmin' } });
      expect(su.isActive).toBe(superSnap.isActive);
    } finally {
      try { fs.unlinkSync(seed); } catch (_) { /* best-effort */ }
      await restoreSuperadmin(superSnap);
    }
  });

  it('rejects a lockdownAdmin with no passwordHash', async () => {
    process.env.SUBSYSTEM_LOCKDOWN = '1';
    const seed = tmpSeedFile({
      kind: 'full',
      version: 3,
      lockdownAdmin: { username: 'noPassword' },
    });
    process.env.BOOT_SEED_PATH = seed;
    try {
      const result = await bootSeedIfNeeded();
      expect(result.ran).toBe(false);
      expect(result.reason).toMatch(/lockdownAdmin requires/);
    } finally {
      try { fs.unlinkSync(seed); } catch (_) { /* best-effort */ }
    }
  });

  it('updates an existing user instead of duplicating on re-apply', async () => {
    const username = `existing_${Date.now()}`;
    const created = await prisma.user.create({
      data: {
        username,
        email: `${username}@old.example`,
        fullName: 'Old Admin',
        passwordHash: '$2a$10$abcdefghijklmnopqrstuvwxyz',
        isActive: true,
        isSuperAdmin: false,
      },
    });
    touchedUserIds.push(created.id);

    process.env.SUBSYSTEM_LOCKDOWN = '1';
    const passwordHash = await bcrypt.hash('NewPwd!2026', 10);
    const seed = tmpSeedFile({
      kind: 'full',
      version: 3,
      lockdownAdmin: { username, fullName: 'New Admin', passwordHash },
    });

    const superSnap = await snapshotSuperadmin();
    process.env.BOOT_SEED_PATH = seed;
    try {
      const result = await bootSeedIfNeeded();
      expect(result.ran).toBe(true);
      expect(result.summary.adminHandover.adminId).toBe(created.id);

      const updated = await prisma.user.findUnique({ where: { id: created.id } });
      expect(updated.passwordHash).toBe(passwordHash);
      expect(updated.fullName).toBe('New Admin');
    } finally {
      try { fs.unlinkSync(seed); } catch (_) { /* best-effort */ }
      await restoreSuperadmin(superSnap);
    }
  });
});
