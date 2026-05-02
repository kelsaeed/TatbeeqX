// Phase 4.19 — outbound email via SMTP (Nodemailer).
//
// Vendor-neutral: any SMTP server works (SendGrid relay, SES, Postmark,
// Postfix, Gmail). Set SMTP_* env vars to enable; without them, the
// lib stays in "stub mode" and the rest of the system continues
// working — non-critical callers (workflow send_email, approval
// notifications) get a graceful no-op + a SystemLog warning, while
// critical callers (forgot-password) check `isConfigured()` first
// and refuse the action with a clear error.
//
// Stub mode behavior:
//   - dev (NODE_ENV != 'production'): pretty-print the message to
//     stdout so devs can iterate without an SMTP server
//   - prod: silent no-op + a single SystemLog warning per process
//     boot (no log spam)
//
// `sendEmail` ALWAYS resolves; it never throws. Critical callers
// inspect the returned `{ ok, reason }` rather than try/catch.

import { isProd } from '../config/env.js';
import { logSystem } from './system_log.js';

let _transport = null;
let _stubWarnedInProd = false;

// Read the SMTP block fresh each call. The env module caches once at
// load time which is fine for production but blocks tests from
// flipping the configuration mid-suite.
function smtpEnv() {
  return {
    host: process.env.SMTP_HOST || null,
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || 'false').toLowerCase() === 'true',
    user: process.env.SMTP_USER || null,
    pass: process.env.SMTP_PASS || null,
    from: process.env.SMTP_FROM || 'TatbeeqX <no-reply@localhost>',
  };
}

export function isConfigured() {
  return Boolean(smtpEnv().host);
}

async function getTransport() {
  if (_transport) return _transport;
  if (!isConfigured()) return null;
  const cfg = smtpEnv();
  // Late import — nodemailer has a non-trivial startup cost we'd
  // rather not pay on boot when the install never sends mail.
  const { default: nodemailer } = await import('nodemailer');
  _transport = nodemailer.createTransport({
    host: cfg.host,
    port: cfg.port,
    secure: cfg.secure,  // true for 465, false for 587/STARTTLS
    auth: cfg.user ? { user: cfg.user, pass: cfg.pass } : undefined,
  });
  return _transport;
}

function logStubOnce() {
  if (isProd && !_stubWarnedInProd) {
    _stubWarnedInProd = true;
    logSystem('warn', 'email', 'SMTP not configured — email features will no-op until SMTP_HOST is set').catch(() => {});
  }
}

function consoleStub({ to, subject, text, html }) {
  // Dev convenience — visible in `npm run dev` output.
  // eslint-disable-next-line no-console
  console.log('\n' + '='.repeat(60));
  console.log('[email stub] would send:');
  console.log(`  to:      ${Array.isArray(to) ? to.join(', ') : to}`);
  console.log(`  subject: ${subject}`);
  if (text) console.log('  text:\n' + text.split('\n').map((l) => '    ' + l).join('\n'));
  if (html && !text) console.log('  html: (' + html.length + ' chars)');
  console.log('='.repeat(60) + '\n');
}

// `to` is a string or an array of strings. `text` and `html` are both
// optional but at least one must be present. `from` defaults to env.
export async function sendEmail({ to, subject, text, html, from } = {}) {
  if (!to || (Array.isArray(to) && to.length === 0)) {
    return { ok: false, reason: 'no recipients' };
  }
  if (!subject || typeof subject !== 'string') {
    return { ok: false, reason: 'subject required' };
  }
  if (!text && !html) {
    return { ok: false, reason: 'text or html required' };
  }

  const transport = await getTransport();
  if (!transport) {
    if (!isProd) consoleStub({ to, subject, text, html });
    logStubOnce();
    return { ok: false, reason: 'smtp not configured', stubbed: true };
  }

  try {
    const info = await transport.sendMail({
      from: from || smtpEnv().from,
      to: Array.isArray(to) ? to.join(', ') : to,
      subject,
      text,
      html,
    });
    return { ok: true, messageId: info.messageId };
  } catch (err) {
    await logSystem('error', 'email', 'sendEmail failed', {
      to: Array.isArray(to) ? to : [to],
      subject,
      error: String(err?.message || err),
    }).catch(() => {});
    return { ok: false, reason: String(err?.message || err) };
  }
}

// Tiny HTML wrapper so per-flow templates stay short. Keep it inline-
// styled — many email clients drop <style> blocks. Shared brand bar at
// the top, gentle footer at the bottom.
export function wrapEmail({ heading, bodyHtml, ctaUrl, ctaLabel }) {
  const cta = ctaUrl
    ? `<p style="text-align:center;margin:24px 0;">
         <a href="${escapeHtml(ctaUrl)}" style="background:#1F6FEB;color:#fff;padding:12px 22px;border-radius:8px;text-decoration:none;font-weight:600;display:inline-block;">${escapeHtml(ctaLabel || 'Open')}</a>
       </p>
       <p style="font-size:12px;color:#64748b;text-align:center;">If the button doesn't work, paste this URL into your browser:<br><span style="word-break:break-all;color:#0f172a;">${escapeHtml(ctaUrl)}</span></p>`
    : '';
  return `<!doctype html>
<html><body style="margin:0;padding:0;background:#f4f6fa;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0f172a;">
  <div style="max-width:560px;margin:32px auto;background:#fff;border-radius:12px;overflow:hidden;border:1px solid #e2e8f0;">
    <div style="padding:20px 28px;background:#0F172A;color:#fff;">
      <strong>TatbeeqX</strong>
    </div>
    <div style="padding:24px 28px;">
      <h2 style="margin:0 0 16px 0;font-size:18px;">${escapeHtml(heading)}</h2>
      ${bodyHtml}
      ${cta}
    </div>
    <div style="padding:14px 28px;background:#f8fafc;font-size:11px;color:#64748b;border-top:1px solid #e2e8f0;">
      Sent automatically by TatbeeqX. Do not reply.
    </div>
  </div>
</body></html>`;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Test seam — reset cached transport. Used by the email test suite to
// re-evaluate isConfigured() between tests with different env.
export function _resetForTests() {
  _transport = null;
  _stubWarnedInProd = false;
}

// Test seam — install a fake transport object with a `sendMail`
// method, bypassing nodemailer entirely. The fake should resolve with
// `{ messageId }` (or throw) like nodemailer's real return. Use in
// pair with setting SMTP_HOST so isConfigured() returns true.
export function _setTransportForTests(fake) {
  _transport = fake;
}
