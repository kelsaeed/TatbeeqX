// Phase 4.15 — Templates UI for branding + modules editing.
//
// Covers PUT /api/templates/:id/subsystem — operators can edit a captured
// `full` or `business` template's subsystem block (branding + modules)
// without hand-editing the JSON via Copy → re-import. Pre-existing capture/
// apply/delete paths are exercised in routes_features and elsewhere.

import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';

let token;
const auth = () => ({ Authorization: `Bearer ${token}` });

beforeAll(async () => {
  const res = await request(app)
    .post('/api/auth/login')
    .send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (res.status !== 200) throw new Error(`login failed: ${res.status}`);
  token = res.body.accessToken;
});

async function makeTemplate({ kind = 'full', initialData = {} } = {}) {
  return prisma.systemTemplate.create({
    data: {
      code: `t_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      name: 'subsystem-edit-fixture',
      kind,
      data: JSON.stringify({ kind, version: 3, ...initialData }),
    },
  });
}

const cleanup = [];
afterEach(async () => {
  while (cleanup.length) {
    const id = cleanup.pop();
    await prisma.systemTemplate.delete({ where: { id } }).catch(() => {});
  }
});

describe('GET /api/templates — subsystem summary', () => {
  it('exposes hasBranding/moduleCount/appName per item without a second round-trip', async () => {
    const t = await prisma.systemTemplate.create({
      data: {
        code: `t_summary_${Date.now()}`,
        name: 'subsystem-summary-fixture',
        kind: 'full',
        data: JSON.stringify({
          kind: 'full', version: 3,
          branding: { appName: 'Factory ABC', primaryColor: '#1f6feb' },
          modules: ['custom:products', 'custom:work_orders'],
        }),
      },
    });
    cleanup.push(t.id);

    const res = await request(app).get('/api/templates').set(auth());
    expect(res.status).toBe(200);
    const found = res.body.items.find((i) => i.id === t.id);
    expect(found).toBeDefined();
    expect(found.subsystem).toBeDefined();
    expect(found.subsystem.hasBranding).toBe(true);
    expect(found.subsystem.appName).toBe('Factory ABC');
    expect(found.subsystem.moduleCount).toBe(2);
    expect(found.subsystem.modules).toEqual(['custom:products', 'custom:work_orders']);
  });

  it('returns hasBranding=false / moduleCount=0 for templates with no subsystem block', async () => {
    const t = await prisma.systemTemplate.create({
      data: {
        code: `t_bare_${Date.now()}`,
        name: 'bare-fixture',
        kind: 'theme',
        data: JSON.stringify({ kind: 'theme', version: 3, theme: { name: 'X' } }),
      },
    });
    cleanup.push(t.id);

    const res = await request(app).get('/api/templates').set(auth());
    const found = res.body.items.find((i) => i.id === t.id);
    expect(found.subsystem).toEqual({ hasBranding: false, moduleCount: 0 });
  });

  it('treats empty-string branding values as not-branded', async () => {
    const t = await prisma.systemTemplate.create({
      data: {
        code: `t_empty_brand_${Date.now()}`,
        name: 'empty-branding-fixture',
        kind: 'full',
        data: JSON.stringify({
          kind: 'full', version: 3,
          branding: { appName: '', logoUrl: '   ' },
          modules: [],
        }),
      },
    });
    cleanup.push(t.id);

    const res = await request(app).get('/api/templates').set(auth());
    const found = res.body.items.find((i) => i.id === t.id);
    expect(found.subsystem.hasBranding).toBe(false);
    expect(found.subsystem.moduleCount).toBe(0);
  });
});

describe('PUT /api/templates/:id/subsystem', () => {
  it('updates branding and modules on a `full` template', async () => {
    const t = await makeTemplate({ kind: 'full' });
    cleanup.push(t.id);

    const res = await request(app)
      .put(`/api/templates/${t.id}/subsystem`)
      .set(auth())
      .send({
        branding: { appName: 'Factory ABC', primaryColor: '#1f6feb' },
        modules: ['custom:products', 'custom:work_orders'],
      });
    expect(res.status).toBe(200);
    expect(res.body.data.branding).toEqual({ appName: 'Factory ABC', primaryColor: '#1f6feb' });
    expect(res.body.data.modules).toEqual(['custom:products', 'custom:work_orders']);

    // Persisted to DB.
    const fresh = await prisma.systemTemplate.findUnique({ where: { id: t.id } });
    const parsed = JSON.parse(fresh.data);
    expect(parsed.branding.appName).toBe('Factory ABC');
    expect(parsed.modules).toEqual(['custom:products', 'custom:work_orders']);
  });

  it('preserves unrelated fields (theme, entities) when editing the subsystem block', async () => {
    const t = await makeTemplate({
      kind: 'full',
      initialData: {
        theme: { name: 'Sunny', data: { primary: '#fab' } },
        entities: [{ code: 'products', label: 'Products' }],
        modules: ['old:thing'],
      },
    });
    cleanup.push(t.id);

    await request(app)
      .put(`/api/templates/${t.id}/subsystem`)
      .set(auth())
      .send({ modules: ['new:thing'] })
      .expect(200);

    const fresh = await prisma.systemTemplate.findUnique({ where: { id: t.id } });
    const parsed = JSON.parse(fresh.data);
    expect(parsed.theme).toEqual({ name: 'Sunny', data: { primary: '#fab' } });
    expect(parsed.entities).toEqual([{ code: 'products', label: 'Products' }]);
    expect(parsed.modules).toEqual(['new:thing']);
  });

  it('strips empty-string branding fields and trims/dedupes module codes', async () => {
    const t = await makeTemplate({ kind: 'full' });
    cleanup.push(t.id);

    const res = await request(app)
      .put(`/api/templates/${t.id}/subsystem`)
      .set(auth())
      .send({
        branding: { appName: 'Keeper', logoUrl: '   ', primaryColor: '' },
        modules: ['custom:a', '  custom:a  ', 'custom:b', '   '],
      });
    expect(res.status).toBe(200);
    expect(res.body.data.branding).toEqual({ appName: 'Keeper' });
    expect(res.body.data.modules).toEqual(['custom:a', 'custom:b']);
  });

  it('removes branding/modules when given empty input', async () => {
    const t = await makeTemplate({
      kind: 'full',
      initialData: { branding: { appName: 'Old' }, modules: ['x', 'y'] },
    });
    cleanup.push(t.id);

    const res = await request(app)
      .put(`/api/templates/${t.id}/subsystem`)
      .set(auth())
      .send({ branding: null, modules: [] });
    expect(res.status).toBe(200);
    expect(res.body.data.branding).toBeUndefined();
    expect(res.body.data.modules).toBeUndefined();
  });

  it('rejects edits on `theme`-only templates (subsystem fields are not part of theme captures)', async () => {
    const t = await makeTemplate({ kind: 'theme' });
    cleanup.push(t.id);

    const res = await request(app)
      .put(`/api/templates/${t.id}/subsystem`)
      .set(auth())
      .send({ modules: ['x'] });
    expect(res.status).toBe(400);
  });

  it('returns 404 when the template does not exist', async () => {
    const res = await request(app)
      .put('/api/templates/999999999/subsystem')
      .set(auth())
      .send({ modules: ['x'] });
    expect(res.status).toBe(404);
  });

  it('rejects malformed payloads (modules not array, branding not object)', async () => {
    const t = await makeTemplate({ kind: 'full' });
    cleanup.push(t.id);

    await request(app)
      .put(`/api/templates/${t.id}/subsystem`)
      .set(auth())
      .send({ modules: 'not-an-array' })
      .expect(400);

    await request(app)
      .put(`/api/templates/${t.id}/subsystem`)
      .set(auth())
      .send({ branding: ['array', 'not', 'object'] })
      .expect(400);
  });
});
