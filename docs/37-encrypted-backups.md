# 37 — Encrypted backups

Phase 4.8 adds optional AES-256-GCM encryption to the backup pipeline introduced in [33-backups.md](33-backups.md) / [36-native-backups.md](36-native-backups.md). When `BACKUP_ENCRYPTION_KEY` is set in the API environment, every backup is encrypted post-write and the plaintext is removed.

- Lib: [`backend/src/lib/backup.js`](../backend/src/lib/backup.js) — `encryptFileInPlace` (internal), `decryptBackupTo` (exported)
- Off-by-default: if the env var is unset, behavior is identical to Phase 4.7 (plaintext backups).

## Enabling

Set one env var on the API process:

```ini
BACKUP_ENCRYPTION_KEY=<key>
```

`<key>` accepts three formats:

| Format | Detection | Use case |
|---|---|---|
| 64 hex chars | regex `^[0-9a-fA-F]{64}$` | 32 raw bytes, generated with `openssl rand -hex 32` |
| 43–44 char base64 | regex match + decode == 32 bytes | for tools that emit base64 directly |
| Anything else | fallback | passphrase derived via PBKDF2-SHA256 (100k iters) using a per-backup salt |

The PBKDF2 path is convenient (a memorable passphrase works) but slower per backup and per restore. Hex is the right choice for production.

## On-disk format

Encrypted files are named `<original>.enc` and have this layout:

```
[magic 4B "MCEB"]
[version 1B = 0x01]
[salt 16B]              ← random, unique per backup
[iv 12B]                ← random, unique per backup
[authTag 16B]           ← AES-GCM authentication tag
[ciphertext...]
```

`MCEB` = TatbeeqX Encrypted Backup. Version 1 = AES-256-GCM with PBKDF2-SHA256 (100k iters) when the key is a passphrase, or direct key derivation when hex/base64.

The header is integrity-checked — `decryptBackupTo` rejects files that don't start with `MCEB` or that have a different version byte, before attempting any decrypt. The auth tag rejects tampered ciphertext.

## Restore flow (SQLite)

`POST /api/admin/backups/:name/restore` for an `.enc` file:

1. Reads the env var; if unset, returns `400 BACKUP_ENCRYPTION_KEY is not set`.
2. Disconnects Prisma (so the engine releases its file lock).
3. Decrypts to a `<dest>.restoring-<ts>` staging path.
4. Atomically renames staging onto the live DB.
5. Returns `restartRequired: true`.

The same restart caveat from [33-backups.md](33-backups.md) applies — the API process must restart so Prisma re-opens the new file.

For `pg_dump` / `mysqldump` `.sql.enc` backups, decrypt them on the host (out-of-process) before piping to `psql` / `mysql`:

```bash
# Use a small node script that calls decryptBackupTo, or implement the
# header parsing in your favorite language. The format is documented above.
```

## Rotating the key

Plain encryption — there's no built-in key rotation. To rotate:

1. Stand up a new env with the new `BACKUP_ENCRYPTION_KEY`.
2. Decrypt the old backups with the old key (out-of-process).
3. Re-encrypt with the new key (or just take fresh backups).
4. Switch the env var on the running API.
5. Delete the old-key backups once you're confident.

A native rotation endpoint is on the roadmap.

## Test coverage

[`tests/backup_encryption.test.js`](../backend/tests/backup_encryption.test.js):

- `decryptBackupTo` rejects when the env key is unset.
- `decryptBackupTo` rejects files that don't start with `MCEB`.
- `listBackups` flags `.enc` files with `encrypted: true` and detects the underlying kind (sqlite vs sql).
- Plain `.db` / `.sql` files come back with `encrypted: false`.

A full encrypt-then-decrypt round-trip test would have to call the internal `encryptFileInPlace` (not currently exported); it's gated on a real `createBackup()` call which needs the live DB. The two layers above (header rejection + listing flag) catch the common failure modes.

## Caveats

- **No streaming.** `encryptFileInPlace` reads the file, encrypts, then writes the header + ciphertext. For multi-GB databases this allocates RAM equal to the dump size. Acceptable for typical SQLite installs (≤ 200 MB); add a streaming path with a trailing footer when you outgrow that.
- **Key in env.** Loss of `BACKUP_ENCRYPTION_KEY` makes existing backups unreadable. Store the key in the same secret manager you use for `JWT_*_SECRET` and back it up out-of-band.
- **Webhook payload is plaintext.** `backup.created` events ([27-webhooks.md](27-webhooks.md)) include the file path + size + `encrypted: true|false`, but never the key. Receivers can re-upload the encrypted file as-is.
