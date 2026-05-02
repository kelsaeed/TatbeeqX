import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import { pipeline } from 'node:stream/promises';
import { prisma } from './prisma.js';
import { logSystem } from './system_log.js';
import { fireAndForget } from './webhooks.js';

// Phase 4.6 / 4.7 — backup + restore for the primary database.
//
// Provider matrix:
//   sqlite        → file copy + atomic rename
//   postgresql    → spawn `pg_dump`, stream stdout to a .sql file
//   mysql/mariadb → spawn `mysqldump`, stream stdout to a .sql file
//
// In-process restore is implemented for sqlite only (file overwrite +
// restart). For pg/mysql, the dump is plain SQL — restore it from the
// host with psql / mysql, since restoring those engines from inside the
// API process is risky (active connections, role privileges).

const BACKUP_DIR_NAME = 'backups';

export function getBackupsDir(cwd = process.cwd()) {
  const dir = path.resolve(cwd, BACKUP_DIR_NAME);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function inferSqlitePath(databaseUrl) {
  if (typeof databaseUrl !== 'string' || !databaseUrl.startsWith('file:')) return null;
  const stripped = databaseUrl.slice('file:'.length);
  return path.resolve(process.cwd(), 'prisma', stripped);
}

export function detectProvider(url = process.env.DATABASE_URL || '') {
  const s = String(url || '').trim().toLowerCase();
  if (s.startsWith('file:') || s.endsWith('.db') || s.endsWith('.sqlite') || s.endsWith('.sqlite3')) return 'sqlite';
  if (s.startsWith('postgres://') || s.startsWith('postgresql://')) return 'postgresql';
  if (s.startsWith('mysql://') || s.startsWith('mariadb://')) return 'mysql';
  return 'other';
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '-');
}

