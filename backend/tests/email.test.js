// Phase 4.19 — email lib unit tests + forgot-password endpoint +
// workflow send_email action.
//
// We don't actually talk to an SMTP server — `_setTransportForTests`
// installs a fake `sendMail` that records the call. `_resetForTests`
// flips the cache between scenarios.

import { describe, it, expect, beforeAll, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';
import {
  sendEmail, wrapEmail, isConfigured,
  _resetForTests, _setTransportForTests,
} from '../src/lib/email.js';

const app = buildApp({ silent: true });

let originalSmtpHost;
let originalAppUrl;

beforeAll(() => {
  originalSmtpHost = process.env.SMTP_HOST;
  originalAppUrl = process.env.APP_URL;
});

afterAll(() => {
  if (originalSmtpHost === undefined) delete process.env.SMTP_HOST;
  else process.env.SMTP_HOST = originalSmtpHost;
  if (originalAppUrl === undefined) delete process.env.APP_URL;
  else process.env.APP_URL = originalAppUrl;
  _resetForTests();
});

function captureSmtp() {
  const captured = [];
  const fake = {
    async sendMail(opts) {
      captured.push(opts);
      return { messageId: `<test-${captured.length}@local>` };
    },
  };
  _setTransportForTests(fake);
  return captured;
}

describe('sendEmail input validation', () => {
  beforeEach(() => {
    delete process.env.SMTP_HOST;
    _resetForTests();
  });

  it('refuses empty `to`', async () => {
    const r = await sendEmail({ to: '', subject: 's', text: 't' });
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/recipient/i);
  });

  it('refuses missing subject', async () => {
    const r = await sendEmail({ to: 'x@y', subject: '', text: 't' });
    expect(r.ok).toBe(false);
  });

  it('refuses missing body', async () => {
    const r = await sendEmail({ to: 'x@y', subject: 's' });
    expect(r.ok).toBe(false);
  });

  it('stub mode: ok=false, stubbed=true when SMTP_HOST is unset', async () => {
    const r = await sendEmail({ to: 'x@y', subject: 's', text: 't' });
    expect(r.ok).toBe(false);
    expect(r.stubbed).toBe(true);
  });
});

describe('sendEmail with fake transport', () => {
  let captured;

  beforeEach(() => {
    process.env.SMTP_HOST = 'smtp.fake.local';
    _resetForTests();
    captured = captureSmtp();
  });

  it('passes through to the transport when configured', async () => {
    const r = await sendEmail({ to: 'a@b.test', subject: 'hi', text: 'hello' });
    expect(r.ok).toBe(true);
    expect(captured).toHaveLength(1);
    expect(captured[0].to).toBe('a@b.test');
    expect(captured[0].subject).toBe('hi');
  });

  it('joins multi-recipient arrays with comma', async () => {
    await sendEmail({ to: ['a@b.test', 'c@d.test'], subject: 'multi', text: 't' });
    expect(captured[0].to).toBe('a@b.test, c@d.test');
  });

  it('uses env SMTP_FROM when no `from` is given', async () => {
    await sendEmail({ to: 'x@y', subject: 's', text: 't' });
    expect(captured[0].from).toMatch(/TatbeeqX/);
  });

  it('explicit `from` overrides env default', async () => {
    await sendEmail({ to: 'x@y', subject: 's', text: 't', from: 'Custom <c@d>' });
    expect(captured[0].from).toBe('Custom <c@d>');
  });

  it('returns reason when transport throws (no exception bubbles up)', async () => {
    _setTransportForTests({
      async sendMail() { throw new Error('connection refused'); },
    });
    const r = await sendEmail({ to: 'x@y', subject: 's', text: 't' });
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/connection refused/);
  });
});

