// Phase 4.16 follow-up — TOTP 2FA helpers.
//
// Wraps the `otpauth` package + an AES-256-GCM encryption layer so
// secrets are never stored plaintext at rest. Recovery codes are
// generated alongside the secret and stored as sha256 hashes.

import crypto from 'node:crypto';
import * as OTPAuth from 'otpauth';
import qrcode from 'qrcode';

import { env } from '../config/env.js';

const TOTP_DIGITS = 6;
const TOTP_PERIOD = 30; // seconds
const TOTP_ALGO = 'SHA1'; // matches every authenticator app's default
const SECRET_BYTES = 20; // 160 bits — RFC 6238 recommendation
const RECOVERY_CODE_COUNT = 10;
const RECOVERY_CODE_BYTES = 5; // 10 hex chars (40 bits) per code

// ---------- secret encryption -------------------------------------------

// Derive a 32-byte AES-256-GCM key from JWT_ACCESS_SECRET via HKDF.
// Tying the key to an existing required env var means TOTP secrets
// survive process restarts without operators having to wire up
// another secret. Key rotation: change JWT_ACCESS_SECRET and all
// stored TOTP secrets become unrecoverable, which is the right
// failure mode for a compromised key.
function totpKey() {
  return crypto.hkdfSync('sha256', env.jwtAccessSecret, Buffer.from('tatbeeqx-totp'), Buffer.from('totp-secret-v1'), 32);
}

export function encryptSecret(base32Secret) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', Buffer.from(totpKey()), iv);
  const ct = Buffer.concat([cipher.update(base32Secret, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  // Format: base64(iv | tag | ciphertext)
  return Buffer.concat([iv, tag, ct]).toString('base64');
}

export function decryptSecret(blob) {
  const buf = Buffer.from(blob, 'base64');
  if (buf.length < 12 + 16) throw new Error('totp: ciphertext too short');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const ct = buf.subarray(28);
  const decipher = crypto.createDecipheriv('aes-256-gcm', Buffer.from(totpKey()), iv);
  decipher.setAuthTag(tag);
  const pt = Buffer.concat([decipher.update(ct), decipher.final()]);
  return pt.toString('utf8');
}

// ---------- secret + QR -------------------------------------------------

export function generateSecret() {
  // OTPAuth.Secret has its own random generator; we use Node's crypto
  // explicitly so the entropy source is auditable.
  const bytes = crypto.randomBytes(SECRET_BYTES);
  return new OTPAuth.Secret({ buffer: bytes }).base32;
}

export function buildOtpauthUri({ base32Secret, accountLabel, issuer }) {
  const t = new OTPAuth.TOTP({
    issuer: issuer || 'TatbeeqX',
    label: accountLabel,
    algorithm: TOTP_ALGO,
    digits: TOTP_DIGITS,
    period: TOTP_PERIOD,
    secret: OTPAuth.Secret.fromBase32(base32Secret),
  });
  return t.toString();
}

// Renders the otpauth URI as a base64-encoded PNG data URL the
// frontend can drop straight into <img src=...>. Avoids needing a QR
// renderer plugin on the Flutter side.
export async function buildQrDataUrl(otpauthUri) {
  return qrcode.toDataURL(otpauthUri, { width: 256, margin: 1 });
}

// ---------- verify ------------------------------------------------------

// Validates a 6-digit TOTP against an unencrypted base32 secret.
// `window: 1` accepts the previous, current, and next 30s window —
// matches every standard authenticator's clock-drift tolerance.
export function verifyCode(base32Secret, code) {
  if (!base32Secret || typeof code !== 'string') return false;
  const cleaned = code.replace(/\s+/g, '');
  if (!/^\d{6}$/.test(cleaned)) return false;
  const t = new OTPAuth.TOTP({
    algorithm: TOTP_ALGO,
    digits: TOTP_DIGITS,
    period: TOTP_PERIOD,
    secret: OTPAuth.Secret.fromBase32(base32Secret),
  });
  // delta is null on miss, an integer (-1, 0, 1) on hit.
  const delta = t.validate({ token: cleaned, window: 1 });
  return delta !== null;
}

// ---------- recovery codes ----------------------------------------------

// Format: lowercase hex, dashes every 5 chars, e.g. `a1b2c-3d4e5`.
function formatRecoveryCode(buf) {
  const hex = buf.toString('hex');
  return `${hex.slice(0, 5)}-${hex.slice(5)}`;
}

export function generateRecoveryCodes(count = RECOVERY_CODE_COUNT) {
  const out = [];
  for (let i = 0; i < count; i++) {
    out.push(formatRecoveryCode(crypto.randomBytes(RECOVERY_CODE_BYTES)));
  }
  return out;
}

export function hashRecoveryCode(plaintext) {
  // Normalize before hashing so users can paste with/without dashes.
  const normalized = plaintext.replace(/[\s-]/g, '').toLowerCase();
  return crypto.createHash('sha256').update(normalized).digest('hex');
}