export function listBackups() {
  const dir = getBackupsDir();
  const files = fs.readdirSync(dir).filter((f) => /\.(db|sql)(\.enc)?$/i.test(f));
  return files
    .map((f) => {
      const full = path.join(dir, f);
      const st = fs.statSync(full);
      const encrypted = f.endsWith('.enc');
      const baseExt = (encrypted ? f.slice(0, -4) : f).split('.').pop();
      return {
        name: f,
        path: full,
        size: st.size,
        createdAt: st.mtime.toISOString(),
        kind: baseExt === 'db' ? 'sqlite' : 'sql',
        encrypted,
      };
    })
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

// Phase 4.8 / 4.9 — optional AES-256-GCM encryption.
//
// If BACKUP_ENCRYPTION_KEY is set, backups are encrypted post-write and
// the source plaintext is removed.
//
// Two on-disk formats supported:
//
//   v1 (Phase 4.8, legacy reads only):
//     [magic 4B "MCEB"] [version 1B = 0x01] [salt 16B] [iv 12B]
//     [authTag 16B] [ciphertext...]
//     — Auth tag in the header forced an in-memory buffer because the tag
//       isn't known until after the cipher finalises.
//
//   v2 (Phase 4.9, current writer + reader):
//     [magic 4B "MCEB"] [version 1B = 0x02] [salt 16B] [iv 12B]
//     [ciphertext...] [authTag 16B]
//     — Auth tag at the END so encryption streams straight to disk.
//       Multi-GB DBs no longer hold the whole ciphertext in RAM.
//
// "MCEB" = TatbeeqX Encrypted Backup. AES-256-GCM with
// PBKDF2(passphrase, salt, 100k iterations, sha256). Self-contained — no
// external KMS dependency.

const ENC_MAGIC = Buffer.from('MCEB', 'utf8');
const ENC_VERSION_V1 = 1;
const ENC_VERSION_V2 = 2;
const ENC_PBKDF2_ITERS = 100_000;
const ENC_AUTH_TAG_BYTES = 16;
const ENC_HEADER_BYTES_V2 = 4 + 1 + 16 + 12; // magic + version + salt + iv

function deriveKey(rawKey, salt) {
  if (/^[0-9a-fA-F]{64}$/.test(rawKey)) return Buffer.from(rawKey, 'hex');
  if (/^[A-Za-z0-9+/=]{43,44}$/.test(rawKey)) {
    try {
      const buf = Buffer.from(rawKey, 'base64');
      if (buf.length === 32) return buf;
    } catch (_) { /* fall through to PBKDF2 */ }
  }
  return crypto.pbkdf2Sync(rawKey, salt, ENC_PBKDF2_ITERS, 32, 'sha256');
}

function isEncryptionEnabled() {
  return typeof process.env.BACKUP_ENCRYPTION_KEY === 'string'
      && process.env.BACKUP_ENCRYPTION_KEY.length > 0;
}

// Phase 4.9 — streams plaintext through the cipher straight to the dest
// file. Auth tag is appended at the end (v2 format). Memory usage stays
// flat regardless of source file size.
export async function encryptStreamWithKey(srcPath, destPath, rawKey) {
  const salt = crypto.randomBytes(16);
  const iv = crypto.randomBytes(12);
  const key = deriveKey(rawKey, salt);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

  const inStream = fs.createReadStream(srcPath);
  const outStream = fs.createWriteStream(destPath);

  // Write header first.
  outStream.write(ENC_MAGIC);
  outStream.write(Buffer.from([ENC_VERSION_V2]));
  outStream.write(salt);
  outStream.write(iv);

  // Stream plaintext → cipher → outStream, but don't end outStream so we
  // can append the auth tag after the cipher finalises.
  await pipeline(inStream, cipher, outStream, { end: false });

  // Append the auth tag and close the file.
  await new Promise((resolve, reject) => {
    outStream.once('error', reject);
    outStream.end(cipher.getAuthTag(), resolve);
  });
}

async function encryptFileInPlace(srcPath) {
  if (!isEncryptionEnabled()) return srcPath;
  const dest = `${srcPath}.enc`;
  await encryptStreamWithKey(srcPath, dest, process.env.BACKUP_ENCRYPTION_KEY);
  fs.unlinkSync(srcPath);
  return dest;
}

export async function decryptBackupToWithKey(srcPath, destPath, rawKey) {
  const stat = fs.statSync(srcPath);
  if (stat.size < ENC_HEADER_BYTES_V2 + ENC_AUTH_TAG_BYTES) {
    throw new Error('Encrypted file too short');
  }
  // Read header + version detection
  const headerProbe = Buffer.alloc(5);
  const fd = fs.openSync(srcPath, 'r');
  try {
    fs.readSync(fd, headerProbe, 0, 5, 0);
  } finally {
    fs.closeSync(fd);
  }
  if (!headerProbe.subarray(0, 4).equals(ENC_MAGIC)) {
    throw new Error('Not an MCEB encrypted file');
  }
  const version = headerProbe[4];

  if (version === ENC_VERSION_V1) {
    // Legacy in-memory path.
    const buf = fs.readFileSync(srcPath);
    const salt = buf.subarray(5, 21);
    const iv = buf.subarray(21, 33);
    const authTag = buf.subarray(33, 49);
    const ciphertext = buf.subarray(49);
    const key = deriveKey(rawKey, salt);
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    fs.writeFileSync(destPath, plaintext);
    return;
  }

  if (version !== ENC_VERSION_V2) {
    throw new Error(`Unsupported MCEB version: ${version}`);
  }

  // v2: streaming path.
  const headerBuf = Buffer.alloc(ENC_HEADER_BYTES_V2);
  const tagBuf = Buffer.alloc(ENC_AUTH_TAG_BYTES);
  const fd2 = fs.openSync(srcPath, 'r');
  try {
    fs.readSync(fd2, headerBuf, 0, ENC_HEADER_BYTES_V2, 0);
    fs.readSync(fd2, tagBuf, 0, ENC_AUTH_TAG_BYTES, stat.size - ENC_AUTH_TAG_BYTES);
  } finally {
    fs.closeSync(fd2);
  }
  const salt = headerBuf.subarray(5, 21);
  const iv = headerBuf.subarray(21, 33);
  const key = deriveKey(rawKey, salt);

  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tagBuf);

  const ciphertextStart = ENC_HEADER_BYTES_V2;
  const ciphertextEnd = stat.size - ENC_AUTH_TAG_BYTES; // exclusive
  const inStream = fs.createReadStream(srcPath, { start: ciphertextStart, end: ciphertextEnd - 1 });
  const outStream = fs.createWriteStream(destPath);

  await new Promise((resolve, reject) => {
    inStream.on('error', reject);
    decipher.on('error', reject);
    outStream.on('error', reject);
    outStream.on('finish', resolve);
    inStream.pipe(decipher).pipe(outStream);
  });
}

