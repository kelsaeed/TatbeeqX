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
    'PORT=4040',
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
    const result = spawnSync('flutter', ['build', 'windows', '--release'], {
      cwd: path.join(staging, 'frontend'),
      stdio: 'inherit',
      shell: process.platform === 'win32',
    });
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
  const startBat = [
    '@echo off',
    'REM Generated by tools/build-subsystem.',
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
    '',
  ].join('\r\n');
  fs.writeFileSync(path.join(bundle, 'start.bat'), startBat, 'utf8');

  const readme = `# ${brandedName}

Locked-down subsystem build of TatbeeqX. Generated from \`${path.basename(args.template)}\`.

## Run

\`\`\`
start.bat
\`\`\`

This launches the API on http://127.0.0.1:4040 and opens the desktop app.

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

- **Port 4040 in use** — edit \`backend/.env\` to set a different \`PORT\`.
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
