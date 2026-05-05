import { Router } from 'express';
import fs from 'node:fs';
import path from 'node:path';
import { authenticate } from '../middleware/auth.js';
import { requirePermission, requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound, unauthorized } from '../lib/http.js';
import { writeAudit } from '../lib/audit.js';
import {
  listBackups,
  createBackup,
  deleteBackup,
  restoreBackup,
  rotateBackupEncryption,
  sweepBackupRetention,
  getBackupsDir,
  verifyDownloadSignature,
  isDownloadSigningEnabled,
} from '../lib/backup.js';
import { setEnvKeys } from '../lib/env_writer.js';
import { logSystem } from '../lib/system_log.js';
import { verifyAccessToken } from '../lib/jwt.js';
import { prisma } from '../lib/prisma.js';
import { listLocales, readLocale, writeLocale } from '../lib/translations.js';

const router = Router();
// Phase 4.10 — download endpoint with dual auth:
//   - signed URL (?expires&sig) — for the off-site sync receiver tool, no JWT needed
//   - else Bearer token — verified inline so this single route can serve both
//
// Mounted BEFORE the global authenticate middleware so signed-URL requests
// don't fail at the JWT check.
router.get(
  '/backups/:name/download',
  asyncHandler(async (req, res) => {
    const name = req.params.name;
    if (!/^[A-Za-z0-9._-]+$/.test(name)) throw badRequest('Invalid backup name');

    let allow = false;
    let actor = 'signed-url';

    if (req.query.sig && req.query.expires) {
      if (!isDownloadSigningEnabled()) throw unauthorized('Signed downloads disabled');
      if (!verifyDownloadSignature(name, req.query.expires, req.query.sig)) {
        throw unauthorized('Bad or expired signature');
      }
      allow = true;
    } else {
      const header = req.get('authorization') || '';
      const token = header.startsWith('Bearer ') ? header.slice(7) : null;
      if (!token) throw unauthorized('Missing access token');
      try {
        const payload = verifyAccessToken(token);
        const user = await prisma.user.findUnique({ where: { id: payload.sub } });
        if (!user || !user.isActive || !user.isSuperAdmin) throw unauthorized('Super Admin only');
        allow = true;
        actor = `user:${user.username}`;
      } catch (err) {
        if (err.name === 'TokenExpiredError') throw unauthorized('Access token expired');
        if (err.name === 'JsonWebTokenError') throw unauthorized('Invalid access token');
        throw err;
      }
    }
    if (!allow) throw unauthorized();

    const dir = getBackupsDir();
    const file = path.join(dir, name);
    if (!file.startsWith(dir)) throw badRequest('Refusing to read outside the backups directory');
    if (!fs.existsSync(file)) throw notFound('Backup not found');

    const size = fs.statSync(file).size;
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Content-Length', String(size));
    res.setHeader('Content-Disposition', `attachment; filename="${name}"`);
    const stream = fs.createReadStream(file);
    // Log started + completed/failed separately so a failed mid-stream
    // download isn't recorded as a successful one. `res.finish` fires
    // once the response is fully flushed; `res.close` fires whether or
    // not the response was finished, so we check `writableFinished` to
    // distinguish a clean end from a client disconnect.
    logSystem('info', 'backup', `Backup download started: ${name}`, { actor, size }).catch(() => {});
    res.once('finish', () => {
      logSystem('info', 'backup', `Backup download complete: ${name}`, { actor, size }).catch(() => {});
    });
    res.once('close', () => {
      if (!res.writableFinished) {
        logSystem('warn', 'backup', `Backup download interrupted: ${name}`, { actor, size }).catch(() => {});
      }
    });
    stream.once('error', (err) => {
      logSystem('error', 'backup', `Backup download stream error: ${name}`, {
        actor, size, error: String(err?.message || err),
      }).catch(() => {});
    });
    stream.pipe(res);
  }),
);

router.use(authenticate);

router.get(
  '/backups',
  requirePermission('backups.view'),
  asyncHandler(async (_req, res) => {
    res.json({ items: listBackups() });
  }),
);

router.post(
  '/backups',
  requirePermission('backups.create'),
  asyncHandler(async (req, res) => {
    const { label = null } = req.body ?? {};
    try {
      const backup = await createBackup({ label });
      await writeAudit({ req, action: 'create', entity: 'Backup', metadata: { name: backup.name, size: backup.size } });
      res.status(201).json(backup);
    } catch (err) {
      if (err && err.status) throw err;
      throw badRequest(err.message || String(err));
    }
  }),
);

