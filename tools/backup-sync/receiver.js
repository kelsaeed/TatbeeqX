// TatbeeqX — backup-sync receiver
//
// A tiny standalone Express service that:
//
//   1. Subscribes (manually, via TatbeeqX's /webhooks UI) to the
//      `backup.created` event.
//   2. Verifies the HMAC-SHA256 signature against a shared secret.
//   3. Acquires the backup file in one of two modes:
//      - **shared-filesystem** (default): copies from SRC_DIR.
//      - **cross-host HTTP pull** (Phase 4.10): downloads via the signed
//        URL embedded in the webhook payload (`payload.downloadUrl`).
//        Used automatically when SRC_DIR isn't reachable, or always when
//        `PULL_VIA_HTTP=1` is set.
//   4. Writes the file to DEST_DIR.
//   5. (Phase 4.11) Optionally uploads the file via a native uploader
//      (S3 or restic), dropping the rclone hand-off requirement. With
//      `KEEP_LOCAL_COPY=0` the DEST_DIR copy is unlinked after a
//      successful upload.
//
// Configuration via env vars (see README.md for the full table):
//   PORT             — listen port (default 4100)
//   WEBHOOK_SECRET   — required; matches the WebhookSubscription secret
//   SRC_DIR          — path to the API's backups/ dir (shared-fs mode)
//   DEST_DIR         — required; where to write received files
//   PULL_VIA_HTTP    — "1" forces HTTP pull mode even if SRC_DIR works
//   UPLOADER         — "none" (default), "s3", or "restic"
//   KEEP_LOCAL_COPY  — "1" (default) keeps DEST_DIR file; "0" unlinks
//                      after successful upload

import express from 'express';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createS3Uploader } from './s3.js';
import { createResticUploader } from './restic.js';

export function createApp(config) {
  const {
    secret,
    srcDir,
    destDir,
    pullViaHttp = false,
    uploader = null, // { name, upload(filePath, fileName) → { ok, location?, error? } }
    keepLocalCopy = true,
    fetchImpl = globalThis.fetch, // overridable for tests
    log = console.log,
  } = config;

  if (!secret) throw new Error('createApp: secret is required');
  if (!destDir) throw new Error('createApp: destDir is required');
  if (!fs.existsSync(destDir)) fs.mkdirSync(destDir, { recursive: true });

  const app = express();
  app.use(express.raw({ type: 'application/json', limit: '512kb' }));

  app.post('/hook', async (req, res) => {
    const sig = req.headers['x-money-signature'];
    const event = req.headers['x-money-event'];
    if (typeof sig !== 'string' || !sig.startsWith('sha256=')) {
      return res.status(401).json({ error: 'missing or malformed signature' });
    }
    const expected = 'sha256=' + crypto.createHmac('sha256', secret).update(req.body).digest('hex');
    if (!safeEqual(sig, expected)) {
      return res.status(401).json({ error: 'bad signature' });
    }

    if (event !== 'backup.created') {
      return res.status(204).end();
    }

    let payload;
    try {
      payload = JSON.parse(req.body.toString('utf8'));
    } catch (_) {
      return res.status(400).json({ error: 'malformed JSON' });
    }

    const fileName = payload?.payload?.name;
    const downloadUrl = payload?.payload?.downloadUrl;
    if (!fileName || !/^[A-Za-z0-9._-]+$/.test(fileName)) {
      return res.status(400).json({ error: 'invalid file name in payload' });
    }

    const dest = path.join(destDir, fileName);
    if (!dest.startsWith(destDir)) {
      return res.status(400).json({ error: 'path escape rejected' });
    }

    const src = srcDir ? path.join(srcDir, fileName) : null;
    const haveSharedFs = !pullViaHttp && src && src.startsWith(srcDir) && fs.existsSync(src);

    try {
      if (haveSharedFs) {
        fs.copyFileSync(src, dest);
        log(`[backup-sync] copied ${fileName} (shared fs) → ${dest}`);
      } else if (downloadUrl) {
        await pullViaHttpFn(downloadUrl, dest, fetchImpl);
        log(`[backup-sync] pulled ${fileName} (HTTPS) → ${dest}`);
      } else {
        return res.status(404).json({
          error: `cannot acquire ${fileName}: not on shared FS and no downloadUrl in webhook payload (set BACKUP_DOWNLOAD_SECRET on the API)`,
        });
      }
    } catch (err) {
      return res.status(500).json({ error: String(err.message || err) });
    }

    let uploadResult = null;
    if (uploader) {
      try {
        uploadResult = await uploader.upload(dest, fileName);
        log(`[backup-sync] uploaded ${fileName} via ${uploader.name} → ${uploadResult.location || 'ok'}`);
        if (!keepLocalCopy) {
          try { fs.unlinkSync(dest); } catch (_) { /* best-effort */ }
        }
      } catch (err) {
        // Upload failed → 500 → API retries the webhook. We deliberately
        // leave the local DEST_DIR copy in place even with
        // keepLocalCopy=false, because losing a backup that we couldn't
        // upload is worse than holding it.
        return res.status(500).json({
          error: `uploader ${uploader.name} failed: ${String(err.message || err)}`,
        });
      }
    }

    res.status(200).json({
      ok: true,
      copiedTo: keepLocalCopy ? dest : null,
      uploaded: uploadResult ? { uploader: uploader.name, ...uploadResult } : null,
    });
  });

  return app;
}

