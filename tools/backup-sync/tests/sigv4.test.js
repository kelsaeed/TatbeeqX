// Phase 4.11 — pin our SigV4 implementation against AWS's published
// test vectors. If `signRequest()` ever drifts from the spec, this test
// catches it before any S3-compatible provider rejects our PUTs.

import { describe, it, expect } from 'vitest';
import crypto from 'node:crypto';
import { signRequest, awsTimestamp } from '../s3.js';

describe('signRequest — SigV4', () => {
  // AWS's canonical "get-vanilla" test vector.
  // https://docs.aws.amazon.com/general/latest/gr/sigv4_testsuite.html
  //
  //   GET /
  //   Host: example.amazonaws.com
  //   X-Amz-Date: 20150830T123600Z
  //
  //   Region:  us-east-1
  //   Service: service
  //   Access:  AKIDEXAMPLE
  //   Secret:  wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY
  //
  // Documented signature:
  //   5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31
  //
  // To match the vector exactly we override the default signed-header
  // set (which always includes x-amz-content-sha256 for S3 PUT) to just
  // [host, x-amz-date], the two headers the AWS vector signs.
  it('matches AWS get-vanilla published signature', () => {
    const result = signRequest({
      method: 'GET',
      path: '/',
      payloadHash: crypto.createHash('sha256').update('').digest('hex'),
      host: 'example.amazonaws.com',
      region: 'us-east-1',
      service: 'service',
      accessKeyId: 'AKIDEXAMPLE',
      secretAccessKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
      date: new Date(Date.UTC(2015, 7, 30, 12, 36, 0)),
      signedHeaders: ['host', 'x-amz-date'],
    });
    expect(result.signature).toBe(
      '5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31',
    );
  });

  it('Authorization header has the AWS4-HMAC-SHA256 shape', () => {
    const r = signRequest({
      method: 'PUT',
      path: '/foo/bar.db',
      payloadHash: crypto.createHash('sha256').update('hello').digest('hex'),
      host: 'mybucket.s3.us-east-1.amazonaws.com',
      region: 'us-east-1',
      service: 's3',
      accessKeyId: 'AKID',
      secretAccessKey: 'SECRET',
    });
    expect(r.authorization).toMatch(
      /^AWS4-HMAC-SHA256 Credential=AKID\/\d{8}\/us-east-1\/s3\/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=[0-9a-f]{64}$/,
    );
  });

  it('amzDate matches the AWS timestamp format', () => {
    expect(awsTimestamp(new Date(Date.UTC(2026, 4, 1, 12, 30, 45)))).toBe(
      '20260501T123045Z',
    );
  });

  it('different secret keys produce different signatures', () => {
    const base = {
      method: 'PUT',
      path: '/key',
      payloadHash: 'a'.repeat(64),
      host: 'bucket.s3.us-east-1.amazonaws.com',
      region: 'us-east-1',
      service: 's3',
      accessKeyId: 'AKID',
      date: new Date(Date.UTC(2026, 4, 1, 0, 0, 0)),
    };
    const a = signRequest({ ...base, secretAccessKey: 'secret-a' });
    const b = signRequest({ ...base, secretAccessKey: 'secret-b' });
    expect(a.signature).not.toBe(b.signature);
  });

  it('different paths produce different signatures', () => {
    const base = {
      method: 'PUT',
      payloadHash: 'a'.repeat(64),
      host: 'bucket.s3.us-east-1.amazonaws.com',
      region: 'us-east-1',
      service: 's3',
      accessKeyId: 'AKID',
      secretAccessKey: 'SECRET',
      date: new Date(Date.UTC(2026, 4, 1, 0, 0, 0)),
    };
    const a = signRequest({ ...base, path: '/a.db' });
    const b = signRequest({ ...base, path: '/b.db' });
    expect(a.signature).not.toBe(b.signature);
  });
});