router.delete(
  '/backups/:name',
  requirePermission('backups.delete'),
  asyncHandler(async (req, res) => {
    await deleteBackup(req.params.name);
    await writeAudit({ req, action: 'delete', entity: 'Backup', metadata: { name: req.params.name } });
    res.json({ ok: true });
  }),
);

router.post(
  '/backups/:name/restore',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const result = await restoreBackup(req.params.name);
    await writeAudit({ req, action: 'restore', entity: 'Backup', metadata: { name: req.params.name } });
    res.json(result);
  }),
);

// Phase 4.11 — manual retention sweep. The hourly cron tick runs the same
// helper; this endpoint exists so admins can trigger a sweep on demand
// after changing settings.system.backup_retention_* values.
router.post(
  '/backups/sweep-retention',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const result = await sweepBackupRetention();
    await writeAudit({
      req,
      action: 'sweep_retention',
      entity: 'Backup',
      metadata: { deleted: result.deleted.length, kept: result.kept },
    });
    res.json(result);
  }),
);

// Phase 4.9 — re-encrypt every .enc backup with a new key, then write the
// new key to .env (with a backup). The running process keeps the OLD key
// in memory until restart — which is correct: in-flight reads against
// existing files still need the current env value. After the operator
// restarts, fresh backups encrypt with the new key.
router.post(
  '/backups/rotate-encryption',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const currentKey = process.env.BACKUP_ENCRYPTION_KEY;
    const { newKey } = req.body ?? {};
    if (!currentKey) {
      throw badRequest('BACKUP_ENCRYPTION_KEY is not currently set. Set it first, take a backup, then rotate.');
    }
    if (!newKey || typeof newKey !== 'string' || newKey.length < 16) {
      throw badRequest('newKey is required (recommended: 64-char hex from `openssl rand -hex 32`).');
    }
    if (newKey === currentKey) {
      throw badRequest('New key matches the current key.');
    }

    const result = await rotateBackupEncryption(currentKey, newKey);
    if (result.failed.length === 0) {
      const env = setEnvKeys({ BACKUP_ENCRYPTION_KEY: newKey });
      await writeAudit({
        req,
        action: 'rotate_encryption',
        entity: 'Backup',
        metadata: { rotated: result.rotated.length, backupPath: env.backup },
      });
      await logSystem('warn', 'backup', 'Backup encryption key rotated; restart required', {
        rotated: result.rotated.length,
        envBackup: env.backup,
      });
      res.json({
        ok: true,
        restartRequired: true,
        rotated: result.rotated,
        failed: [],
        envBackup: env.backup,
        message:
          'Re-encryption complete and .env updated. Restart the API process so the new key is used for future backups.',
      });
    } else {
      // Don't touch .env if any file failed to re-encrypt.
      await writeAudit({
        req,
        action: 'rotate_encryption_partial',
        entity: 'Backup',
        metadata: { rotated: result.rotated.length, failed: result.failed.length },
      });
      await logSystem('error', 'backup', 'Key rotation incomplete; .env unchanged', result);
      res.status(500).json({
        ok: false,
        restartRequired: false,
        rotated: result.rotated,
        failed: result.failed,
        message:
          'Some backups failed to re-encrypt; .env was NOT updated so the running process can still read the originals.',
      });
    }
  }),
);

// Phase 4.10 — translation file management.
//
// Exposes the frontend ARBs over the API so a Super Admin can edit them
// from the running UI. Changes only take effect after `flutter gen-l10n`
// runs and the desktop binary is rebuilt — see docs/42-translation-management.md.

router.get(
  '/translations',
  requireSuperAdmin(),
  asyncHandler(async (_req, res) => {
    res.json({ items: listLocales() });
  }),
);

router.get(
  '/translations/:locale',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    res.json(readLocale(req.params.locale));
  }),
);

router.put(
  '/translations/:locale',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    if (!req.body || typeof req.body !== 'object' || !req.body.data) {
      throw badRequest('Body must be { data: <arb-json> }');
    }
    const summary = writeLocale(req.params.locale, req.body.data);
    await writeAudit({ req, action: 'update', entity: 'Translation', metadata: summary });
    await logSystem('info', 'translations', `ARB updated: ${summary.file}`, summary);
    res.json(summary);
  }),
);

export default router;
