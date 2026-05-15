#!/usr/bin/env node
// Phase 4.12 — build-subsystem CLI.
//
// Takes a TatbeeqX template JSON + an output dir, and produces a
// branded, locked-down customer build:
//
//   - Stages a working copy of `backend/` + `frontend/` to <out>/staging/
//   - Patches `frontend/windows/runner/Runner.rc` so the .exe shows the
//     branded name in Windows file properties
//   - Optionally replaces `frontend/windows/runner/resources/app_icon.ico`
//     when the template's `branding.iconPath` points at a local .ico
//   - Writes `<backend>/.env` with `SUBSYSTEM_LOCKDOWN=1` and
//     `BOOT_SEED_PATH=./seed.json`, plus a fresh DATABASE_URL
//   - Writes `<backend>/seed.json` with the template payload — the
//     backend's first-boot seeder picks it up on first start
//   - Runs `flutter build windows --release` (skip with --no-build)
//   - Packages everything into `<out>/<subsystem-name>/`, ready to ship
//
// The output is a folder with: `<name>.exe` (frontend), `backend/`
// directory, `start.bat` to launch both, and a `README.md`.
//
// Usage:
//   node tools/build-subsystem/build.mjs \
//     --template ./factory_v1.json \
//     --out ./dist \
//     [--name "Factory ABC"] \
//     [--source <path-to-tatbeeqx-repo>] \
//     [--no-build]

import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import { prune } from './prune.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Match the backend's hashPassword in src/lib/password.js. The hash is
// portable across bcryptjs versions, so the CLI hashes once and the
// boot seeder applies the hash directly — no plaintext ever lands on
// disk.
const BCRYPT_ROUNDS = 10;

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--template') out.template = argv[++i];
    else if (a === '--out') out.out = argv[++i];
    else if (a === '--name') out.name = argv[++i];
    else if (a === '--source') out.source = argv[++i];
    else if (a === '--admin-username') out.adminUsername = argv[++i];
    else if (a === '--admin-password') out.adminPassword = argv[++i];
    else if (a === '--admin-fullname') out.adminFullName = argv[++i];
    else if (a === '--admin-email') out.adminEmail = argv[++i];
    else if (a === '--port') out.port = Number(argv[++i]);
    else if (a === '--port-pool') out.portPool = argv[++i];
    else if (a === '--no-build') out.noBuild = true;
    else if (a === '--no-admin') out.noAdmin = true;
    else if (a === '--prune') out.prune = true;
    else if (a === '--help' || a === '-h') out.help = true;
  }
  return out;
}

function help() {
  console.log(`
build-subsystem — package a branded, locked-down TatbeeqX binary
                  from a template JSON.

Required:
  --template <file>     Path to template JSON (full or business kind).
  --out <dir>           Where to write the staging + final bundle.
  --admin-password <p>  Password for the customer's Company Admin user.
                        Hashed with bcrypt (rounds=10) before being
                        written to seed.json — no plaintext ever lands
                        on disk. Skip this with --no-admin if you want
                        to handle admin provisioning manually.

Optional:
  --name <string>       Override the subsystem name (defaults to the
                        template's branding.appName, then "subsystem").
  --admin-username <u>  Default: "admin".
  --admin-fullname <n>  Default: "Administrator".
  --admin-email <e>     Default: "<username>@subsystem.local".
  --source <dir>        Path to the TatbeeqX repo. Defaults to the
                        script's grandparent.
  --no-build            Skip "flutter build windows --release".
  --prune               Phase 4.16 — strip optional modules NOT listed
                        in template.modules from the staged copy before
                        the Flutter build. Removes route imports, app
                        router entries, and orphaned feature dirs.
                        Core/infra modules are always kept. See
                        tools/build-subsystem/prune.mjs.
  --no-admin            Don't bake an admin user into the seed. The
                        seeded "superadmin" is left active — use this
                        only if you'll provision the customer's admin
                        manually before handover.
  --port <n>            Bake a single port into backend/.env and the
                        Flutter app's API_BASE_URL. start.bat will only
                        ever try this port. Default: 4040.
  --port-pool <a-b>     Bake a port range (e.g. 4040-4050). Build-time:
                        scan the build host and use the first free port
                        in the range as the primary. Runtime: start.bat
                        scans the same range on the customer host and
                        falls through to the next free port if the
                        primary is busy. Use this when running multiple
                        subsystems side-by-side on one machine.

Outputs:
  <out>/staging/      Working copy of backend + frontend (patched).
  <out>/<name>/       Final bundle: backend/, <name>.exe, start.bat,
                      README.md, seed.json.
`);
}

