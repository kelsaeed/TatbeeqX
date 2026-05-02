// Phase 4.8 — backup encryption round-trip.
//
// We don't run an actual createBackup() here (that would touch the live DB
// and disk); instead we write a known plaintext to a temp .db, encrypt it,
// and decrypt it back. The encryption helpers are not exported as
// public API yet (they're internal to lib/backup.js), so this test
// imports the post-write encrypt + the public decryptBackupTo via a
// small dynamic shim — see the imports below.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  decryptBackupTo,
  decryptBackupToWithKey,
  encryptStreamWithKey,
  rotateBackupEncryption,
  listBackups,
  getBackupsDir,
} from '../src/lib/backup.js';

// Round-trip test: write plaintext, kick off createBackup() with the env
// flag enabled? No — createBackup needs a real DB. We use a different path:
// generate plaintext, run encryptFileInPlace by writing it via the same
// algorithm decryptBackupTo expects. Since encryptFileInPlace is not
// exported, we instead validate the listBackups + decrypt path by writing
// a fake encrypted file ourselves using the same scheme — that catches
// header mismatches.
//
// Then we cover the "no key set" rejection path.

const ENC_KEY = 'a'.repeat(64); // 64 hex chars → 32 raw bytes

function tmpFile(suffix) {
  return path.join(os.tmpdir(), `mc-backup-${Date.now()}-${Math.random().toString(36).slice(2)}${suffix}`);
}

describe('backup encryption', () => {
  beforeEach(() => {
    process.env.BACKUP_ENCRYPTION_KEY = ENC_KEY;
  });

  afterEach(() => {
    delete process.env.BACKUP_ENCRYPTION_KEY;
  });

  it('rejects decryption when key is not set', async () => {
    delete process.env.BACKUP_ENCRYPTION_KEY;
    await expect(decryptBackupTo('whatever', 'whatever')).rejects.toThrow(/not set/);
  });

  it('rejects decryption when file is not MCEB', async () => {
    const bad = tmpFile('.enc');
    fs.writeFileSync(bad, Buffer.from('not really encrypted, just bytes that look long enough to clear the size guard ----------------------------', 'utf8'));
    try {
      await expect(decryptBackupTo(bad, tmpFile('.db'))).rejects.toThrow(/MCEB/);
    } finally {
      try { fs.unlinkSync(bad); } catch (_) { /* ignore */ }
    }
  });
});

describe('streaming encryption round-trip (v2)', () => {
  it('encrypts a file and decrypts it back to identical bytes', async () => {
    const plain = tmpFile('.db');
    const enc = tmpFile('.db.enc');
    const back = tmpFile('.db');
    const data = Buffer.alloc(1024 * 64); // 64 KB of random-ish bytes
    for (let i = 0; i < data.length; i++) data[i] = (i * 37 + 11) & 0xff;
    fs.writeFileSync(plain, data);

    try {
      await encryptStreamWithKey(plain, enc, ENC_KEY);
      // Encrypted file starts with MCEB magic
      const head = fs.readFileSync(enc, { encoding: null }).subarray(0, 5);
      expect(head[0]).toBe(0x4D); // 'M'
      expect(head[1]).toBe(0x43); // 'C'
      expect(head[2]).toBe(0x45); // 'E'
      expect(head[3]).toBe(0x42); // 'B'
      expect(head[4]).toBe(2);    // version 2

      await decryptBackupToWithKey(enc, back, ENC_KEY);
      const restored = fs.readFileSync(back);
      expect(restored.equals(data)).toBe(true);
    } finally {
      for (const f of [plain, enc, back]) {
        try { fs.unlinkSync(f); } catch (_) { /* ignore */ }
      }
    }
  });

  it('rejects a tampered ciphertext', async () => {
    const plain = tmpFile('.db');
    const enc = tmpFile('.db.enc');
    const back = tmpFile('.db');
    fs.writeFileSync(plain, Buffer.from('hello world!'.repeat(100)));

    try {
      await encryptStreamWithKey(plain, enc, ENC_KEY);
      // Flip a byte in the ciphertext (after the 33-byte v2 header, before the trailer).
      const buf = fs.readFileSync(enc);
      buf[40] = buf[40] ^ 0xff;
      fs.writeFileSync(enc, buf);

      await expect(decryptBackupToWithKey(enc, back, ENC_KEY)).rejects.toThrow();
    } finally {
      for (const f of [plain, enc, back]) {
        try { fs.unlinkSync(f); } catch (_) { /* ignore */ }
      }
    }
  });
});

describe('rotateBackupEncryption', () => {
  it('rotates an .enc file from one key to another', async () => {
    const dir = getBackupsDir();
    const key1 = 'a'.repeat(64);
    const key2 = 'b'.repeat(64);
    const plain = tmpFile('.db');
    fs.writeFileSync(plain, Buffer.from('rotation-test-payload'));

    const enc = path.join(dir, `dev-rotation-test-${Date.now()}.db.enc`);
    await encryptStreamWithKey(plain, enc, key1);

    try {
      const result = await rotateBackupEncryption(key1, key2);
      const rotatedNames = result.rotated;
      expect(rotatedNames).toContain(path.basename(enc));
      expect(result.failed).toEqual([]);

      // The file should now decrypt with key2 but NOT key1.
      const back = tmpFile('.db');
      await decryptBackupToWithKey(enc, back, key2);
      expect(fs.readFileSync(back).toString()).toBe('rotation-test-payload');
      try { fs.unlinkSync(back); } catch (_) { /* ignore */ }

      const back2 = tmpFile('.db');
      await expect(decryptBackupToWithKey(enc, back2, key1)).rejects.toThrow();
      try { fs.unlinkSync(back2); } catch (_) { /* ignore */ }
    } finally {
      try { fs.unlinkSync(plain); } catch (_) { /* ignore */ }
      try { fs.unlinkSync(enc); } catch (_) { /* ignore */ }
    }
  });

  it('rejects when keys match or are missing', async () => {
    await expect(rotateBackupEncryption('', 'whatever')).rejects.toThrow(/required/);
    await expect(rotateBackupEncryption('same', 'same')).rejects.toThrow(/identical/);
  });
});

describe('listBackups encryption metadata', () => {
  it('marks .enc files as encrypted in the listing', () => {
    const dir = getBackupsDir();
    const fakeName = `dev-2026-01-01T00-00-00-test-encryption-${Date.now()}.db.enc`;
    const fakePath = path.join(dir, fakeName);
    fs.writeFileSync(fakePath, Buffer.from('placeholder'));
    try {
      const items = listBackups();
      const found = items.find((b) => b.name === fakeName);
      expect(found).toBeDefined();
      expect(found.encrypted).toBe(true);
      expect(found.kind).toBe('sqlite');
    } finally {
      try { fs.unlinkSync(fakePath); } catch (_) { /* ignore */ }
    }
  });

  it('marks plain .db / .sql files as not encrypted', () => {
    const dir = getBackupsDir();
    const fake = `dev-2026-01-01T00-00-00-test-plain-${Date.now()}.db`;
    const fp = path.join(dir, fake);
    fs.writeFileSync(fp, Buffer.from('placeholder'));
    try {
      const items = listBackups();
      const found = items.find((b) => b.name === fake);
      expect(found).toBeDefined();
      expect(found.encrypted).toBe(false);
    } finally {
      try { fs.unlinkSync(fp); } catch (_) { /* ignore */ }
    }
  });
});
