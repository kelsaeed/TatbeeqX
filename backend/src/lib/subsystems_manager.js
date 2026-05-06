// Phase 4.20 (Phase 2) — Subsystems Manager.
//
// Lets the running studio (the dev TatbeeqX install) register, launch,
// and stop locked-down subsystem bundles produced by
// `tools/build-subsystem`. Useful when running multiple subsystems on
// one machine for a demo.
//
// Registry lives at `<APPDATA>/TatbeeqX/subsystems.json` so it persists
// across studio restarts. PID tracking is best-effort: we save the
// PIDs we spawned and check `kill(pid, 0)` to decide alive/dead. If
// the user kills the .exe with the X button, our next status read sees
// a dead PID and reports "stopped" — no daemon needed.
//
// Process model: we spawn `node src/server.js` (cwd=<bundle>/backend)
// and the bundle's `<name>.exe` (cwd=<bundle>/app) directly, NOT via
// start.bat. Direct spawn means we get clean PIDs to track. We
// replicate start.bat's first-boot behavior (npm install, prisma
// migrate deploy, prisma seed) on the first start of a bundle.
//
// This module is Windows-only by intent — the bundles it manages are
// Windows .exe builds. Cross-platform support would need a parallel
// impl for Linux/macOS. None today.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn, spawnSync } from 'node:child_process';
import crypto from 'node:crypto';

const APPDATA_DIR = process.env.APPDATA
  || path.join(os.homedir(), 'AppData', 'Roaming');
const REGISTRY_DIR = path.join(APPDATA_DIR, 'TatbeeqX');
const REGISTRY_FILE = path.join(REGISTRY_DIR, 'subsystems.json');

function ensureRegistryDir() {
  if (!fs.existsSync(REGISTRY_DIR)) fs.mkdirSync(REGISTRY_DIR, { recursive: true });
}

function readRegistry() {
  ensureRegistryDir();
  if (!fs.existsSync(REGISTRY_FILE)) return { items: [] };
  try {
    const raw = fs.readFileSync(REGISTRY_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.items)) return { items: [] };
    return parsed;
  } catch {
    // Corrupted registry — return empty rather than crashing.
    // start-from-scratch is recoverable; the user can re-add bundles.
    return { items: [] };
  }
}

function writeRegistry(reg) {
  ensureRegistryDir();
  fs.writeFileSync(REGISTRY_FILE, JSON.stringify(reg, null, 2), 'utf8');
}

// Lightweight `.env` parser. We only need PORT; ignore quoting edge
// cases and multiline values. Returns an object of trimmed string
// values; missing keys are undefined.
function parseEnvFile(filePath) {
  const out = {};
  if (!fs.existsSync(filePath)) return out;
  const raw = fs.readFileSync(filePath, 'utf8');
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"'))
      || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    out[key] = value;
  }
  return out;
}

// Probe a bundle directory and return a normalized layout summary.
// Throws an HTTP-friendly Error if the dir doesn't look like a bundle
// (caller wraps as 400).
export function inspectBundle(bundleDir) {
  const abs = path.resolve(bundleDir);
  if (!fs.existsSync(abs) || !fs.statSync(abs).isDirectory()) {
    throw new Error(`Not a directory: ${abs}`);
  }
  const backendDir = path.join(abs, 'backend');
  const appDir = path.join(abs, 'app');
  if (!fs.existsSync(backendDir)) {
    throw new Error(`Missing backend/ in bundle: ${abs}`);
  }
  const envPath = path.join(backendDir, '.env');
  const env = parseEnvFile(envPath);
  const port = Number(env.PORT);
  if (!Number.isFinite(port) || port < 1 || port > 65535) {
    throw new Error(`Bundle .env has no valid PORT: ${envPath}`);
  }
  // Find the .exe in app/. Bundles have exactly one branded .exe;
  // pick the first .exe as the entrypoint.
  let exePath = null;
  if (fs.existsSync(appDir) && fs.statSync(appDir).isDirectory()) {
    const exes = fs.readdirSync(appDir).filter((f) => f.toLowerCase().endsWith('.exe'));
    if (exes.length > 0) exePath = path.join(appDir, exes[0]);
  }
  // Read seed.json's branding for a friendly default name.
  let suggestedName = path.basename(abs);
  const seedPath = path.join(abs, 'seed.json');
  if (fs.existsSync(seedPath)) {
    try {
      const seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
      const appName = seed?.branding?.appName;
      if (typeof appName === 'string' && appName.trim()) {
        suggestedName = appName.trim();
      }
    } catch { /* ignore */ }
  }
  return {
    bundleDir: abs,
    backendDir,
    appDir,
    envPath,
    exePath,
    port,
    suggestedName,
  };
}

