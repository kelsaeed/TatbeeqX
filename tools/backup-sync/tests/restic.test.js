// Phase 4.11 — restic uploader tests.
//
// We can't assume restic is installed on every dev box, so we inject
// fake spawn / spawnSync functions and assert on the args + env we'd
// pass to the real binary.

import { describe, it, expect } from 'vitest';
import { EventEmitter } from 'node:events';
import { createResticUploader } from '../restic.js';

// A stub child process that emits the supplied stdout/stderr/exit code
// asynchronously, mimicking what `spawn` returns.
function fakeChild({ stdout = '', stderr = '', code = 0 } = {}) {
  const child = new EventEmitter();
  child.stdout = new EventEmitter();
  child.stderr = new EventEmitter();
  // Fire emissions on next tick so the listener attaches first.
  setImmediate(() => {
    if (stdout) child.stdout.emit('data', Buffer.from(stdout));
    if (stderr) child.stderr.emit('data', Buffer.from(stderr));
    child.emit('close', code);
  });
  return child;
}

const probeOk = () => ({ status: 0 });
const probeFail = () => ({ status: 1 });

describe('createResticUploader — validation', () => {
  it('throws when RESTIC_REPOSITORY is missing', () => {
    expect(() => createResticUploader({
      password: 'p',
      spawnSyncImpl: probeOk,
      spawnImpl: () => fakeChild(),
    })).toThrow(/RESTIC_REPOSITORY/);
  });

  it('throws when RESTIC_PASSWORD is missing', () => {
    expect(() => createResticUploader({
      repository: 'local:/tmp',
      spawnSyncImpl: probeOk,
      spawnImpl: () => fakeChild(),
    })).toThrow(/RESTIC_PASSWORD/);
  });

  it('throws when binary probe fails', () => {
    expect(() => createResticUploader({
      repository: 'local:/tmp',
      password: 'p',
      spawnSyncImpl: probeFail,
      spawnImpl: () => fakeChild(),
    })).toThrow(/Restic binary 'restic' not found/);
  });

  it('respects custom RESTIC_BIN in the error message', () => {
    expect(() => createResticUploader({
      repository: 'local:/tmp',
      password: 'p',
      bin: '/custom/restic',
      spawnSyncImpl: probeFail,
      spawnImpl: () => fakeChild(),
    })).toThrow(/'\/custom\/restic'/);
  });
});

describe('createResticUploader — upload', () => {
  it('spawns restic with the right args and env', async () => {
    const calls = [];
    const uploader = createResticUploader({
      repository: 's3:s3.amazonaws.com/my-bucket',
      password: 'super-secret',
      spawnSyncImpl: probeOk,
      spawnImpl: (bin, args, opts) => {
        calls.push({ bin, args, env: opts.env });
        return fakeChild({ stdout: 'snapshot abc12345 saved\n' });
      },
    });

    const result = await uploader.upload('/tmp/dev-2026-05-01.db', 'dev-2026-05-01.db');
    expect(result.ok).toBe(true);
    expect(result.snapshotId).toBe('abc12345');
    expect(result.location).toBe('s3:s3.amazonaws.com/my-bucket#abc12345');

    expect(calls).toHaveLength(1);
    expect(calls[0].bin).toBe('restic');
    expect(calls[0].args).toEqual(['backup', '/tmp/dev-2026-05-01.db']);
    expect(calls[0].env.RESTIC_REPOSITORY).toBe('s3:s3.amazonaws.com/my-bucket');
    expect(calls[0].env.RESTIC_PASSWORD).toBe('super-secret');
  });

  it('appends --tag flags for each configured tag', async () => {
    let captured;
    const uploader = createResticUploader({
      repository: 'local:/repo',
      password: 'p',
      tags: ['tatbeeqx', 'sqlite'],
      spawnSyncImpl: probeOk,
      spawnImpl: (_bin, args) => {
        captured = args;
        return fakeChild({ stdout: 'snapshot xyz7 saved' });
      },
    });
    await uploader.upload('/tmp/x.db', 'x.db');
    expect(captured).toEqual([
      'backup', '/tmp/x.db',
      '--tag', 'tatbeeqx',
      '--tag', 'sqlite',
    ]);
  });

  it('rejects with stderr included when restic exits non-zero', async () => {
    const uploader = createResticUploader({
      repository: 'local:/repo',
      password: 'p',
      spawnSyncImpl: probeOk,
      spawnImpl: () => fakeChild({
        code: 1,
        stderr: 'unable to open repository: stat /repo: no such file or directory',
      }),
    });
    await expect(uploader.upload('/tmp/x.db', 'x.db'))
      .rejects.toThrow(/exited 1.*no such file or directory/);
  });

  it('returns snapshotId=null when stdout doesn\'t include a snapshot ID', async () => {
    const uploader = createResticUploader({
      repository: 'local:/repo',
      password: 'p',
      spawnSyncImpl: probeOk,
      spawnImpl: () => fakeChild({ stdout: 'unexpected output format' }),
    });
    const result = await uploader.upload('/tmp/x.db', 'x.db');
    expect(result.snapshotId).toBeNull();
    expect(result.location).toBe('local:/repo#unknown');
  });
});
