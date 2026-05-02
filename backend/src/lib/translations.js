// Phase 4.10 — read/write the frontend's ARB files from the API.
//
// The ARBs live at `<repo>/frontend/lib/l10n/app_<locale>.arb`. This
// helper exists so a Super Admin can edit translations from the running
// TatbeeqX UI without SSHing to the host.
//
// Caveat: changes to ARB files only take effect after `flutter gen-l10n`
// runs and the desktop binary is rebuilt + redistributed. The endpoint
// makes the round-trip easier; it does NOT regenerate the Dart code.

import fs from 'node:fs';
import path from 'node:path';

const SUPPORTED_LOCALES = ['en', 'ar', 'fr'];
const LOCALE_RE = /^[a-z]{2}(?:_[A-Z]{2})?$/;

export function getL10nDir(cwd = process.cwd()) {
  // backend cwd is `<repo>/backend` when run via npm; frontend ARBs
  // live at `<repo>/frontend/lib/l10n/`.
  return path.resolve(cwd, '..', 'frontend', 'lib', 'l10n');
}

export function listLocales() {
  const dir = getL10nDir();
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const f of fs.readdirSync(dir)) {
    const m = f.match(/^app_([a-z]{2}(?:_[A-Z]{2})?)\.arb$/);
    if (!m) continue;
    const code = m[1];
    const full = path.join(dir, f);
    const st = fs.statSync(full);
    let keyCount = 0;
    try {
      const data = JSON.parse(fs.readFileSync(full, 'utf8'));
      keyCount = Object.keys(data).filter((k) => !k.startsWith('@')).length;
    } catch (_) { /* corrupted file — surface elsewhere */ }
    out.push({
      locale: code,
      file: f,
      size: st.size,
      keyCount,
      updatedAt: st.mtime.toISOString(),
      isSupported: SUPPORTED_LOCALES.includes(code),
    });
  }
  return out.sort((a, b) => a.locale.localeCompare(b.locale));
}

export function readLocale(locale) {
  if (!LOCALE_RE.test(locale)) {
    const err = new Error(`Invalid locale: ${locale}`);
    err.status = 400;
    throw err;
  }
  const file = path.join(getL10nDir(), `app_${locale}.arb`);
  if (!fs.existsSync(file)) {
    const err = new Error(`Locale not found: ${locale}`);
    err.status = 404;
    throw err;
  }
  const raw = fs.readFileSync(file, 'utf8');
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    const err = new Error(`ARB is not valid JSON: ${e.message}`);
    err.status = 500;
    throw err;
  }
  return { locale, file: `app_${locale}.arb`, data: parsed };
}

export function writeLocale(locale, data) {
  if (!LOCALE_RE.test(locale)) {
    const err = new Error(`Invalid locale: ${locale}`);
    err.status = 400;
    throw err;
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    const err = new Error('data must be an ARB JSON object');
    err.status = 400;
    throw err;
  }
  // ARB convention: `@@locale` first, then key/value pairs. Strip any
  // submitted `@@locale` and stamp our own so authors can't accidentally
  // write a mismatched marker.
  const cleaned = Object.fromEntries(
    Object.entries(data).filter(([k]) => k !== '@@locale'),
  );
  const out = { '@@locale': locale, ...cleaned };
  const dir = getL10nDir();
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `app_${locale}.arb`);
  // Backup the previous version next to the file so accidental overwrites
  // are recoverable.
  if (fs.existsSync(file)) {
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    fs.copyFileSync(file, path.join(dir, `app_${locale}.arb.bak-${stamp}`));
  }
  fs.writeFileSync(file, JSON.stringify(out, null, 2) + '\n', 'utf8');
  const st = fs.statSync(file);
  return { locale, file: `app_${locale}.arb`, size: st.size, updatedAt: st.mtime.toISOString() };
}
