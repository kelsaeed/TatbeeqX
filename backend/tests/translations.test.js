// Phase 4.10 — backend ARB read/write helpers.
//
// We test against the live ARB files shipped with the frontend. The test
// is read-mostly: we read each existing ARB, write it back unchanged,
// and verify the on-disk content + sidecar `.bak-*` is created.
//
// The tests run in the isolated test DB harness (Phase 4.8), but the ARB
// files live on the real filesystem under frontend/lib/l10n/. Failures
// here mean someone changed the ARB layout without updating the lib.

import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { listLocales, readLocale, writeLocale, getL10nDir } from '../src/lib/translations.js';

describe('listLocales', () => {
  it('returns the seeded ARB files (en/ar/fr)', () => {
    const items = listLocales();
    const codes = items.map((l) => l.locale);
    expect(codes).toContain('en');
    expect(codes).toContain('ar');
    expect(codes).toContain('fr');
  });

  it('reports key counts and isSupported', () => {
    const en = listLocales().find((l) => l.locale === 'en');
    expect(en).toBeDefined();
    expect(en.keyCount).toBeGreaterThan(10);
    expect(en.isSupported).toBe(true);
  });
});

describe('readLocale', () => {
  it('parses the en ARB and exposes the canonical signIn key', () => {
    const en = readLocale('en');
    expect(en.locale).toBe('en');
    expect(en.data['@@locale']).toBe('en');
    expect(en.data.signIn).toBeTypeOf('string');
  });

  it('rejects an invalid locale code', () => {
    expect(() => readLocale('not-a-locale!')).toThrow(/Invalid locale/);
    expect(() => readLocale('zz')).toThrow(/not found/);
  });
});

describe('writeLocale', () => {
  it('writes a backup before overwriting and stamps @@locale', () => {
    const dir = getL10nDir();
    const original = readLocale('en');

    // Try writing with a deliberately mismatched @@locale; helper should overwrite it.
    const result = writeLocale('en', { ...original.data, '@@locale': 'wrong' });
    expect(result.locale).toBe('en');
    expect(result.file).toBe('app_en.arb');

    const after = readLocale('en');
    expect(after.data['@@locale']).toBe('en'); // helper stamped it back
    expect(after.data.signIn).toBe(original.data.signIn);

    // A backup with the same prefix must exist.
    const baks = fs.readdirSync(dir).filter((f) => f.startsWith('app_en.arb.bak-'));
    expect(baks.length).toBeGreaterThan(0);

    // Cleanup: remove just the new backup. Keep the live file (it's already
    // restored to the same content).
    for (const b of baks) {
      try { fs.unlinkSync(path.join(dir, b)); } catch (_) { /* ignore */ }
    }
  });

  it('rejects bad input', () => {
    expect(() => writeLocale('bad-code!', {})).toThrow(/Invalid locale/);
    expect(() => writeLocale('en', null)).toThrow(/ARB JSON object/);
    expect(() => writeLocale('en', [1, 2])).toThrow(/ARB JSON object/);
  });
});
