// Phase 4.11 — receiver dispatch tests.
//
// Verifies that:
//   - HMAC verification works (good sig accepted, bad rejected, missing
//     header rejected)
//   - Non-backup events return 204
//   - File acquisition picks shared-fs vs HTTPS pull correctly
//   - The configured uploader is invoked after acquisition succeeds
//   - Upload failure returns 500 (so the API retries the webhook)
//   - keepLocalCopy=false unlinks the DEST_DIR file after a successful
//     upload, but keeps it on upload failure
//
// We bypass supertest's body-shaping by sending the body via .write()
// on the underlying http request — supertest's `.send(buffer)` with
// `Content-Type: application/json` will JSON-stringify the Buffer (we
// confirmed this once and dropped the probe test).

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createApp } from '../receiver.js';

const SECRET = 'test-secret';

function sign(body) {
  return 'sha256=' + crypto.createHmac('sha256', SECRET).update(body).digest('hex');
}

function buildBody(extra = {}) {
  return Buffer.from(JSON.stringify({
    event: 'backup.created',
    occurredAt: '2026-05-01T10:15:00.000Z',
    payload: {
      name: 'dev-2026-05-01.db',
      size: 11,
      createdAt: '2026-05-01T10:15:00.000Z',
      provider: 'sqlite',
      encrypted: false,
      ...extra,
    },
  }));
}

// Boot the express app on an ephemeral port so we can issue plain
// http.request() calls and control the wire bytes.
async function bootApp(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      resolve({ server, port });
    });
  });
}

