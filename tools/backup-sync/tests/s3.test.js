// Phase 4.11 — integration test for S3 PUT.
//
// Spins up a tiny HTTP stub on a local port, configures the S3 uploader
// to talk to it via S3_ENDPOINT + path-style addressing, then verifies
// the receiver issues a correctly shaped PUT — right URL, right
// Authorization header, right payload bytes.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { createS3Uploader } from '../s3.js';

let server;
let port;
const captured = []; // every request the stub sees

beforeAll(async () => {
  server = http.createServer((req, res) => {
    let body = Buffer.alloc(0);
    req.on('data', (chunk) => { body = Buffer.concat([body, chunk]); });
    req.on('end', () => {
      captured.push({
        method: req.method,
        url: req.url,
        host: req.headers.host,
        authorization: req.headers.authorization,
        amzDate: req.headers['x-amz-date'],
        amzContentSha256: req.headers['x-amz-content-sha256'],
        contentType: req.headers['content-type'],
        contentLength: req.headers['content-length'],
        body,
      });
      res.statusCode = 200;
      res.setHeader('etag', '"deadbeef-stub"');
      res.end();
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  port = server.address().port;
});

afterAll(async () => {
  await new Promise((resolve) => server.close(resolve));
});

function tmpFile(content) {
  const p = path.join(os.tmpdir(), `mc-s3-test-${Date.now()}-${Math.random().toString(36).slice(2)}.db`);
  fs.writeFileSync(p, content);
  return p;
}

describe('createS3Uploader — wire shape', () => {
  it('PUTs to <bucket>/<prefix>/<name> with a SigV4 Authorization header', async () => {
    captured.length = 0;
    const filePath = tmpFile(Buffer.from('hello world'));

    const uploader = createS3Uploader({
      bucket: 'my-bucket',
      region: 'us-east-1',
      accessKeyId: 'AKID',
      secretAccessKey: 'SECRET',
      endpoint: `http://127.0.0.1:${port}`,
      pathStyle: true,
      keyPrefix: 'mc/2026',
    });

    const result = await uploader.upload(filePath, 'dev-2026-05-01.db');
    expect(result.ok).toBe(true);
    expect(result.etag).toBe('"deadbeef-stub"');

    fs.unlinkSync(filePath);

    expect(captured).toHaveLength(1);
    const req = captured[0];
    expect(req.method).toBe('PUT');
    expect(req.url).toBe('/my-bucket/mc/2026/dev-2026-05-01.db');
    expect(req.host).toBe(`127.0.0.1:${port}`);
    expect(req.authorization).toMatch(
      /^AWS4-HMAC-SHA256 Credential=AKID\/\d{8}\/us-east-1\/s3\/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=[0-9a-f]{64}$/,
    );
    expect(req.amzDate).toMatch(/^\d{8}T\d{6}Z$/);
    expect(req.amzContentSha256).toBe(
      crypto.createHash('sha256').update('hello world').digest('hex'),
    );
    expect(req.contentType).toBe('application/octet-stream');
    expect(req.contentLength).toBe('11');
    expect(req.body.toString('utf8')).toBe('hello world');
  });

  it('omits the prefix segment when keyPrefix is empty', async () => {
    captured.length = 0;
    const filePath = tmpFile('x');

    const uploader = createS3Uploader({
      bucket: 'b',
      region: 'us-west-2',
      accessKeyId: 'AK',
      secretAccessKey: 'SK',
      endpoint: `http://127.0.0.1:${port}`,
      pathStyle: true,
    });

    await uploader.upload(filePath, 'a.db');
    fs.unlinkSync(filePath);

    expect(captured[0].url).toBe('/b/a.db');
  });

  it('throws on missing required config at construction time', () => {
    expect(() => createS3Uploader({ region: 'us-east-1' })).toThrow(/bucket/);
    expect(() => createS3Uploader({ bucket: 'b', accessKeyId: 'a', secretAccessKey: 's' })).toThrow(/region/);
    expect(() => createS3Uploader({ bucket: 'b', region: 'r', secretAccessKey: 's' })).toThrow(/accessKeyId/);
    expect(() => createS3Uploader({ bucket: 'b', region: 'r', accessKeyId: 'a' })).toThrow(/secretAccessKey/);
  });

  it('surfaces a non-2xx response as an error', async () => {
    // Spin up a separate server that always 403s.
    const failServer = http.createServer((_req, res) => {
      res.statusCode = 403;
      res.end('<Error><Code>SignatureDoesNotMatch</Code></Error>');
    });
    await new Promise((resolve) => failServer.listen(0, '127.0.0.1', resolve));
    const failPort = failServer.address().port;

    try {
      const filePath = tmpFile('x');
      const uploader = createS3Uploader({
        bucket: 'b',
        region: 'us-east-1',
        accessKeyId: 'AK',
        secretAccessKey: 'SK',
        endpoint: `http://127.0.0.1:${failPort}`,
        pathStyle: true,
      });
      await expect(uploader.upload(filePath, 'a.db')).rejects.toThrow(/S3 PUT 403/);
      fs.unlinkSync(filePath);
    } finally {
      await new Promise((resolve) => failServer.close(resolve));
    }
  });
});
