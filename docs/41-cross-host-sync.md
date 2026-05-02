# 41 — Cross-host backup sync

Phase 4.10 lifts the shared-filesystem assumption from [40-offsite-sync.md](40-offsite-sync.md). The receiver tool can now pull a backup over HTTPS using a pre-signed URL embedded in the `backup.created` webhook payload.

- API endpoint: `GET /api/admin/backups/:name/download`
- Lib: [`backend/src/lib/backup.js`](../backend/src/lib/backup.js) — `signDownloadUrl()`, `verifyDownloadSignature()`
- Receiver: [`tools/backup-sync/receiver.js`](../tools/backup-sync/receiver.js) — automatically uses HTTPS pull when SRC_DIR is unreachable, or always when `PULL_VIA_HTTP=1`

## When you need this

The Phase 4.9 receiver assumed it shared a filesystem with the API. That's fine for `docker compose` deployments where both processes mount the same volume — and for LAN setups where the receiver runs on the same host. But a typical cloud topology has the API on one machine and the off-site uploader on another. Before Phase 4.10, the operator had to NFS-mount or rsync `backups/` to bridge the gap.

Now: the API webhook payload includes a `downloadUrl` that the receiver fetches directly. No shared filesystem required.

## Wire format additions

```jsonc
{
  "event": "backup.created",
  "occurredAt": "2026-05-01T10:15:00.000Z",
  "payload": {
    "name": "dev-2026-05-01T10-15-00-month-end.db.enc",
    "path": "/app/backups/dev-2026-05-01T10-15-00-month-end.db.enc",
    "size": 2_457_600,
    "createdAt": "2026-05-01T10:15:00.000Z",
    "provider": "sqlite",
    "encrypted": true,
    "downloadUrl": "https://api.example.com/api/admin/backups/dev-...db.enc?expires=1714560000&sig=..."
  }
}
```

`downloadUrl` is `null` when `BACKUP_DOWNLOAD_SECRET` isn't set on the API.

## Configuration

### On the API

```ini
# .env on the API host
BACKUP_DOWNLOAD_SECRET=<32+ chars; openssl rand -hex 32 is ideal>
BACKUP_PUBLIC_URL=https://api.example.com   # optional but recommended; embedded in downloadUrl
```

`BACKUP_PUBLIC_URL` should be how *the receiver* sees the API. Default behaviour without it is to emit a relative URL — fine for same-network deployments where the receiver constructs the absolute URL from another env var, awkward otherwise.

### On the receiver

```bash
WEBHOOK_SECRET=<paste from /webhooks UI>
DEST_DIR=/mnt/backups-offsite
PULL_VIA_HTTP=1                               # optional; force HTTP even if SRC_DIR works
```

That's it — no separate `BACKUP_DOWNLOAD_SECRET` on the receiver. The signature is verified server-side; the receiver just follows the URL it was handed.

## Auth model

The download endpoint accepts two flavours of auth:

| Caller | Auth | Path |
|---|---|---|
| TatbeeqX UI (operator clicks "Download" from `/backups`) | `Bearer <access token>`, must be Super Admin | inline JWT verify in the route |
| Off-site sync receiver | `?expires&sig` query params, signed with `BACKUP_DOWNLOAD_SECRET` | inline HMAC verify |

The route is mounted **before** the global `authenticate` middleware so signed-URL requests don't fail the JWT check. Both paths require Super Admin authority — for signed URLs, the API has already gated the signing key behind a Super-Admin-controlled env var.

## Signature scheme

```
payload   = "<name>.<unix-expires>"
signature = HMAC-SHA256(BACKUP_DOWNLOAD_SECRET, payload).hex
url       = BASE_URL + "/api/admin/backups/" + encodeURIComponent(name)
            + "?expires=" + unix-expires
            + "&sig=" + signature
```

The verifier uses Node's `timingSafeEqual` for the compare. `expires` is checked against wall-clock; URLs older than the embedded timestamp are rejected.

Default TTL: **1 hour**. Configurable per-call via `signDownloadUrl(name, baseUrl, ttlSeconds)`. Webhook deliveries always use the default — the receiver pulls within seconds of receipt, so an hour is plenty.

## Receiver mode selection

Each request:

1. If `PULL_VIA_HTTP=1` → HTTPS pull.
2. Else if `<SRC_DIR>/<name>` exists → shared-filesystem copy.
3. Else if `payload.downloadUrl` is present → HTTPS pull.
4. Else → 404 with a hint that `BACKUP_DOWNLOAD_SECRET` must be set on the API.

The `else` ladder lets a single receiver flip between modes without restart — a deployment that loses its NFS mount keeps working as long as the API is emitting `downloadUrl`s.

## Tests

[`tests/signed_url.test.js`](../backend/tests/signed_url.test.js) covers:

- `isDownloadSigningEnabled` requires a 16+ char secret.
- `signDownloadUrl` returns null when signing is disabled.
- Round-trip: signed URL → `verifyDownloadSignature` returns true.
- Expired signature → false (constructed manually since the helper clamps to a 60s minimum).
- Mismatched name (path attack) → false.
- Tampered signature → false.
- Verify-time disable → false.

## Caveats

- **TLS is your responsibility.** The API ships HTTP by default. Put nginx / Caddy / a cloud LB in front of it before exposing `BACKUP_PUBLIC_URL` to the public internet. Encrypted backups (`MCEB`) are still protected by their AES-GCM tag, but plaintext `.sql` dumps from `pg_dump` ride this URL in the clear.
- **Signed URL leakage.** Anyone holding a valid `?sig=` URL can download the file until the expiry. Don't paste them in chat. The 1-hour default minimizes blast radius.
- **The `path` field in the payload is the API-side path** — useful for debugging, never used by the receiver.
- **No retry inside the receiver's HTTP pull.** A failed `fetch()` returns 5xx, which makes TatbeeqX retry the whole webhook (3 attempts). On the second/third try, the receiver retries the pull. Network blips self-heal.