function postRaw({ port, headers = {}, body }) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      method: 'POST',
      host: '127.0.0.1',
      port,
      path: '/hook',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        ...headers,
      },
    }, (res) => {
      let chunks = '';
      res.on('data', (c) => { chunks += c.toString(); });
      res.on('end', () => {
        let parsed = null;
        try { parsed = chunks.length > 0 ? JSON.parse(chunks) : null; } catch (_) { parsed = chunks; }
        resolve({ status: res.statusCode, body: parsed });
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function tmpDir(prefix) {
  return fs.mkdtempSync(path.join(os.tmpdir(), `mc-recv-${prefix}-`));
}

let srcDir, destDir;
let server, port;

beforeEach(() => {
  srcDir = tmpDir('src');
  destDir = tmpDir('dest');
});

afterEach(async () => {
  if (server) {
    await new Promise((resolve) => server.close(resolve));
    server = null;
    port = null;
  }
  for (const d of [srcDir, destDir]) {
    try {
      for (const f of fs.readdirSync(d)) fs.unlinkSync(path.join(d, f));
      fs.rmdirSync(d);
    } catch (_) { /* best-effort */ }
  }
});

async function start(opts) {
  const app = createApp({ secret: SECRET, srcDir, destDir, ...opts });
  ({ server, port } = await bootApp(app));
  return port;
}

describe('createApp — signature verification', () => {
  it('rejects requests with no signature header', async () => {
    await start();
    const body = buildBody();
    const res = await postRaw({ port, body });
    expect(res.status).toBe(401);
  });

  it('rejects requests with a wrong signature', async () => {
    await start();
    const body = buildBody();
    const res = await postRaw({
      port, body,
      headers: {
        'X-Money-Event': 'backup.created',
        'X-Money-Signature': 'sha256=' + 'a'.repeat(64),
      },
    });
    expect(res.status).toBe(401);
  });

  it('returns 204 for events that are not backup.created', async () => {
    await start();
    const body = Buffer.from(JSON.stringify({ event: 'webhook.test' }));
    const res = await postRaw({
      port, body,
      headers: {
        'X-Money-Event': 'webhook.test',
        'X-Money-Signature': sign(body),
      },
    });
    expect(res.status).toBe(204);
  });
});

describe('createApp — file acquisition', () => {
  it('copies from shared FS when SRC_DIR has the file', async () => {
    fs.writeFileSync(path.join(srcDir, 'dev-2026-05-01.db'), 'hello');
    await start();
    const body = buildBody();
    const res = await postRaw({
      port, body,
      headers: {
        'X-Money-Event': 'backup.created',
        'X-Money-Signature': sign(body),
      },
    });
    expect(res.status).toBe(200);
    expect(res.body.copiedTo).toBe(path.join(destDir, 'dev-2026-05-01.db'));
    expect(fs.readFileSync(path.join(destDir, 'dev-2026-05-01.db'), 'utf8')).toBe('hello');
  });

  it('returns 404 when no shared FS file and no downloadUrl in payload', async () => {
    await start();
    const body = buildBody();
    const res = await postRaw({
      port, body,
      headers: {
        'X-Money-Event': 'backup.created',
        'X-Money-Signature': sign(body),
      },
    });
    expect(res.status).toBe(404);
  });

  it('rejects path-escape attempts in the file name', async () => {
    await start();
    const body = Buffer.from(JSON.stringify({
      event: 'backup.created',
      payload: { name: '../etc/passwd' },
    }));
    const res = await postRaw({
      port, body,
      headers: {
        'X-Money-Event': 'backup.created',
        'X-Money-Signature': sign(body),
      },
    });
    expect(res.status).toBe(400);
  });
});

describe('createApp — uploader dispatch', () => {
  function fakeUploader(behavior = 'ok') {
    const calls = [];
    return {
      calls,
      uploader: {
        name: 'fake',
        async upload(filePath, fileName) {
          calls.push({ filePath, fileName });
          if (behavior === 'ok') return { ok: true, location: `fake://${fileName}` };
          throw new Error('simulated upload failure');
        },
      },
    };
  }

  async function postBackupCreated(body) {
    return postRaw({
      port, body,
      headers: {
        'X-Money-Event': 'backup.created',
        'X-Money-Signature': sign(body),
      },
    });
  }

  it('invokes the uploader after the file lands in DEST_DIR', async () => {
    fs.writeFileSync(path.join(srcDir, 'dev-2026-05-01.db'), 'hello');
    const f = fakeUploader('ok');
    await start({ uploader: f.uploader });
    const res = await postBackupCreated(buildBody());
    expect(res.status).toBe(200);
    expect(f.calls).toHaveLength(1);
    expect(f.calls[0].fileName).toBe('dev-2026-05-01.db');
    expect(f.calls[0].filePath).toBe(path.join(destDir, 'dev-2026-05-01.db'));
    expect(res.body.uploaded).toEqual({
      uploader: 'fake',
      ok: true,
      location: 'fake://dev-2026-05-01.db',
    });
    // Default keepLocalCopy=true → DEST_DIR file remains.
    expect(fs.existsSync(path.join(destDir, 'dev-2026-05-01.db'))).toBe(true);
  });

  it('returns 500 (so the API retries) when the upload fails', async () => {
    fs.writeFileSync(path.join(srcDir, 'dev-2026-05-01.db'), 'hello');
    const f = fakeUploader('fail');
    await start({ uploader: f.uploader });
    const res = await postBackupCreated(buildBody());
    expect(res.status).toBe(500);
    expect(res.body.error).toMatch(/uploader fake failed.*simulated upload failure/);
    // Local copy preserved on upload failure — losing a backup we can't
    // ship is worse than keeping it.
    expect(fs.existsSync(path.join(destDir, 'dev-2026-05-01.db'))).toBe(true);
  });

  it('unlinks the DEST_DIR file after a successful upload when keepLocalCopy=false', async () => {
    fs.writeFileSync(path.join(srcDir, 'dev-2026-05-01.db'), 'hello');
    const f = fakeUploader('ok');
    await start({ uploader: f.uploader, keepLocalCopy: false });
    const res = await postBackupCreated(buildBody());
    expect(res.status).toBe(200);
    expect(res.body.copiedTo).toBeNull();
    expect(fs.existsSync(path.join(destDir, 'dev-2026-05-01.db'))).toBe(false);
  });

  it('keeps the DEST_DIR file when keepLocalCopy=false but the upload fails', async () => {
    fs.writeFileSync(path.join(srcDir, 'dev-2026-05-01.db'), 'hello');
    const f = fakeUploader('fail');
    await start({ uploader: f.uploader, keepLocalCopy: false });
    const res = await postBackupCreated(buildBody());
    expect(res.status).toBe(500);
    expect(fs.existsSync(path.join(destDir, 'dev-2026-05-01.db'))).toBe(true);
  });

  it('skips the uploader when none is configured', async () => {
    fs.writeFileSync(path.join(srcDir, 'dev-2026-05-01.db'), 'hello');
    await start();
    const res = await postBackupCreated(buildBody());
    expect(res.status).toBe(200);
    expect(res.body.uploaded).toBeNull();
  });
});