// Best-effort liveness check. `kill(pid, 0)` doesn't deliver a signal
// on Windows — Node's libuv translates it to OpenProcess() with a
// permission probe, throwing if the process doesn't exist. So a thrown
// error here means "dead PID"; success means "still around".
function isPidAlive(pid) {
  if (!pid || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function computeStatus(item) {
  const backendAlive = isPidAlive(item.backendPid);
  const exeAlive = isPidAlive(item.exePid);
  if (backendAlive && exeAlive) return 'running';
  if (backendAlive || exeAlive) return 'partial';
  return 'stopped';
}

function toDto(item) {
  return {
    id: item.id,
    name: item.name,
    bundleDir: item.bundleDir,
    port: item.port,
    backendPid: item.backendPid ?? null,
    exePid: item.exePid ?? null,
    lastStartedAt: item.lastStartedAt ?? null,
    lastStoppedAt: item.lastStoppedAt ?? null,
    status: computeStatus(item),
  };
}

export function listSubsystems() {
  const reg = readRegistry();
  return reg.items.map(toDto);
}

export function getSubsystem(id) {
  const reg = readRegistry();
  const item = reg.items.find((s) => s.id === id);
  return item ? toDto(item) : null;
}

export function registerSubsystem({ name, bundleDir }) {
  const info = inspectBundle(bundleDir);
  const reg = readRegistry();
  const existing = reg.items.find((s) => s.bundleDir === info.bundleDir);
  if (existing) {
    throw new Error(`Bundle already registered: ${info.bundleDir}`);
  }
  const item = {
    id: crypto.randomBytes(6).toString('hex'),
    name: (name && String(name).trim()) || info.suggestedName,
    bundleDir: info.bundleDir,
    port: info.port,
    backendPid: null,
    exePid: null,
    lastStartedAt: null,
    lastStoppedAt: null,
  };
  reg.items.push(item);
  writeRegistry(reg);
  return toDto(item);
}

export function unregisterSubsystem(id) {
  const reg = readRegistry();
  const idx = reg.items.findIndex((s) => s.id === id);
  if (idx === -1) return false;
  // Refuse to drop a row that's still running — the user should stop
  // it first so we don't orphan their PIDs (the kill button is gone
  // once the row is gone).
  const item = reg.items[idx];
  if (computeStatus(item) !== 'stopped') {
    throw new Error('Stop the subsystem before removing it');
  }
  reg.items.splice(idx, 1);
  writeRegistry(reg);
  return true;
}

// Mirror of start.bat's npm install + prisma migrate deploy + prisma
// seed. Runs synchronously so we don't return success until the
// backend has the runtime it needs to actually start. Each step is
// idempotent — re-running these on an already-bootstrapped bundle is
// a no-op (npm sees node_modules, prisma sees migrations applied).
function ensureBackendBootstrapped(backendDir) {
  const nodeModules = path.join(backendDir, 'node_modules');
  if (!fs.existsSync(nodeModules)) {
    const r = spawnSync('npm', ['install', '--omit=dev'], {
      cwd: backendDir,
      stdio: 'inherit',
      shell: true,
    });
    if (r.status !== 0) throw new Error('npm install failed');
  }
  const dbPath = path.join(backendDir, 'prisma', 'dev.db');
  if (!fs.existsSync(dbPath)) {
    let r = spawnSync('npx', ['prisma', 'migrate', 'deploy'], {
      cwd: backendDir,
      stdio: 'inherit',
      shell: true,
    });
    if (r.status !== 0) throw new Error('prisma migrate deploy failed');
    r = spawnSync('node', ['prisma/seed.js'], {
      cwd: backendDir,
      stdio: 'inherit',
      shell: true,
    });
    if (r.status !== 0) throw new Error('prisma seed failed');
  }
}

export async function startSubsystem(id) {
  const reg = readRegistry();
  const item = reg.items.find((s) => s.id === id);
  if (!item) throw new Error('Subsystem not found');
  if (computeStatus(item) === 'running') {
    return toDto(item);
  }
  const info = inspectBundle(item.bundleDir);
  // Refresh the port from .env in case the user edited it manually
  // since registration. The next port-reassignment endpoint (Phase 2c)
  // will rewrite the .env in-place; reading it fresh keeps that path
  // simple later.
  item.port = info.port;

  ensureBackendBootstrapped(info.backendDir);

  const apiBaseUrl = `http://localhost:${item.port}/api`;

  // Spawn the backend. `detached: true` + `unref()` lets the child
  // outlive the studio process if the studio crashes — avoids
  // zombie restarts. stdio is ignored to keep our event loop clean;
  // a future Phase 2 can pipe to log files.
  const backend = spawn('node', ['src/server.js'], {
    cwd: info.backendDir,
    env: { ...process.env, PORT: String(item.port) },
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
  });
  backend.unref();
  if (!backend.pid) {
    throw new Error('Failed to spawn backend (no PID)');
  }
  item.backendPid = backend.pid;

  // Tiny delay so the backend's listen() can land before the .exe
  // does its boot fetch. Matches start.bat's `timeout /t 2`.
  await new Promise((r) => setTimeout(r, 1500));

  if (info.exePath) {
    const gui = spawn(info.exePath, [], {
      cwd: info.appDir,
      env: { ...process.env, TATBEEQX_API_BASE_URL: apiBaseUrl },
      detached: true,
      stdio: 'ignore',
      windowsHide: false,
    });
    gui.unref();
    if (gui.pid) item.exePid = gui.pid;
  }

  item.lastStartedAt = new Date().toISOString();
  item.lastStoppedAt = null;
  writeRegistry(reg);
  return toDto(item);
}

// Force-kill via taskkill — Node's process.kill() doesn't reliably
// terminate Windows GUI processes, and SIGTERM has no Windows
// equivalent anyway. /F = force, /T = include child tree (catches
// the .exe's renderer subprocesses).
function taskkill(pid) {
  if (!pid) return;
  spawnSync('taskkill', ['/PID', String(pid), '/F', '/T'], {
    stdio: 'ignore',
    shell: false,
  });
}

export function stopSubsystem(id) {
  const reg = readRegistry();
  const item = reg.items.find((s) => s.id === id);
  if (!item) throw new Error('Subsystem not found');
  taskkill(item.backendPid);
  taskkill(item.exePid);
  item.backendPid = null;
  item.exePid = null;
  item.lastStoppedAt = new Date().toISOString();
  writeRegistry(reg);
  return toDto(item);
}

export const REGISTRY_PATH = REGISTRY_FILE;
