# 39 — Backup encryption key rotation

Phase 4.9 ships a built-in rotation flow for `BACKUP_ENCRYPTION_KEY`. One endpoint re-encrypts every existing `.enc` backup with a new key and rewrites `.env` so the next process boot uses it.

- Endpoint: `POST /api/admin/backups/rotate-encryption` (Super Admin only)
- Lib: [`backend/src/lib/backup.js`](../backend/src/lib/backup.js) — `rotateBackupEncryption(currentKey, newKey)`
- Env writer: [`backend/src/lib/env_writer.js`](../backend/src/lib/env_writer.js) — same helper that handles `DATABASE_URL` promotes, with timestamped backups under `.env-backups/`

## Request

```http
POST /api/admin/backups/rotate-encryption
Content-Type: application/json
Authorization: Bearer <super admin>

{ "newKey": "<32 random bytes, hex/base64/passphrase>" }
```

`newKey` is required; min length 16 chars; cannot match the current key.

## What runs

1. Sanity checks: current key set, new key non-empty + different.
2. For each `.enc` file in `backend/backups/`:
   - Decrypt to `<file>.rot-plain-<ts>` with **current** key.
   - Re-encrypt to `<file>.rot-enc-<ts>` with **new** key.
   - Atomically rename `<file>.rot-enc-<ts>` over the original.
   - Tmp files are cleaned in `finally` regardless of outcome.
3. **Only if every file succeeded**: write `BACKUP_ENCRYPTION_KEY=<newKey>` to `.env` (with timestamped backup) and return `{ ok: true, restartRequired: true }`.
4. **If any file failed**: return 500 with the rotated + failed lists; **`.env` is NOT updated** so the running process can still read the originals.

The "all-or-nothing" `.env` write is intentional. A partial rotation that updated `.env` would leave older files unreadable on the next boot.

## Response — success

```json
{
  "ok": true,
  "restartRequired": true,
  "rotated": ["dev-2026-04-30T...-pre-migration.db.enc", "dev-2026-05-01T...-month-end.db.enc"],
  "failed": [],
  "envBackup": ".env-backups/.env.2026-05-01T...",
  "message": "Re-encryption complete and .env updated. Restart the API process so the new key is used for future backups."
}
```

## Response — partial failure

```json
{
  "ok": false,
  "restartRequired": false,
  "rotated": ["a.db.enc"],
  "failed": [{ "name": "b.db.enc", "error": "Unsupported MCEB version: 7" }],
  "message": "Some backups failed to re-encrypt; .env was NOT updated so the running process can still read the originals."
}
```

Investigate `failed[].error` — common causes:
- File on disk isn't actually MCEB (someone dropped a foreign file in `backups/`).
- File was encrypted under an even older key the operator forgot about.
- I/O error mid-rotation.

Once you understand each failure, either:
- Move the bad files out of `backend/backups/`, then re-run rotation.
- Or, set the new key in `.env` manually (after handling the bad files out-of-band).

## Audit + system log

- Successful rotation: `audit_logs.action = 'rotate_encryption'` with `metadata: { rotated, backupPath }`.
- Partial failure: `audit_logs.action = 'rotate_encryption_partial'`.
- System log entries at `level: 'warn'` (success — needs restart) or `level: 'error'` (partial failure).

## Restart workflow

```bash
# from the host running the API
pm2 restart tatbeeqx      # or `nssm restart TatbeeqX`, or your service manager
```

After restart:

- New backups encrypt with the new key.
- Existing `.enc` files (just re-encrypted) decrypt with the new key.
- The previous key is no longer needed — wipe it from your password manager once you've verified a fresh backup + restore round-trip.

## Tests

[`tests/backup_encryption.test.js`](../backend/tests/backup_encryption.test.js):

- `rotateBackupEncryption` rotates an `.enc` file from one key to another. After rotation, decrypt with the new key succeeds and decrypt with the old key fails.
- Rejects when keys are missing or identical.

## Caveats

- **Wall time scales with N × file size.** Rotation reads + re-encrypts every file. For a fleet with 100 GB of historical backups, plan for several minutes of CPU.
- **Single-instance only.** If you have two API replicas pointed at the same storage, take one offline for the rotation. The other could otherwise read a half-rotated file (very narrow window — the rename is atomic — but possible).
- **Key history is your responsibility.** TatbeeqX doesn't keep a key history. If you want to read very old backups, store every key you've ever used and pass it explicitly to `decryptBackupToWithKey(file, dest, oldKey)` from a one-off script.
