// Phase 4.12 — locked-down subsystem builds.
//
// Verifies the lib/subsystem.js helpers and the public /api/subsystem/info
// endpoint.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';
import {
  isLockdown,
  getSubsystemInfo,
  setSubsystemInfo,
} from '../src/lib/subsystem.js';

const SUBSYSTEM_KEY = 'system.subsystem_info';

async function clearSubsystemSetting() {
  await prisma.setting.deleteMany({
    where: { companyId: null, key: SUBSYSTEM_KEY },
  });
}

describe('isLockdown', () => {
  beforeEach(() => {
    delete process.env.SUBSYSTEM_LOCKDOWN;
  });

  afterEach(() => {
    delete process.env.SUBSYSTEM_LOCKDOWN;
  });

  it('returns false when env var is unset', () => {
    expect(isLockdown()).toBe(false);
  });

  it('returns true only for the literal "1" value', () => {
    process.env.SUBSYSTEM_LOCKDOWN = '1';
    expect(isLockdown()).toBe(true);
    process.env.SUBSYSTEM_LOCKDOWN = 'true';
    expect(isLockdown()).toBe(false); // strict — only "1" enables
    process.env.SUBSYSTEM_LOCKDOWN = '0';
    expect(isLockdown()).toBe(false);
  });
});

describe('getSubsystemInfo', () => {
  beforeEach(async () => {
    delete process.env.SUBSYSTEM_LOCKDOWN;
    await clearSubsystemSetting();
  });

  afterEach(async () => {
    delete process.env.SUBSYSTEM_LOCKDOWN;
    await clearSubsystemSetting();
  });

  it('returns the core module set when no template has been applied', async () => {
    const info = await getSubsystemInfo();
    expect(info.lockdown).toBe(false);
    expect(info.branding).toBeNull();
    // Core modules are always present.
    expect(info.modules).toEqual(expect.arrayContaining(['dashboard', 'users', 'roles', 'audit']));
    // Without lockdown, hiddenModules is empty.
    expect(info.hiddenModules).toEqual([]);
  });

  it('merges template modules with the core set', async () => {
    await setSubsystemInfo({
      modules: ['custom:products', 'custom:work_orders'],
      branding: { appName: 'Factory ABC' },
    });
    const info = await getSubsystemInfo();
    expect(info.modules).toEqual(expect.arrayContaining([
      'dashboard', 'users', 'custom:products', 'custom:work_orders',
    ]));
    expect(info.branding).toEqual({ appName: 'Factory ABC' });
  });

  it('strips hidden modules in lockdown mode', async () => {
    process.env.SUBSYSTEM_LOCKDOWN = '1';
    // Even if a template tries to declare a hidden module, lockdown wins.
    await setSubsystemInfo({
      modules: ['custom:products', 'system', 'database'],
      branding: { appName: 'Factory ABC' },
    });
    const info = await getSubsystemInfo();
    expect(info.lockdown).toBe(true);
    expect(info.modules).toContain('custom:products');
    expect(info.modules).not.toContain('system');
    expect(info.modules).not.toContain('database');
    expect(info.hiddenModules).toEqual(expect.arrayContaining([
      'system', 'system-logs', 'database', 'templates',
    ]));
  });

  it('survives malformed setting JSON without throwing', async () => {
    // Manually plant an invalid value.
    await prisma.setting.create({
      data: { companyId: null, key: SUBSYSTEM_KEY, value: 'not-json', type: 'json' },
    });
    const info = await getSubsystemInfo();
    // Falls back to the core defaults.
    expect(info.modules).toEqual(expect.arrayContaining(['dashboard']));
    expect(info.branding).toBeNull();
  });
});

describe('setSubsystemInfo', () => {
  beforeEach(() => clearSubsystemSetting());
  afterEach(() => clearSubsystemSetting());

  it('creates the row when missing', async () => {
    await setSubsystemInfo({ modules: ['x'], branding: { appName: 'A' } });
    const row = await prisma.setting.findFirst({
      where: { companyId: null, key: SUBSYSTEM_KEY },
    });
    expect(row).not.toBeNull();
    expect(JSON.parse(row.value)).toEqual({
      modules: ['x'],
      branding: { appName: 'A' },
    });
  });

  it('updates the row when present', async () => {
    await setSubsystemInfo({ modules: ['x'], branding: null });
    await setSubsystemInfo({ modules: ['y', 'z'], branding: { appName: 'B' } });
    const row = await prisma.setting.findFirst({
      where: { companyId: null, key: SUBSYSTEM_KEY },
    });
    expect(JSON.parse(row.value).modules).toEqual(['y', 'z']);
    expect(JSON.parse(row.value).branding).toEqual({ appName: 'B' });
  });

  it('coerces invalid input to safe defaults', async () => {
    await setSubsystemInfo({ modules: 'not-an-array', branding: 'not-an-object' });
    const row = await prisma.setting.findFirst({
      where: { companyId: null, key: SUBSYSTEM_KEY },
    });
    expect(JSON.parse(row.value)).toEqual({ modules: [], branding: null });
  });
});

describe('GET /api/subsystem/info', () => {
  let app;

  beforeEach(async () => {
    delete process.env.SUBSYSTEM_LOCKDOWN;
    await clearSubsystemSetting();
    app = buildApp();
  });

  afterEach(async () => {
    delete process.env.SUBSYSTEM_LOCKDOWN;
    await clearSubsystemSetting();
  });

  it('returns 200 without auth', async () => {
    const res = await request(app).get('/api/subsystem/info');
    expect(res.status).toBe(200);
    expect(res.body.lockdown).toBe(false);
    expect(res.body.modules).toEqual(expect.arrayContaining(['dashboard']));
  });

  it('reflects the env var + DB state in the response', async () => {
    process.env.SUBSYSTEM_LOCKDOWN = '1';
    await setSubsystemInfo({
      modules: ['custom:products'],
      branding: { appName: 'Factory ABC', primaryColor: '#1f6feb' },
    });
    const res = await request(app).get('/api/subsystem/info');
    expect(res.status).toBe(200);
    expect(res.body.lockdown).toBe(true);
    expect(res.body.branding).toEqual({ appName: 'Factory ABC', primaryColor: '#1f6feb' });
    expect(res.body.modules).toContain('custom:products');
    expect(res.body.hiddenModules).toContain('system');
  });
});