export async function decryptBackupTo(srcPath, destPath) {
  if (!isEncryptionEnabled()) {
    throw new Error('BACKUP_ENCRYPTION_KEY is not set; cannot decrypt.');
  }
  return decryptBackupToWithKey(srcPath, destPath, process.env.BACKUP_ENCRYPTION_KEY);
}

// Phase 4.9 — re-encrypt every .enc file in the backups dir under a new
// key. Workflow:
//   1. Read each .enc through decryptBackupToWithKey(currentKey)
//   2. Re-encrypt to a sibling file with newKey
//   3. Atomically rename over the original
//   4. Caller is responsible for updating the running env (`.env`) so the
//      next process boot sees the new key.
//
// We don't auto-update .env from inside this helper — that's coupled to
// the route layer (which writes via env_writer.js).
export async function rotateBackupEncryption(currentKey, newKey) {
  if (!currentKey || !newKey) throw new Error('Both currentKey and newKey are required');
  if (currentKey === newKey) throw new Error('Old and new keys are identical');

  const dir = getBackupsDir();
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.enc'));
  const results = { rotated: [], failed: [] };

  for (const name of files) {
    const full = path.join(dir, name);
    const tmpPlain = `${full}.rot-plain-${Date.now()}`;
    const tmpEnc = `${full}.rot-enc-${Date.now()}`;
    try {
      await decryptBackupToWithKey(full, tmpPlain, currentKey);
      await encryptStreamWithKey(tmpPlain, tmpEnc, newKey);
      fs.renameSync(tmpEnc, full); // atomic on a single filesystem
      results.rotated.push(name);
    } catch (err) {
      results.failed.push({ name, error: String(err.message || err) });
    } finally {
      try { fs.existsSync(tmpPlain) && fs.unlinkSync(tmpPlain); } catch (_) { /* ignore */ }
      try { fs.existsSync(tmpEnc) && fs.unlinkSync(tmpEnc); } catch (_) { /* ignore */ }
    }
  }
  return results;
}

function safeLabel(label) {
  if (!label) return '';
  const cleaned = String(label)
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40);
  return cleaned ? `-${cleaned}` : '';
}

function finalize(name, dest) {
  const size = fs.statSync(dest).size;
  return { name, path: dest, size, createdAt: new Date().toISOString(), encrypted: false };
}

async function maybeEncrypt(result) {
  if (!isEncryptionEnabled()) return result;
  const encryptedPath = await encryptFileInPlace(result.path);
  const encryptedName = path.basename(encryptedPath);
  const size = fs.statSync(encryptedPath).size;
  return { name: encryptedName, path: encryptedPath, size, createdAt: result.createdAt, encrypted: true };
}

// Phase 4.10 — signed-URL helpers for cross-host download.
//
// The receiver tool can pull a backup over HTTPS without holding a Money
// Control session. We sign the URL with a shared secret + an expiry, and
// the download endpoint verifies before streaming the file.
//
// Secret: BACKUP_DOWNLOAD_SECRET (env). If missing, signed URLs aren't
// emitted in webhook payloads and the download endpoint refuses signed
// requests — clients must fall back to the existing JWT-protected route
// (which doesn't accept query-param tokens, on purpose).
//
// Format: ?expires=<unix>&sig=<hex of HMAC-SHA256(secret, name + expires)>

