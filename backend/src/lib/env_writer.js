import fs from 'node:fs';
import path from 'node:path';

const ENV_PATH = path.resolve(process.cwd(), '.env');
const BACKUP_DIR = path.resolve(process.cwd(), '.env-backups');

function readEnv() {
  if (!fs.existsSync(ENV_PATH)) return '';
  return fs.readFileSync(ENV_PATH, 'utf8');
}

function backupEnv() {
  if (!fs.existsSync(ENV_PATH)) return null;
  if (!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const target = path.join(BACKUP_DIR, `.env.${stamp}`);
  fs.copyFileSync(ENV_PATH, target);
  return target;
}

export function readEnvKeys(keys) {
  const txt = readEnv();
  const out = {};
  for (const key of keys) {
    const re = new RegExp(`^${key}\\s*=\\s*(.*)$`, 'm');
    const match = txt.match(re);
    out[key] = match ? match[1].replace(/^"|"$/g, '') : null;
  }
  return out;
}

export function setEnvKeys(map) {
  const backup = backupEnv();
  let txt = readEnv();
  for (const [key, value] of Object.entries(map)) {
    const safe = value == null ? '' : String(value);
    const line = `${key}="${safe.replace(/"/g, '\\"')}"`;
    const re = new RegExp(`^${key}\\s*=.*$`, 'm');
    if (re.test(txt)) {
      txt = txt.replace(re, line);
    } else {
      if (txt.length && !txt.endsWith('\n')) txt += '\n';
      txt += `${line}\n`;
    }
  }
  fs.writeFileSync(ENV_PATH, txt, 'utf8');
  return { backup, written: Object.keys(map) };
}