async function pullViaHttpFn(url, destPath, fetchImpl) {
  const r = await fetchImpl(url, { signal: AbortSignal.timeout(120_000) });
  if (!r.ok) throw new Error(`HTTP ${r.status} from ${url}`);
  const tmp = `${destPath}.partial-${Date.now()}`;
  const out = fs.createWriteStream(tmp);
  await new Promise((resolve, reject) => {
    out.on('error', reject);
    out.on('finish', resolve);
    (async () => {
      try {
        for await (const chunk of r.body) out.write(chunk);
        out.end();
      } catch (err) {
        out.destroy();
        reject(err);
      }
    })();
  });
  fs.renameSync(tmp, destPath);
}

function safeEqual(a, b) {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

// Build a config object from environment variables. Exposed so tests
// can build a config without process.env mutations.
export function buildUploaderFromEnv(env = process.env) {
  const kind = (env.UPLOADER || 'none').toLowerCase();
  if (kind === 'none') return null;
  if (kind === 's3') {
    return createS3Uploader({
      bucket: env.S3_BUCKET,
      region: env.S3_REGION,
      accessKeyId: env.S3_ACCESS_KEY_ID,
      secretAccessKey: env.S3_SECRET_ACCESS_KEY,
      endpoint: env.S3_ENDPOINT || undefined,
      keyPrefix: env.S3_KEY_PREFIX || '',
      pathStyle: env.S3_PATH_STYLE === '1',
    });
  }
  if (kind === 'restic') {
    return createResticUploader({
      repository: env.RESTIC_REPOSITORY,
      password: env.RESTIC_PASSWORD,
      bin: env.RESTIC_BIN || 'restic',
    });
  }
  throw new Error(`Unknown UPLOADER value: ${env.UPLOADER} (expected: none, s3, restic)`);
}

function main() {
  const PORT = Number(process.env.PORT || 4100);
  const SECRET = process.env.WEBHOOK_SECRET;
  const SRC_DIR = path.resolve(
    process.env.SRC_DIR ||
      path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'backend', 'backups'),
  );
  const DEST_DIR = path.resolve(process.env.DEST_DIR || '');

  if (!SECRET) {
    console.error('FATAL: WEBHOOK_SECRET must be set.');
    process.exit(1);
  }
  if (!DEST_DIR) {
    console.error('FATAL: DEST_DIR must be set.');
    process.exit(1);
  }

  let uploader;
  try {
    uploader = buildUploaderFromEnv();
  } catch (err) {
    console.error(`FATAL: ${err.message}`);
    process.exit(1);
  }

  const app = createApp({
    secret: SECRET,
    srcDir: SRC_DIR,
    destDir: DEST_DIR,
    pullViaHttp: process.env.PULL_VIA_HTTP === '1',
    uploader,
    keepLocalCopy: process.env.KEEP_LOCAL_COPY !== '0',
  });

  app.listen(PORT, () => {
    console.log(`[backup-sync] listening on :${PORT}`);
    console.log(`[backup-sync] watching SRC_DIR ${SRC_DIR}`);
    console.log(`[backup-sync] copying to DEST_DIR ${DEST_DIR}`);
    console.log(`[backup-sync] uploader: ${uploader ? uploader.name : 'none'}`);
    if (uploader && process.env.KEEP_LOCAL_COPY === '0') {
      console.log('[backup-sync] KEEP_LOCAL_COPY=0 — DEST_DIR file removed after successful upload');
    }
  });
}

// Only auto-run when invoked directly. Importing the module (e.g. from
// tests) does not start the server.
if (import.meta.url === `file://${process.argv[1]?.replace(/\\/g, '/')}` ||
    import.meta.url === `file:///${process.argv[1]?.replace(/\\/g, '/')}`) {
  main();
}