function logStep(msg) { console.log(`\n▸ ${msg}`); }

function ensureDir(d) { if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true }); }

function copyTree(src, dest, opts = {}) {
  const skipDirs = new Set(opts.skipDirs || []);
  ensureDir(dest);
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (skipDirs.has(entry.name)) continue;
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) copyTree(s, d, opts);
    else if (entry.isFile()) fs.copyFileSync(s, d);
  }
}

function safeName(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 50) || 'subsystem';
}

// Phase 4.20 — port management helpers.
//
// `--port-pool 4040-4050` parses to [4040..4050]. `--port 4040` parses
// to [4040]. With no flag we default to [4040] (a single port, no
// fallback) to preserve the shipping default — customers don't expect
// the bundle to silently bind a different port if 4040 is taken.
function parsePortPool(args) {
  if (args.port != null) {
    if (!Number.isFinite(args.port) || args.port < 1 || args.port > 65535) {
      throw new Error(`--port must be 1..65535, got: ${args.port}`);
    }
    return [args.port];
  }
  if (args.portPool) {
    const m = String(args.portPool).match(/^(\d+)\s*-\s*(\d+)$/);
    if (!m) throw new Error(`--port-pool must be "<low>-<high>", got: ${args.portPool}`);
    const lo = Number(m[1]);
    const hi = Number(m[2]);
    if (lo < 1 || hi > 65535 || lo > hi) {
      throw new Error(`--port-pool out of range or inverted: ${args.portPool}`);
    }
    const out = [];
    for (let p = lo; p <= hi; p++) out.push(p);
    return out;
  }
  return [4040];
}

function isPortFree(port) {
  return new Promise((resolve) => {
    const srv = net.createServer();
    srv.once('error', () => resolve(false));
    srv.once('listening', () => srv.close(() => resolve(true)));
    srv.listen(port, '127.0.0.1');
  });
}

async function pickPrimaryPort(pool) {
  for (const p of pool) {
    if (await isPortFree(p)) return p;
  }
  // Whole pool busy on the build host — fall back to the first port
  // anyway. Runtime fallback in start.bat will retry on the customer
  // host, where the picture may differ.
  return pool[0];
}

