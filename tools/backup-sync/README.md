# backup-sync

Standalone Node service that listens for TatbeeqX's `backup.created` webhook, copies the referenced backup file to a destination directory, and (Phase 4.11) optionally uploads it to S3 / restic in one hop.

See [docs/40-offsite-sync.md](../../docs/40-offsite-sync.md) for the full setup guide.

## Quickstart

### Default (copy only — pair with rclone/restic on the side)

```bash
cd tools/backup-sync
npm install
WEBHOOK_SECRET=<paste from TatbeeqX's /webhooks UI> \
  DEST_DIR=/mnt/backups-offsite \
  npm start
```

### With native S3 upload (Phase 4.11)

```bash
WEBHOOK_SECRET=...                 \
  DEST_DIR=/mnt/staging            \
  UPLOADER=s3                      \
  S3_BUCKET=my-tatbeeqx-backups \
  S3_REGION=us-east-1              \
  S3_ACCESS_KEY_ID=AKID...         \
  S3_SECRET_ACCESS_KEY=...         \
  S3_KEY_PREFIX=mc/2026            \
  KEEP_LOCAL_COPY=0                \
  npm start
```

### With native restic backup (Phase 4.11)

```bash
WEBHOOK_SECRET=...                 \
  DEST_DIR=/mnt/staging            \
  UPLOADER=restic                  \
  RESTIC_REPOSITORY=s3:s3.amazonaws.com/my-bucket \
  RESTIC_PASSWORD=...              \
  npm start
```

Then in TatbeeqX's `/webhooks`, create a subscription pointing to `http://<this-host>:4100/hook` with events `["backup.created"]` (or `["*"]`). TatbeeqX reveals the secret once on create — paste it into `WEBHOOK_SECRET` here.

## Configuration

Required:

| Var | Notes |
|---|---|
| `WEBHOOK_SECRET` | Matches the `secret` on the matching TatbeeqX `WebhookSubscription`. |
| `DEST_DIR` | Absolute path; auto-created if missing. With `KEEP_LOCAL_COPY=0` this is just staging. |

Optional:

| Var | Default | Notes |
|---|---|---|
| `PORT` | `4100` | Listen port |
| `SRC_DIR` | `<repo>/backend/backups` | Path to the API's backups dir (shared-fs mode) |
| `PULL_VIA_HTTP` | `0` | `1` forces HTTPS pull mode even if SRC_DIR works |
| `UPLOADER` | `none` | `none`, `s3`, or `restic` |
| `KEEP_LOCAL_COPY` | `1` | `0` = unlink the DEST_DIR file after a successful upload |

S3 (when `UPLOADER=s3`):

| Var | Required | Notes |
|---|---|---|
| `S3_BUCKET` | yes | |
| `S3_REGION` | yes | E.g. `us-east-1`, `eu-west-2`. |
| `S3_ACCESS_KEY_ID` | yes | |
| `S3_SECRET_ACCESS_KEY` | yes | |
| `S3_ENDPOINT` | no | Custom endpoint URL — set this for B2 / Wasabi / MinIO / R2. |
| `S3_KEY_PREFIX` | no | Prefix prepended to the file name as the object key. |
| `S3_PATH_STYLE` | no | `1` forces path-style addressing (required for many MinIO setups). |

Restic (when `UPLOADER=restic`):

| Var | Required | Notes |
|---|---|---|
| `RESTIC_REPOSITORY` | yes | E.g. `s3:s3.amazonaws.com/my-bucket`, `b2:bucket-name`, `local:/path/to/repo`. |
| `RESTIC_PASSWORD` | yes | Plaintext for now — keep it in a secret store, not a checked-in file. |
| `RESTIC_BIN` | no | Default `restic`. Set if not on PATH. |

The receiver uses `process.env` for restic, so any restic-specific env vars (`AWS_ACCESS_KEY_ID` for an `s3:` repo, `B2_ACCOUNT_ID` for `b2:`, etc.) are picked up automatically.

## Why standalone?

- Keeps TatbeeqX's dependency footprint small.
- Lets each install pick its own off-site target (S3, B2, restic, rsync, etc.).
- The API retries the webhook up to 3 times on 5xx, so this receiver is robust to brief restarts.

## What about the rclone / restic CLI hand-off?

You no longer need it for the two most common targets — the receiver speaks S3 SigV4 natively (no AWS SDK dep, just hand-rolled SigV4 over `fetch`) and shells out to `restic` directly. The `DEST_DIR` → external-uploader pattern is still supported (`UPLOADER=none`) when your target is something else (B2 native API, Azure Blob CLI, rsync over ssh, etc.).

## Verifying the signature

Every request includes:

```
X-Money-Signature: sha256=<hex>
X-Money-Event:     backup.created
X-Money-Attempt:   1..3
```

The signature is `HMAC-SHA256(WEBHOOK_SECRET, raw-body-bytes)`. The receiver uses Node's `timingSafeEqual` for the compare. For non-Node receivers, see [`tools/webhook-verify/`](../webhook-verify/) for stdlib-only Python / Go / PHP / Bash helpers.

## Tests

```bash
cd tools/backup-sync
npm test
```

Covers SigV4 against AWS's published `get-vanilla` test vector, S3 PUT shape against a local HTTP stub, restic dispatch via injected `spawn`, and the receiver's signature/acquisition/upload code paths via supertest. 28 tests at the time of writing.

## Failure modes

- **Bad signature** → `401`. TatbeeqX retries up to 3 times then gives up; check the secret.
- **Path escape attempt** → `400`. The file name in the payload must match `[A-Za-z0-9._-]+`.
- **Source file missing + no `downloadUrl`** → `404`. Either ensure the receiver shares a filesystem with `backend/backups/`, or set `BACKUP_DOWNLOAD_SECRET` on the API so the webhook payload includes a signed pull URL.
- **Upload failure** (S3 5xx, restic non-zero exit) → `500`. The API retries with backoff. The local `DEST_DIR` copy is preserved even with `KEEP_LOCAL_COPY=0`, so a failed upload doesn't lose the backup.
- **Restic binary missing at startup** → process exits with `FATAL: ...` before binding the port. Won't accept webhooks until restic is installed.
