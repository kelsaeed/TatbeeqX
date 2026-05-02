// S3 (and S3-compatible) uploader.
//
// Hand-rolled AWS Signature V4 over native fetch. Zero new dependencies —
// preserves the receiver's "minimal deps" ethos. PUT-only path; we don't
// implement listing, multipart, or signed-URL generation here.
//
// Compatible with:
//   - AWS S3 (any region)
//   - Backblaze B2's S3-compatible endpoint
//   - Wasabi
//   - MinIO (set S3_PATH_STYLE=1)
//   - Cloudflare R2
//
// References:
//   - SigV4 spec: https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html
//   - S3 PUT object: https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html

import crypto from 'node:crypto';
import fs from 'node:fs';

const SIGV4_ALGORITHM = 'AWS4-HMAC-SHA256';
// Default for S3 PUT — S3 requires x-amz-content-sha256 to be signed.
const DEFAULT_SIGNED_HEADERS = ['host', 'x-amz-content-sha256', 'x-amz-date'];

function sha256Hex(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function hmac(key, value) {
  return crypto.createHmac('sha256', key).update(value).digest();
}

function deriveSigningKey(secretAccessKey, dateStamp, region, service) {
  const kDate = hmac(`AWS4${secretAccessKey}`, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  return hmac(kService, 'aws4_request');
}

// SigV4 requires path-segment URI-encoding that does NOT encode "/". The
// only RFC-3986 unreserved chars stay literal: A-Z a-z 0-9 - _ . ~
function encodeUriPath(p) {
  return p.split('/').map((seg) => encodeURIComponent(seg).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`)).join('/');
}

function buildCanonicalRequest({ method, path, payloadHash, host, amzDate, signedHeaders }) {
  // Build per-header canonical lines for the requested set. Lower-cased
  // names, sorted alphabetically. We only support the small set of
  // headers we actually sign — adding more requires looking up the
  // value from a request-header map.
  const headerValues = {
    host,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
  };
  const canonicalHeaders = signedHeaders
    .map((h) => `${h}:${headerValues[h]}`)
    .join('\n') + '\n';
  return [
    method,
    encodeUriPath(path),
    '', // empty query string (we never sign with one)
    canonicalHeaders,
    signedHeaders.join(';'),
    payloadHash,
  ].join('\n');
}

// Build an AWS-style timestamp (YYYYMMDD'T'HHMMSS'Z') from a Date.
export function awsTimestamp(date = new Date()) {
  const iso = date.toISOString();
  return iso.replace(/[:-]/g, '').replace(/\.\d{3}/, '');
}

// Compute the SigV4 signature + Authorization header for a PUT request.
// Exposed (not just used internally) so tests can pin against the AWS
// SigV4 test vectors.
export function signRequest({
  method,
  path,
  payloadHash,
  host,
  region,
  service,
  accessKeyId,
  secretAccessKey,
  date = new Date(),
  signedHeaders = DEFAULT_SIGNED_HEADERS,
}) {
  const amzDate = awsTimestamp(date);
  const dateStamp = amzDate.slice(0, 8);
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;

  const canonicalRequest = buildCanonicalRequest({
    method, path, payloadHash, host, amzDate, signedHeaders,
  });
  const stringToSign = [
    SIGV4_ALGORITHM,
    amzDate,
    credentialScope,
    sha256Hex(canonicalRequest),
  ].join('\n');

  const signingKey = deriveSigningKey(secretAccessKey, dateStamp, region, service);
  const signature = crypto.createHmac('sha256', signingKey).update(stringToSign).digest('hex');

  const authorization =
    `${SIGV4_ALGORITHM} Credential=${accessKeyId}/${credentialScope}, ` +
    `SignedHeaders=${signedHeaders.join(';')}, Signature=${signature}`;

  return { signature, authorization, amzDate, payloadHash };
}

function buildEndpoint(config, key) {
  // Default: virtual-hosted-style — bucket as a sub-domain.
  //   PUT https://<bucket>.s3.<region>.amazonaws.com/<key>
  // Path-style — bucket in the path. Required for many MinIO setups.
  //   PUT https://<host>/<bucket>/<key>
  const usePathStyle = config.pathStyle === true;
  const customEndpoint = config.endpoint;

  let baseHost;
  let basePath;
  let protocol = 'https:';

  if (customEndpoint) {
    const u = new URL(customEndpoint);
    protocol = u.protocol;
    baseHost = u.host; // includes :port if present
    if (usePathStyle) {
      basePath = `${u.pathname.replace(/\/$/, '')}/${config.bucket}`;
    } else {
      baseHost = `${config.bucket}.${u.host}`;
      basePath = u.pathname.replace(/\/$/, '');
    }
  } else {
    if (usePathStyle) {
      baseHost = `s3.${config.region}.amazonaws.com`;
      basePath = `/${config.bucket}`;
    } else {
      baseHost = `${config.bucket}.s3.${config.region}.amazonaws.com`;
      basePath = '';
    }
  }

  const path = `${basePath}/${key.replace(/^\//, '')}`;
  const url = `${protocol}//${baseHost}${path}`;
  return { url, host: baseHost, path };
}

function joinKey(prefix, name) {
  if (!prefix) return name;
  return `${prefix.replace(/\/$/, '')}/${name}`;
}

export async function s3PutFile(filePath, key, config) {
  const stat = fs.statSync(filePath);
  // We compute the SHA-256 over the whole file in one pass. For the file
  // sizes TatbeeqX produces (a few MB to a few GB at the high end),
  // that's acceptable. If we ever need to handle 10s of GB we'd want
  // multipart upload; flag in the README for now.
  const body = fs.readFileSync(filePath);
  const payloadHash = sha256Hex(body);

  const { url, host, path } = buildEndpoint(config, key);

  const { authorization, amzDate } = signRequest({
    method: 'PUT',
    path,
    payloadHash,
    host,
    region: config.region,
    service: 's3',
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
  });

  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      'Host': host,
      'X-Amz-Date': amzDate,
      'X-Amz-Content-Sha256': payloadHash,
      'Authorization': authorization,
      'Content-Type': 'application/octet-stream',
      'Content-Length': String(stat.size),
    },
    body,
    // Fail fast — if S3 is down the API will retry the webhook.
    signal: AbortSignal.timeout(120_000),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`S3 PUT ${res.status}: ${text.slice(0, 500)}`);
  }
  return { url, etag: res.headers.get('etag') || null };
}

export function createS3Uploader(config) {
  // Validate up-front so we fail at startup, not on the first webhook.
  for (const k of ['bucket', 'region', 'accessKeyId', 'secretAccessKey']) {
    if (!config[k]) throw new Error(`S3 uploader requires ${k}`);
  }
  return {
    name: 's3',
    async upload(filePath, fileName) {
      const key = joinKey(config.keyPrefix || '', fileName);
      const { url, etag } = await s3PutFile(filePath, key, config);
      return { ok: true, location: url, etag };
    },
  };
}