function patchRunnerRc(rcPath, brandedName, productName) {
  let txt = fs.readFileSync(rcPath, 'utf8');
  // Field replacements — the template values are seeded by Flutter's
  // `flutter create` for this project ("tatbeeqx",
  // "local.TatbeeqX"). We patch them in-place so the .exe shows
  // the customer's branding in File Explorer.
  txt = txt
    .replace(/"FileDescription", "tatbeeqx" "\\0"/g, `"FileDescription", "${brandedName}" "\\0"`)
    .replace(/"InternalName", "tatbeeqx" "\\0"/g, `"InternalName", "${productName}" "\\0"`)
    .replace(/"OriginalFilename", "tatbeeqx\.exe" "\\0"/g, `"OriginalFilename", "${productName}.exe" "\\0"`)
    .replace(/"ProductName", "tatbeeqx" "\\0"/g, `"ProductName", "${brandedName}" "\\0"`);
  fs.writeFileSync(rcPath, txt, 'utf8');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || !args.template || !args.out) {
    help();
    process.exit(args.help ? 0 : 1);
  }
  if (!args.adminPassword && !args.noAdmin) {
    console.error('error: --admin-password is required (or pass --no-admin to skip baking a Company Admin and disable the superadmin manually before handover).');
    process.exit(1);
  }

  // 1. Load + validate template.
  if (!fs.existsSync(args.template)) {
    console.error(`Template not found: ${args.template}`);
    process.exit(1);
  }
  let template;
  try {
    template = JSON.parse(fs.readFileSync(args.template, 'utf8'));
  } catch (err) {
    console.error(`Failed to parse template JSON: ${err.message}`);
    process.exit(1);
  }
  if (template.kind !== 'full' && template.kind !== 'business') {
    console.warn(`Warning: template.kind="${template.kind}" — recommended is "full" or "business" for subsystem builds.`);
  }

  // 1b. Bake the lockdown admin into the template.
  // Hash here so the plaintext password never touches disk. The boot
  // seeder uses the hash directly, no re-hashing on the customer host.
  if (!args.noAdmin) {
    const username = args.adminUsername || 'admin';
    const fullName = args.adminFullName || 'Administrator';
    const email = args.adminEmail || `${username}@subsystem.local`;
    const passwordHash = await bcrypt.hash(args.adminPassword, BCRYPT_ROUNDS);
    template.lockdownAdmin = { username, fullName, email, passwordHash };
    // Defensive — wipe the plaintext from memory so it doesn't end up
    // in any error stack trace or log dump.
    args.adminPassword = '<redacted>';
  }

  const brandedName = args.name
    || template?.branding?.appName
    || 'Subsystem';
  const productName = safeName(brandedName);
  logStep(`Building subsystem: ${brandedName} (slug: ${productName})`);

  // 1c. Resolve port pool. Build-time scan picks the primary; runtime
  // scan in start.bat picks again on the customer host.
  let portPool;
  try {
    portPool = parsePortPool(args);
  } catch (err) {
    console.error(`error: ${err.message}`);
    process.exit(1);
  }
  const primaryPort = await pickPrimaryPort(portPool);
  if (portPool.length === 1) {
    console.log(`  port: ${primaryPort} (no fallback)`);
  } else {
    console.log(`  port: ${primaryPort} (primary), pool: ${portPool[0]}-${portPool[portPool.length - 1]}`);
  }

  // 2. Resolve source repo.
  const sourceRoot = path.resolve(args.source || path.join(__dirname, '..', '..'));
  const backendSrc = path.join(sourceRoot, 'backend');
  const frontendSrc = path.join(sourceRoot, 'frontend');
  if (!fs.existsSync(backendSrc) || !fs.existsSync(frontendSrc)) {
    console.error(`Source repo missing backend/ or frontend/ at: ${sourceRoot}`);
    process.exit(1);
  }

  const outRoot = path.resolve(args.out);
  const staging = path.join(outRoot, 'staging');
  const bundle = path.join(outRoot, productName);
  ensureDir(outRoot);

  // 3. Stage backend + frontend (skip volatile / huge dirs).
  logStep('Staging backend + frontend');
  if (fs.existsSync(staging)) fs.rmSync(staging, { recursive: true, force: true });
  copyTree(backendSrc, path.join(staging, 'backend'), {
    skipDirs: ['node_modules', 'backups', 'uploads', '.env-backups'],
  });
  copyTree(frontendSrc, path.join(staging, 'frontend'), {
    skipDirs: ['build', '.dart_tool', 'ephemeral'],
  });

  // 4. Patch Windows resources for branding.
  logStep('Patching Windows resources');
  const rcPath = path.join(staging, 'frontend', 'windows', 'runner', 'Runner.rc');
  if (fs.existsSync(rcPath)) {
    patchRunnerRc(rcPath, brandedName, productName);
  } else {
    console.warn(`Runner.rc not found at ${rcPath} — skipping resource patch`);
  }

  // 5. Optional icon replacement.
  const iconPath = template?.branding?.iconPath;
  if (iconPath) {
    const absIcon = path.isAbsolute(iconPath) ? iconPath : path.resolve(path.dirname(args.template), iconPath);
    if (fs.existsSync(absIcon)) {
      const dest = path.join(staging, 'frontend', 'windows', 'runner', 'resources', 'app_icon.ico');
      fs.copyFileSync(absIcon, dest);
      console.log(`  swapped app_icon.ico ← ${absIcon}`);
    } else {
      console.warn(`  branding.iconPath set but file not found: ${absIcon}`);
    }
  }

  // 6. Write backend .env + seed.json.
  logStep('Writing backend .env and seed.json');
  const dbName = `subsystem-${productName}.db`;
  const jwtSecret = crypto.randomBytes(48).toString('hex');
  const envContent = [
    '# Generated by tools/build-subsystem — do not edit by hand.',
    'NODE_ENV=production',
    `PORT=${primaryPort}`,
    'HOST=127.0.0.1',
    `DATABASE_URL=file:./${dbName}`,
    `JWT_ACCESS_SECRET=${jwtSecret}`,
    `JWT_REFRESH_SECRET=${crypto.randomBytes(48).toString('hex')}`,
    'SUBSYSTEM_LOCKDOWN=1',
    'BOOT_SEED_PATH=./seed.json',
    '',
  ].join('\n');
  fs.writeFileSync(path.join(staging, 'backend', '.env'), envContent, 'utf8');
  fs.writeFileSync(
    path.join(staging, 'backend', 'seed.json'),
    JSON.stringify(template, null, 2),
    'utf8',
  );

  // 6.5. Phase 4.16 — optional code-gen pruning. Strip optional modules
  // NOT listed in template.modules from the staged copy. Runs BEFORE
  // the Flutter build so the trimmed source is what gets compiled.
  // Core/infra (auth, dashboard, users, etc.) is unmarked and never
  // touched. See tools/build-subsystem/prune.mjs.
  if (args.prune) {
    logStep('Pruning optional modules');
    try {
      const summary = prune(staging, template);
      const declared = summary.declared.length;
      const beDropped = summary.orphans.droppedBackend.length;
      const feDropped = summary.orphans.droppedFrontend.length;
      console.log(`  ${declared} optional module(s) kept; ${beDropped} backend route file(s) + ${feDropped} frontend feature dir(s) removed`);
      if (summary.backendRoutes.changed) {
        console.log(`  routes/index.js: -${summary.backendRoutes.droppedLines} lines`);
      }
      if (summary.frontendRouter.changed) {
        console.log(`  app_router.dart: -${summary.frontendRouter.droppedLines} lines`);
      }
      for (const fk of summary.forceKept) {
        console.log(`  force-kept "${fk.module}" — ${fk.reason}`);
      }
    } catch (err) {
      console.error(`  prune failed: ${err.message}`);
      console.error('  leaving staging dir for inspection.');
      process.exit(1);
    }
  }

  // 7. Optional: run `flutter build windows --release`.
  if (!args.noBuild) {
    logStep('Running `flutter build windows --release`');
    // Bake the chosen port into the Flutter build's compile-time
    // API_BASE_URL. start.bat can still override at runtime via the
    // TATBEEQX_API_BASE_URL env var when port-pool fallback kicks in.
    const apiBaseUrl = `http://localhost:${primaryPort}/api`;
    const result = spawnSync(
      'flutter',
      ['build', 'windows', '--release', `--dart-define=API_BASE_URL=${apiBaseUrl}`],
      {
        cwd: path.join(staging, 'frontend'),
        stdio: 'inherit',
        shell: process.platform === 'win32',
      },
    );
    if (result.status !== 0) {
      console.error('flutter build failed — leaving the staging dir for inspection.');
      process.exit(1);
    }
  } else {
    console.log('  (skipped per --no-build; run `flutter build windows --release` in the staging dir manually)');
  }

  // 8. Assemble final bundle.
  logStep(`Assembling bundle at ${bundle}`);
  if (fs.existsSync(bundle)) fs.rmSync(bundle, { recursive: true, force: true });
  ensureDir(bundle);
  // Backend (everything we staged, minus node_modules — customer runs `npm install`).
  copyTree(path.join(staging, 'backend'), path.join(bundle, 'backend'), {
    skipDirs: ['node_modules', 'backups', 'uploads'],
  });
  // Frontend Release output (only present when --no-build wasn't passed).
  const releaseDir = path.join(staging, 'frontend', 'build', 'windows', 'x64', 'runner', 'Release');
  if (fs.existsSync(releaseDir)) {
    copyTree(releaseDir, path.join(bundle, 'app'));
    // Rename the .exe to match the branding.
    const original = path.join(bundle, 'app', 'tatbeeqx.exe');
    const renamed = path.join(bundle, 'app', `${productName}.exe`);
    if (fs.existsSync(original)) fs.renameSync(original, renamed);
  } else {
    console.log('  no Release build present — bundle will need a manual `flutter build windows --release` step');
  }

  // 9. Write start.bat + README.
  // Runtime port pool: primary first, then the rest of the build-time
  // pool. start.bat scans on the customer host and picks the first
  // free port; backend reads PORT from env (dotenv leaves shell-set
  // values alone) and the Flutter .exe reads TATBEEQX_API_BASE_URL.
  // Single-port pools degenerate to "no fallback" — same behavior as
  // before this flag existed, so default builds ship unchanged.
  const runtimePool = [primaryPort, ...portPool.filter((p) => p !== primaryPort)];
  const poolStr = runtimePool.join(' ');
  // Reserve ONE port by default. Only an explicit `--port-pool <a-b>`
  // build asks for a runtime fallback list; the default and `--port
  // <n>` ship a single-port launcher with NO per-launch
  // `netstat`/`findstr` scan. That scan spawned `cmd` + `netstat` +
  // `findstr` for every pooled port on every start — pure overhead on
  // a single-port bundle, and badly amplified on hosts running
  // real-time AV (each spawn gets scanned). To target a different port
  // later, rebuild with `--port`/`--port-pool` or use the studio's
  // "Reassign port" (rewrites backend/.env in place).
  const usePoolScan = runtimePool.length > 1;
  const launchTail = [
    '',
    'pushd "%~dp0backend"',
    'IF NOT EXIST node_modules (',
    '  echo Installing backend dependencies...',
    '  call npm install --omit=dev',
    ')',
    'IF NOT EXIST prisma\\dev.db (',
    '  echo Initializing database...',
    '  call npx prisma migrate deploy',
    '  call node prisma/seed.js',
    ')',
    'start /min cmd /c "node src\\server.js"',
    'popd',
    'timeout /t 2 /nobreak >nul',
    `start "" "%~dp0app\\${productName}.exe"`,
  ];
  const startBat = (usePoolScan
    ? [
        '@echo off',
        'setlocal enabledelayedexpansion',
        'REM Generated by tools/build-subsystem (--port-pool fallback).',
        '',
        `set "TATBEEQX_PORT_POOL=${poolStr}"`,
        'set "TATBEEQX_PORT="',
        'for %%P in (%TATBEEQX_PORT_POOL%) do (',
        '  if not defined TATBEEQX_PORT (',
        '    netstat -ano | findstr ":%%P " >nul 2>&1',
        '    if !errorlevel! equ 1 set "TATBEEQX_PORT=%%P"',
        '  )',
        ')',
        'if not defined TATBEEQX_PORT (',
        '  echo ERROR: no free port available in pool: %TATBEEQX_PORT_POOL%',
        '  pause',
        '  exit /b 1',
        ')',
        'echo Using port !TATBEEQX_PORT!',
        'set "PORT=!TATBEEQX_PORT!"',
        'set "TATBEEQX_API_BASE_URL=http://localhost:!TATBEEQX_PORT!/api"',
        ...launchTail,
        'endlocal',
        '',
      ]
    : [
        '@echo off',
        'REM Generated by tools/build-subsystem (single reserved port).',
        '',
        `set "PORT=${primaryPort}"`,
        `set "TATBEEQX_API_BASE_URL=http://localhost:${primaryPort}/api"`,
        `echo Using port ${primaryPort}`,
        ...launchTail,
        '',
      ]
  ).join('\r\n');
  fs.writeFileSync(path.join(bundle, 'start.bat'), startBat, 'utf8');

  const readme = `# ${brandedName}

Locked-down subsystem build of TatbeeqX. Generated from \`${path.basename(args.template)}\`.

## Run

\`\`\`
start.bat
\`\`\`

This launches the API on http://127.0.0.1:${primaryPort} and opens the desktop app.${runtimePool.length > 1 ? `

