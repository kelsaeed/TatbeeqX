// Restic uploader.
//
// Spawns the `restic` binary to back up the just-arrived file into the
// configured repository. We don't reimplement the restic protocol —
// restic does encryption, chunking, dedup, and repository-format work we
// have no business duplicating.
//
// Same pattern as `pg_dump` / `mysqldump` in `backend/src/lib/backup.js`:
// spawn, stream stderr, fail loudly with the binary's own error message
// if it exits non-zero.
//
// Restic itself reads its config from env vars (RESTIC_REPOSITORY,
// RESTIC_PASSWORD, plus provider-specific creds like AWS_ACCESS_KEY_ID
// for `s3:` repos). We pass `process.env` through verbatim so the
// operator can configure the repo any way they like.

import { spawn as defaultSpawn, spawnSync as defaultSpawnSync } from 'node:child_process';

export function probeBinary(bin, spawnSyncImpl = defaultSpawnSync) {
  try {
    const r = spawnSyncImpl(bin, ['version'], { stdio: 'ignore' });
    return r.status === 0;
  } catch (_) {
    return false;
  }
}

export function createResticUploader(config) {
  const bin = config.bin || 'restic';
  const spawnImpl = config.spawnImpl || defaultSpawn;
  const spawnSyncImpl = config.spawnSyncImpl || defaultSpawnSync;

  if (!config.repository) throw new Error('Restic uploader requires RESTIC_REPOSITORY');
  if (!config.password) throw new Error('Restic uploader requires RESTIC_PASSWORD');

  // Fail-fast: if the binary isn't on PATH, refuse to start. Better than
  // accepting webhooks for hours while every upload silently fails.
  if (!probeBinary(bin, spawnSyncImpl)) {
    throw new Error(
      `Restic binary '${bin}' not found on PATH or not executable. ` +
      `Install restic (https://restic.net/) or set RESTIC_BIN to its absolute path.`,
    );
  }

  const baseEnv = {
    ...process.env,
    RESTIC_REPOSITORY: config.repository,
    RESTIC_PASSWORD: config.password,
  };

  async function runRestic(args) {
    return new Promise((resolve, reject) => {
      let stderr = '';
      let stdout = '';
      let child;
      try {
        child = spawnImpl(bin, args, { env: baseEnv });
      } catch (err) {
        reject(new Error(`Could not spawn ${bin}: ${err.message}`));
        return;
      }
      child.stdout.on('data', (c) => { stdout += c.toString(); });
      child.stderr.on('data', (c) => { stderr += c.toString(); });
      child.on('error', (err) => reject(new Error(`${bin} error: ${err.message}`)));
      child.on('close', (code) => {
        if (code === 0) resolve({ stdout, stderr });
        else reject(new Error(`${bin} ${args.join(' ')} exited ${code}: ${stderr.slice(0, 1000)}`));
      });
    });
  }

  return {
    name: 'restic',
    async upload(filePath, _fileName) {
      // `restic backup <path>` snapshots the single file into the repo.
      // Any tags from config get appended (one --tag flag per tag).
      const args = ['backup', filePath];
      for (const tag of config.tags || []) {
        args.push('--tag', tag);
      }
      const { stdout } = await runRestic(args);
      // Restic prints "snapshot abc12345 saved" on success — extract the
      // short ID for the receiver's response/log.
      const match = stdout.match(/snapshot\s+([a-f0-9]+)\s+saved/i);
      return {
        ok: true,
        location: `${config.repository}#${match ? match[1] : 'unknown'}`,
        snapshotId: match ? match[1] : null,
      };
    },
  };
}

