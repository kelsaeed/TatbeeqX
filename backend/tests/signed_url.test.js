// Phase 4.10 — signed-URL helpers for cross-host backup download.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import crypto from 'node:crypto';
import {
  isDownloadSigningEnabled,
  signDownloadUrl,
  verifyDownloadSignature,
} from '../src/lib/backup.js';

// Mirror of the on-disk format for tests that need to construct
// signatures the helper won't produce (e.g. past expiries).
function manualSign(name, expires) {
  const payload = `${name}.${expires}`;
  return crypto.createHmac('sha256', process.env.BACKUP_DOWNLOAD_SECRET).update(payload).digest('hex');
}

const SECRET = 'a'.repeat(32);

describe('signed download URLs', () => {
  beforeEach(() => {
    process.env.BACKUP_DOWNLOAD_SECRET = SECRET;
  });
  afterEach(() => {
    delete process.env.BACKUP_DOWNLOAD_SECRET;
  });

  it('isDownloadSigningEnabled requires a 16+ char secret', () => {
    expect(isDownloadSigningEnabled()).toBe(true);
    process.env.BACKUP_DOWNLOAD_SECRET = 'short';
    expect(isDownloadSigningEnabled()).toBe(false);
    delete process.env.BACKUP_DOWNLOAD_SECRET;
    expect(isDownloadSigningEnabled()).toBe(false);
  });

  it('signDownloadUrl returns null when signing disabled', () => {
    delete process.env.BACKUP_DOWNLOAD_SECRET;
    expect(signDownloadUrl('any.db', 'https://example.com')).toBeNull();
  });

  it('signed URL roundtrips: parses and verifies', () => {
    const url = signDownloadUrl('dev-2026-05-01.db.enc', 'https://api.example.com');
    expect(url).toContain('https://api.example.com/api/admin/backups/');
    expect(url).toContain('expires=');
    expect(url).toContain('sig=');
    const u = new URL(url);
    const expires = u.searchParams.get('expires');
    const sig = u.searchParams.get('sig');
    expect(verifyDownloadSignature('dev-2026-05-01.db.enc', expires, sig)).toBe(true);
  });

  it('rejects expired signatures', () => {
    const expires = Math.floor(Date.now() / 1000) - 60; // 60s in the past
    const sig = manualSign('a.db', expires);
    expect(verifyDownloadSignature('a.db', String(expires), sig)).toBe(false);
  });

  it('rejects mismatched name', () => {
    const url = signDownloadUrl('legit.db', 'https://x');
    const u = new URL(url);
    const expires = u.searchParams.get('expires');
    const sig = u.searchParams.get('sig');
    expect(verifyDownloadSignature('attacker-renamed.db', expires, sig)).toBe(false);
  });

  it('rejects tampered signature', () => {
    const url = signDownloadUrl('a.db', 'https://x');
    const u = new URL(url);
    const expires = u.searchParams.get('expires');
    const sig = u.searchParams.get('sig');
    const flipped = sig.replace(/^./, (c) => c === 'a' ? 'b' : 'a');
    expect(verifyDownloadSignature('a.db', expires, flipped)).toBe(false);
  });

  it('rejects when signing disabled at verify time', () => {
    const url = signDownloadUrl('a.db', 'https://x');
    const u = new URL(url);
    const expires = u.searchParams.get('expires');
    const sig = u.searchParams.get('sig');
    delete process.env.BACKUP_DOWNLOAD_SECRET;
    expect(verifyDownloadSignature('a.db', expires, sig)).toBe(false);
  });
});
