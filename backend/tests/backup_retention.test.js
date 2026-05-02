// Phase 4.11 — on-disk backup retention sweep.
//
// These tests work against a per-test temp directory and pass an explicit
// `config` + `now`, so we exercise the prune logic without touching the
// shared backups dir or the settings table.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { sweepBackupRetention } from '../src/lib/backup.js';

const DAY = 86_400_000;

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'mc-retention-'));
}

function writeBackup(dir, name, ageDays, now) {
  const full = path.join(dir, name);
  fs.writeFileSync(full, `dummy ${name}`);
  const t = (now - ageDays * DAY) / 1000;
  fs.utimesSync(full, t, t);
  return full;
}

function listNames(dir) {
  return fs.readdirSync(dir).sort();
}

let tmp;
const NOW = Date.UTC(2026, 4, 1, 12, 0, 0); // 2026-05-01T12:00:00Z

beforeEach(() => {
  tmp = mkTmpDir();
});

afterEach(() => {
  try {
    for (const f of fs.readdirSync(tmp)) fs.unlinkSync(path.join(tmp, f));
    fs.rmdirSync(tmp);
  } catch (_) { /* best-effort */ }
});

describe('sweepBackupRetention', () => {
  it('deletes files older than the age cutoff and keeps newer ones', async () => {
    writeBackup(tmp, 'dev-old.db', 60, NOW);
    writeBackup(tmp, 'dev-mid.db', 20, NOW);
    writeBackup(tmp, 'dev-new.db', 1, NOW);

    const result = await sweepBackupRetention({
      dir: tmp,
      now: NOW,
      config: { days: 30, maxCount: 0, minKeep: 1 },
    });

    expect(result.deleted).toEqual(['dev-old.db']);
    expect(result.kept).toBe(2);
    expect(listNames(tmp)).toEqual(['dev-mid.db', 'dev-new.db']);
  });

  it('keeps only the newest maxCount when count rule triggers', async () => {
    writeBackup(tmp, 'a.db', 5, NOW);
    writeBackup(tmp, 'b.db', 4, NOW);
    writeBackup(tmp, 'c.db', 3, NOW);
    writeBackup(tmp, 'd.db', 2, NOW);
    writeBackup(tmp, 'e.db', 1, NOW);

    const result = await sweepBackupRetention({
      dir: tmp,
      now: NOW,
      config: { days: 0, maxCount: 2, minKeep: 1 },
    });

    expect(result.kept).toBe(2);
    expect(listNames(tmp)).toEqual(['d.db', 'e.db']);
    expect(result.deleted.sort()).toEqual(['a.db', 'b.db', 'c.db']);
  });

  it('combines age and count rules — file deleted if either triggers', async () => {
    writeBackup(tmp, 'old.db', 90, NOW);  // age trigger
    writeBackup(tmp, 'mid.db', 10, NOW);  // count trigger (3rd newest, maxCount=2)
    writeBackup(tmp, 'new1.db', 2, NOW);
    writeBackup(tmp, 'new2.db', 1, NOW);

    const result = await sweepBackupRetention({
      dir: tmp,
      now: NOW,
      config: { days: 30, maxCount: 2, minKeep: 1 },
    });

    expect(listNames(tmp)).toEqual(['new1.db', 'new2.db']);
    expect(result.deleted.sort()).toEqual(['mid.db', 'old.db']);
  });

  it('honors minKeep floor even when both rules say "delete everything"', async () => {
    writeBackup(tmp, 'ancient1.db', 365, NOW);
    writeBackup(tmp, 'ancient2.db', 360, NOW);
    writeBackup(tmp, 'ancient3.db', 355, NOW);

    const result = await sweepBackupRetention({
      dir: tmp,
      now: NOW,
      config: { days: 30, maxCount: 1, minKeep: 2 },
    });

    // minKeep=2 protects the two newest (ancient3, ancient2) regardless
    // of age. Only ancient1 gets pruned.
    expect(listNames(tmp)).toEqual(['ancient2.db', 'ancient3.db']);
    expect(result.deleted).toEqual(['ancient1.db']);
    expect(result.kept).toBe(2);
  });

  it('is a no-op when both rules are disabled (days=0, maxCount=0)', async () => {
    writeBackup(tmp, 'old1.db', 365, NOW);
    writeBackup(tmp, 'old2.db', 100, NOW);
    writeBackup(tmp, 'new.db', 1, NOW);

    const result = await sweepBackupRetention({
      dir: tmp,
      now: NOW,
      config: { days: 0, maxCount: 0, minKeep: 1 },
    });

    expect(result.deleted).toEqual([]);
    expect(result.kept).toBe(3);
    expect(listNames(tmp).length).toBe(3);
  });

  it('leaves non-backup files alone', async () => {
    writeBackup(tmp, 'old.db', 365, NOW);
    writeBackup(tmp, 'old.sql', 365, NOW);
    writeBackup(tmp, 'old.db.enc', 365, NOW);
    writeBackup(tmp, 'README.txt', 365, NOW);     // not a backup name
    writeBackup(tmp, 'notes.md', 365, NOW);       // not a backup name
    writeBackup(tmp, 'somefile.lock', 365, NOW);  // not a backup name

    const result = await sweepBackupRetention({
      dir: tmp,
      now: NOW,
      config: { days: 30, maxCount: 0, minKeep: 0 },
    });

    expect(result.deleted.sort()).toEqual(['old.db', 'old.db.enc', 'old.sql']);
    // The non-backup files survive even though they're "old".
    expect(listNames(tmp).sort()).toEqual(['README.txt', 'notes.md', 'somefile.lock']);
  });

  it('treats .enc files the same as plaintext', async () => {
    writeBackup(tmp, 'a.db.enc', 90, NOW);
    writeBackup(tmp, 'b.sql.enc', 60, NOW);
    writeBackup(tmp, 'c.db.enc', 1, NOW);

    const result = await sweepBackupRetention({
      dir: tmp,
      now: NOW,
      config: { days: 30, maxCount: 0, minKeep: 1 },
    });

    expect(result.deleted.sort()).toEqual(['a.db.enc', 'b.sql.enc']);
    expect(listNames(tmp)).toEqual(['c.db.enc']);
  });
});