const DOWNLOAD_TTL_SECONDS = 60 * 60; // 1 hour

export function isDownloadSigningEnabled() {
  return typeof process.env.BACKUP_DOWNLOAD_SECRET === 'string'
      && process.env.BACKUP_DOWNLOAD_SECRET.length >= 16;
}

export function signDownloadUrl(name, baseUrl, ttlSeconds = DOWNLOAD_TTL_SECONDS) {
  if (!isDownloadSigningEnabled()) return null;
  const expires = Math.floor(Date.now() / 1000) + Math.max(60, ttlSeconds);
  const payload = `${name}.${expires}`;
  const sig = crypto.createHmac('sha256', process.env.BACKUP_DOWNLOAD_SECRET).update(payload).digest('hex');
  const base = String(baseUrl || '').replace(/\/$/, '');
  return `${base}/api/admin/backups/${encodeURIComponent(name)}/download?expires=${expires}&sig=${sig}`;
}

export function verifyDownloadSignature(name, expires, sig) {
  if (!isDownloadSigningEnabled()) return false;
  if (!name || !expires || !sig) return false;
  const exp = Number(expires);
  if (!Number.isFinite(exp) || exp * 1000 < Date.now()) return false;
  const payload = `${name}.${exp}`;
  const expected = crypto.createHmac('sha256', process.env.BACKUP_DOWNLOAD_SECRET).update(payload).digest('hex');
  if (expected.length !== sig.length) return false;
  return crypto.timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(sig, 'hex'));
}

async function createSqliteBackup({ label }) {
  const url = process.env.DATABASE_URL;
  const src = inferSqlitePath(url);
  if (!src || !fs.existsSync(src)) {
    const err = new Error(`Source DB file not found: ${src ?? '(no file: URL)'}`);
    err.status = 500;
    throw err;
  }
  const name = `dev-${timestamp()}${safeLabel(label)}.db`;
  const dest = path.join(getBackupsDir(), name);
  fs.copyFileSync(src, dest);
  return finalize(name, dest);
}

