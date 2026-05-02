# 40 — Off-site backup sync

Phase 4.9 ships a tiny standalone Node service ([`tools/backup-sync/`](../tools/backup-sync/)) that listens for the `backup.created` webhook event and copies the referenced backup file to a destination directory on a different host or volume.

The receiver is intentionally separate from the API:

- Keeps the API's dependency footprint small (no S3 client, no rclone bindings).
- Lets each install pick its own off-site target without changing backend code.
- The API retries the webhook up to 3 times on 5xx, so the receiver is robust to brief restarts.

## Architecture

```
+----------------+   POST /hook (HMAC-signed)   +---------------+   copyFileSync   +-------------+
|  TatbeeqX | ───────────────────────────▶ | backup-sync   | ───────────────▶ |  DEST_DIR   |
|     API        |                              |  receiver     |                  | (off-site)  |
+----------------+                              +---------------+                  +-------------+
        │
        │  fs.copyFileSync (host filesystem)
        ▼
  backend/backups/   ←───── shared filesystem (mount, NFS, host dir, ...)
```

The receiver reads the file from a **shared filesystem** with the API. For LAN deployments and most container setups (where both processes mount the same volume), this is the simplest path. For deployments where the receiver runs on a different host, replace the `fs.copyFileSync` step with an HTTPS pull from a backup-fetch endpoint (see Caveats below).

## Setup

### 1. Install + run the receiver

```bash
cd tools/backup-sync
npm install
WEBHOOK_SECRET=<paste-from-tatbeeqx>  \
  DEST_DIR=/mnt/backups-offsite             \
  npm start
# [backup-sync] listening on :4100
```

Required env vars:

| Name | Notes |
|---|---|
| `WEBHOOK_SECRET` | matches the `secret` on the matching TatbeeqX `WebhookSubscription`. TatbeeqX reveals it once on create. |
| `DEST_DIR` | absolute path; auto-created if missing. |

Optional:

| Name | Default | Notes |
|---|---|---|
| `PORT` | `4100` | listen port |
| `SRC_DIR` | `<repo>/backend/backups` | path to the API's backups dir |

### 2. Subscribe in TatbeeqX

In the TatbeeqX UI: **Webhooks** → **New webhook**:

- URL: `http://<receiver-host>:4100/hook`
- Events: `["backup.created"]` (or `["*"]` if you want everything)
- Secret: leave blank to auto-generate, then paste the revealed secret into the receiver's `WEBHOOK_SECRET` env var.

### 3. (Optional) Use the built-in S3 / restic uploader (Phase 4.11)

The receiver can talk to S3 and restic directly, removing the rclone hand-off step. Set `UPLOADER=s3` or `UPLOADER=restic` on the receiver process:

```bash
# Native S3 — no AWS SDK dep, hand-rolled SigV4 PUT.
UPLOADER=s3 \
  S3_BUCKET=my-bucket S3_REGION=us-east-1 \
  S3_ACCESS_KEY_ID=AKID... S3_SECRET_ACCESS_KEY=... \
  S3_KEY_PREFIX=mc/2026 \
  KEEP_LOCAL_COPY=0 \
  npm start

# S3-compatible (B2 / Wasabi / MinIO / R2) — set S3_ENDPOINT, optionally S3_PATH_STYLE=1.
UPLOADER=s3 S3_ENDPOINT=https://s3.us-west-002.backblazeb2.com \
  S3_BUCKET=... S3_REGION=us-west-002 \
  S3_ACCESS_KEY_ID=... S3_SECRET_ACCESS_KEY=... \
  npm start

# Restic — repo can be local, sftp, s3:, b2:, etc. (anything restic supports).
UPLOADER=restic \
  RESTIC_REPOSITORY=s3:s3.amazonaws.com/my-bucket \
  RESTIC_PASSWORD=... \
  AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... \
  npm start
```

`KEEP_LOCAL_COPY=0` unlinks the `DEST_DIR` file after a successful upload, so disk usage stays bounded. On upload failure the local copy is preserved (better to keep a backup we couldn't ship than lose it).

The S3 path is implemented as hand-rolled SigV4 over native `fetch` — no new dependencies, ~200 LOC. Pinned against AWS's published test vectors. Restic is invoked via `spawn`; the binary must be on `PATH` (or set `RESTIC_BIN=/path/to/restic`).

### 3a. (Alternative) Hook an external uploader to `DEST_DIR`

If your target isn't S3 or restic, leave `UPLOADER=none` (default) and run your own uploader against `DEST_DIR`:

```bash
# Azure CLI
az storage blob sync -s /mnt/backups-offsite -c backups

# rsync over ssh
rsync -av /mnt/backups-offsite/ user@archive:/srv/backups/

# rclone to anything-it-supports
rclone sync /mnt/backups-offsite s3:my-bucket/backups --progress
```

A simple inotify/fswatch loop pointed at `DEST_DIR` is the natural pairing.

## Verifying the signature

The receiver uses Node's `timingSafeEqual` to compare:

```js
const expected = 'sha256=' + crypto.createHmac('sha256', SECRET)
  .update(rawBody)        // RAW BUFFER, not the parsed JSON
  .digest('hex');
```

A wrong / missing signature returns 401. A signature mismatch never logs — fail silently to avoid leaking timing info.

## What the API sends

The webhook payload for `backup.created`:

```json
{
  "event": "backup.created",
  "occurredAt": "2026-05-01T10:15:00.000Z",
  "payload": {
    "name": "dev-2026-05-01T10-15-00-month-end.db.enc",
    "path": "/app/backups/dev-2026-05-01T10-15-00-month-end.db.enc",
    "size": 2_457_600,
    "createdAt": "2026-05-01T10:15:00.000Z",
    "provider": "sqlite",
    "encrypted": true
  }
}
```

The receiver only uses `payload.name` (sanitized against a whitelist regex) — `path` is for human debugging.

## Logs

Successful copies print to stdout:

```
[backup-sync] copied dev-2026-05-01T10-15-00-month-end.db.enc → /mnt/backups-offsite/dev-2026-05-01T10-15-00-month-end.db.enc
```

The TatbeeqX side audits the dispatch (`webhook_deliveries` table) — the receiver doesn't have its own DB; logs are stdout.

## Caveats

- **Same-filesystem assumption.** The receiver does `fs.copyFileSync(src, dest)` against the API's `backups/`. For receivers on a different host, replace the copy with an authenticated HTTPS pull from an API endpoint that streams the file. We don't ship that endpoint today — file me an issue.
- **Encrypted backups stay encrypted.** The receiver doesn't decrypt; it just moves the bytes. If you want plaintext off-site, decrypt out-of-band with the `decryptBackupToWithKey` helper or run [`tools/backup-sync`](../tools/backup-sync/) inside the same trust boundary as the encryption key.
- **No retry on the receiver side.** TatbeeqX retries the webhook up to 3 times on 5xx. If all three fail, the file stays only in `backend/backups/` until the next backup. Persistent failures show up in `/webhooks` → deliveries history.
- **Authentication strength = secret strength.** Pick a 64-char hex secret. Don't reuse the secret across subscriptions.