If port ${primaryPort} is busy at startup, \`start.bat\` falls through the
pool ${runtimePool.join(', ')} and uses the first free port. The desktop
app picks up the chosen port via the \`TATBEEQX_API_BASE_URL\` env var
that \`start.bat\` sets before launch.` : ''}

## First-boot

The first time you run \`start.bat\`, the backend:
- Installs Node dependencies (\`npm install --omit=dev\`).
- Runs \`prisma migrate deploy\` to create the SQLite database.
- Runs the bundled \`seed.json\` to apply the template (custom entities,
  reports, theme, branding).

## Default credentials

The build CLI bakes a Company Admin into \`seed.json\` as a bcrypt hash
(plaintext never lands on disk). On first boot the seeder:

1. Disables \`superadmin\` (the user \`prisma/seed.js\` creates).
2. Upserts the customer's Company Admin with the hash from the CLI.
3. Grants the \`company_admin\` role.

The customer logs in with \`--admin-username\` (default \`admin\`) and the
password the vendor passed via \`--admin-password\`.

**Vendor support access:** \`superadmin\` is disabled, not deleted. To
get back in for support, run over SSH:

\`\`\`sql
UPDATE users SET isActive = 1 WHERE username = 'superadmin';
\`\`\`

Reset its password if you don't recall the seeded one
(\`ChangeMe!2026\`). Disable again after support is done.

## Lockdown surfaces

This binary runs with \`SUBSYSTEM_LOCKDOWN=1\`. The frontend hides:
- Database admin (\`/database\`)
- Custom Entities admin (\`/custom-entities\`)
- Templates (\`/templates\`)
- Theme builder (\`/themes\`)
- System (\`/system\`)
- System logs (\`/system-logs\`)
- Pages (\`/pages\`)
- Translations (\`/translations\`)

Direct API access still requires a Super Admin — the lockdown is UX, not
adversarial security.

## Troubleshooting

- **Port ${primaryPort} in use** — ${runtimePool.length > 1 ? `\`start.bat\` will auto-pick the next free port from the pool (${runtimePool.join(', ')}).` : `edit \`backend/.env\` to set a different \`PORT\`, or rebuild with \`--port-pool\` to bake a fallback list.`}
- **Missing Node** — install Node 20+ on the customer host.
- **Database errors** — delete \`backend/prisma/dev.db\` and \`backend/seed.json\`'s applied marker
  by running this SQL: \`DELETE FROM settings WHERE key IN ('system.subsystem_info', 'system.boot_seed_applied');\`
  and restart.
`;
  fs.writeFileSync(path.join(bundle, 'README.md'), readme, 'utf8');
  fs.copyFileSync(path.join(staging, 'backend', 'seed.json'), path.join(bundle, 'seed.json'));

  logStep(`Done. Bundle at: ${bundle}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