function parseDbUrl(url) {
  const u = new URL(url);
  return {
    user: decodeURIComponent(u.username),
    password: decodeURIComponent(u.password),
    host: u.hostname,
    port: u.port,
    database: u.pathname.replace(/^\//, ''),
  };
}

async function spawnDumpToFile(bin, args, env, dest) {
  await new Promise((resolve, reject) => {
    const out = fs.createWriteStream(dest);
    let stderr = '';
    let child;
    try {
      child = spawn(bin, args, { env });
    } catch (err) {
      reject(new Error(`Could not spawn ${bin}: ${err.message}`));
      return;
    }
    child.stdout.pipe(out);
    child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
    child.on('error', (err) => {
      out.destroy();
      try { fs.unlinkSync(dest); } catch (_) { /* ignore */ }
      reject(new Error(
        `Could not run ${bin}: ${err.message}. ` +
        `Make sure ${bin} is on PATH inside the API process or container.`,
      ));
    });
    child.on('close', (code) => {
      out.end(() => {
        if (code === 0) {
          resolve();
        } else {
          try { fs.unlinkSync(dest); } catch (_) { /* ignore */ }
          reject(new Error(`${bin} exited with ${code}: ${stderr.slice(0, 1000)}`));
        }
      });
    });
  });
}

async function createPostgresBackup({ label }) {
  const cfg = parseDbUrl(process.env.DATABASE_URL);
  const name = `pg-${timestamp()}${safeLabel(label)}.sql`;
  const dest = path.join(getBackupsDir(), name);
  const args = [];
  if (cfg.host) args.push('-h', cfg.host);
  if (cfg.port) args.push('-p', cfg.port);
  if (cfg.user) args.push('-U', cfg.user);
  args.push('--no-owner', '--no-privileges', '--clean', '--if-exists', '--quote-all-identifiers');
  args.push('-d', cfg.database);
  const env = { ...process.env };
  if (cfg.password) env.PGPASSWORD = cfg.password;
  await spawnDumpToFile('pg_dump', args, env, dest);
  return finalize(name, dest);
}

async function createMysqlBackup({ label }) {
  const cfg = parseDbUrl(process.env.DATABASE_URL);
  const name = `mysql-${timestamp()}${safeLabel(label)}.sql`;
  const dest = path.join(getBackupsDir(), name);
  const args = ['--single-transaction', '--routines', '--triggers', '--no-tablespaces'];
  if (cfg.host) args.push('-h', cfg.host);
  if (cfg.port) args.push('-P', cfg.port);
  if (cfg.user) args.push('-u', cfg.user);
  if (cfg.password) args.push(`-p${cfg.password}`); // mysqldump has no env-var equivalent for password
  args.push(cfg.database);
  await spawnDumpToFile('mysqldump', args, process.env, dest);
  return finalize(name, dest);
}

export async function createBackup({ label = null } = {}) {
  const provider = detectProvider();
  let backup;
  try {
    if (provider === 'sqlite') backup = await createSqliteBackup({ label });
    else if (provider === 'postgresql') backup = await createPostgresBackup({ label });
    else if (provider === 'mysql') backup = await createMysqlBackup({ label });
    else {
      const err = new Error(`Backup not supported for provider: ${provider}.`);
      err.status = 400;
      throw err;
    }
  } catch (err) {
    if (!err.status) err.status = 500;
    throw err;
  }
  backup = await maybeEncrypt(backup);
  await logSystem('info', 'backup', `Backup created: ${backup.name}`, {
    provider, size: backup.size, encrypted: backup.encrypted,
  });
  // Phase 4.8 — fire-and-forget webhook so off-site sync services can pick it up.
  // Phase 4.10 — include a pre-signed download URL when BACKUP_DOWNLOAD_SECRET is set,
  // so cross-host receivers can pull the file without a TatbeeqX session.
  const downloadUrl = signDownloadUrl(backup.name, process.env.BACKUP_PUBLIC_URL || '');
  fireAndForget('backup.created', {
    name: backup.name,
    path: backup.path,
    size: backup.size,
    createdAt: backup.createdAt,
    provider,
    encrypted: backup.encrypted,
    downloadUrl,
  });
  return backup;
}

// Phase 4.11 — on-disk retention.
//
// Two rules, applied together (file deleted if EITHER triggers):
//   - age:   files older than `days` days
//   - count: files beyond the newest `maxCount` (when > 0)
// Floor: never let count drop below `minKeep` — protects the last backup.
//
// All three are read from the `settings` table (companyId=null) at sweep
// time, so the operator can change them without restarting the API. The
// hourly cron tick calls sweepBackupRetention() alongside the existing
// scheduled-report retention sweep; admins can also trigger it manually
// via POST /api/admin/backups/sweep-retention.
//
// Webhooks are NOT fired on retention deletion: the receiver maintains
// its own copy under its own retention; remote sync doesn't care that
// the source pruned an old file locally.

const BACKUP_FILE_REGEX = /\.(db|sql)(\.enc)?$/i;
const DEFAULT_BACKUP_RETENTION_DAYS = 30;
const DEFAULT_BACKUP_MIN_KEEP = 1;

async function readNumericSetting(key, fallback) {
  try {
    const setting = await prisma.setting.findFirst({
      where: { companyId: null, key },
    });
    if (!setting) return fallback;
    const parsed = Number(setting.value);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
  } catch {
    return fallback;
  }
}

export async function getBackupRetentionConfig() {
  const days = await readNumericSetting('system.backup_retention_days', DEFAULT_BACKUP_RETENTION_DAYS);
  const maxCount = await readNumericSetting('system.backup_retention_max_count', 0);
  const minKeep = await readNumericSetting('system.backup_retention_min_keep', DEFAULT_BACKUP_MIN_KEEP);
  return { days, maxCount, minKeep };
}

export async function sweepBackupRetention(opts = {}) {
  const config = opts.config || await getBackupRetentionConfig();
  const dir = opts.dir || getBackupsDir();
  const now = typeof opts.now === 'number' ? opts.now : Date.now();

  const files = fs.readdirSync(dir)
    .filter((f) => BACKUP_FILE_REGEX.test(f))
    .map((f) => {
      const full = path.join(dir, f);
      const st = fs.statSync(full);
      return { name: f, path: full, mtime: st.mtimeMs };
    })
    .sort((a, b) => b.mtime - a.mtime); // newest first

  const ageCutoff = config.days > 0 ? now - config.days * 86_400_000 : null;
  const minKeep = Math.max(0, config.minKeep);

  const toDelete = [];
  for (let i = 0; i < files.length; i++) {
    if (i < minKeep) continue; // protect the newest minKeep
    const f = files[i];
    const tooOld = ageCutoff != null && f.mtime < ageCutoff;
    const tooMany = config.maxCount > 0 && i >= config.maxCount;
    if (tooOld || tooMany) toDelete.push(f);
  }

  const deleted = [];
  for (const f of toDelete) {
    try {
      fs.unlinkSync(f.path);
      deleted.push(f.name);
    } catch (err) {
      await logSystem('warn', 'backup', `Retention sweep failed to delete ${f.name}`, {
        error: String(err?.message || err),
      });
    }
  }

  if (deleted.length > 0) {
    await logSystem('info', 'backup', 'Retention sweep pruned old backups', {
      deleted: deleted.length,
      kept: files.length - deleted.length,
      config,
    });
  }

  return {
    deleted,
    kept: files.length - deleted.length,
    totalBefore: files.length,
    config,
  };
}

export async function deleteBackup(name) {
  if (typeof name !== 'string' || !/^[A-Za-z0-9._-]+$/.test(name)) {
    const err = new Error('Invalid backup name');
    err.status = 400;
    throw err;
  }
  const target = path.join(getBackupsDir(), name);
  if (!target.startsWith(getBackupsDir())) {
    const err = new Error('Refusing to delete outside the backups directory');
    err.status = 400;
    throw err;
  }
  if (!fs.existsSync(target)) {
    const err = new Error('Backup not found');
    err.status = 404;
    throw err;
  }
  fs.unlinkSync(target);
  await logSystem('info', 'backup', `Backup deleted: ${name}`);
}

export async function restoreBackup(name) {
  if (typeof name !== 'string' || !/^[A-Za-z0-9._-]+$/.test(name)) {
    const err = new Error('Invalid backup name');
    err.status = 400;
    throw err;
  }
  const provider = detectProvider();
  if (provider !== 'sqlite') {
    const err = new Error(
      `In-process restore is supported for SQLite only. For ${provider}, restore the .sql dump from the host using psql / mysql.`,
    );
    err.status = 400;
    throw err;
  }
  const dest = inferSqlitePath(process.env.DATABASE_URL);
  const src = path.join(getBackupsDir(), name);
  if (!src.startsWith(getBackupsDir())) {
    const err = new Error('Refusing to read outside the backups directory');
    err.status = 400;
    throw err;
  }
  if (!fs.existsSync(src)) {
    const err = new Error('Backup not found');
    err.status = 404;
    throw err;
  }

  try { await prisma.$disconnect(); } catch (_) { /* ignore */ }

  const staging = `${dest}.restoring-${Date.now()}`;
  if (name.endsWith('.enc')) {
    if (!isEncryptionEnabled()) {
      const err = new Error('This backup is encrypted; set BACKUP_ENCRYPTION_KEY to restore it.');
      err.status = 400;
      throw err;
    }
    await decryptBackupTo(src, staging);
  } else {
    fs.copyFileSync(src, staging);
  }
  fs.renameSync(staging, dest);

  await logSystem('warn', 'backup', `Restore from ${name} complete; restart required`);
  return {
    ok: true,
    restartRequired: true,
    message: 'Restore complete. Restart the API process so Prisma re-opens the new DB file.',
  };
}