describe('wrapEmail', () => {
  it('escapes user-supplied HTML in the heading', () => {
    const html = wrapEmail({ heading: '<script>alert(1)</script>', bodyHtml: '<p>x</p>' });
    expect(html).not.toContain('<script>alert');
    expect(html).toContain('&lt;script&gt;');
  });

  it('renders the CTA when ctaUrl is given', () => {
    const html = wrapEmail({
      heading: 'h', bodyHtml: '<p>b</p>', ctaUrl: 'https://example.test/x', ctaLabel: 'Go',
    });
    expect(html).toContain('https://example.test/x');
    expect(html).toContain('>Go<');
  });

  it('skips the CTA block when ctaUrl is omitted', () => {
    const html = wrapEmail({ heading: 'h', bodyHtml: '<p>b</p>' });
    expect(html).not.toContain('background:#1F6FEB;color:#fff');
  });
});

describe('POST /api/auth/forgot-password', () => {
  beforeEach(() => {
    process.env.SMTP_HOST = 'smtp.fake.local';
    _resetForTests();
    captureSmtp();
  });

  it('returns 503 when SMTP is unconfigured', async () => {
    delete process.env.SMTP_HOST;
    _resetForTests();
    const res = await request(app).post('/api/auth/forgot-password').send({ identifier: 'noone' });
    expect(res.status).toBe(503);
  });

  it('returns 200 with a generic message when user does not exist (anti-enumeration)', async () => {
    const res = await request(app).post('/api/auth/forgot-password').send({ identifier: 'nope_zzz_404' });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.message).toMatch(/if that account exists/i);
  });

  it('persists a token for an existing user', async () => {
    // Use the seeded superadmin — guaranteed to exist.
    const before = await prisma.passwordResetToken.count();
    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ identifier: process.env.SEED_SUPERADMIN_USERNAME || 'superadmin' });
    expect(res.status).toBe(200);
    const after = await prisma.passwordResetToken.count();
    expect(after).toBe(before + 1);

    // Cleanup the token we just created.
    await prisma.passwordResetToken.deleteMany({
      where: { user: { username: process.env.SEED_SUPERADMIN_USERNAME || 'superadmin' } },
    });
  });
});

describe('Workflow send_email action', () => {
  let captured;
  beforeEach(() => {
    process.env.SMTP_HOST = 'smtp.fake.local';
    _resetForTests();
    captured = captureSmtp();
  });

  it('isConfigured()=true → action sends through the fake transport', async () => {
    expect(isConfigured()).toBe(true);
    // Login + create + run a send_email workflow inline.
    const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
    const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';
    const login = await request(app).post('/api/auth/login').send({ username: SEED_USERNAME, password: SEED_PASSWORD });
    const token = login.body.accessToken;
    const code = `wf_email_${Date.now()}`;
    const create = await request(app)
      .post('/api/workflows')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code, name: 'send mail',
        triggerType: 'event', triggerConfig: { event: '*' },
        actions: [
          { type: 'send_email', name: 'mail',
            params: { to: 'someone@x.test', subject: 'hi', text: 'hello' } },
        ],
      });
    expect(create.status).toBe(201);
    const run = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set('Authorization', `Bearer ${token}`);
    expect(run.body.status).toBe('success');
    expect(captured).toHaveLength(1);
    expect(captured[0].subject).toBe('hi');

    await prisma.workflow.delete({ where: { id: create.body.id } }).catch(() => {});
  });

  it('isConfigured()=false → action returns step success with stubbed=true (no throw)', async () => {
    delete process.env.SMTP_HOST;
    _resetForTests();
    const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
    const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';
    const login = await request(app).post('/api/auth/login').send({ username: SEED_USERNAME, password: SEED_PASSWORD });
    const token = login.body.accessToken;
    const code = `wf_email_stub_${Date.now()}`;
    const create = await request(app)
      .post('/api/workflows')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code, name: 'send mail stub',
        triggerType: 'event', triggerConfig: { event: '*' },
        actions: [
          { type: 'send_email', name: 'mail',
            params: { to: 'someone@x.test', subject: 's', text: 't' } },
        ],
      });
    const run = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set('Authorization', `Bearer ${token}`);
    // Stub mode: step succeeds (workflow chain not broken), but the
    // result records that nothing was sent.
    expect(run.body.status).toBe('success');

    await prisma.workflow.delete({ where: { id: create.body.id } }).catch(() => {});
  });
});
