import { env } from './config/env.js';
import { buildApp } from './lib/app.js';
import { startCronLoop } from './lib/cron.js';
import { logSystem } from './lib/system_log.js';
import { bootSeedIfNeeded } from './lib/boot_seeder.js';

const app = buildApp();

app.listen(env.port, env.host, async () => {
  console.log(`API listening on http://${env.host}:${env.port}`);
  // Phase 4.12 — first-boot seeder runs before cron and before any
  // request lands. Idempotent: a marker row in `settings` records that
  // we've already applied the bundled template, so restarts don't
  // re-apply.
  try {
    const result = await bootSeedIfNeeded();
    if (result.ran) {
      console.log('Boot seeder applied template:', result.summary);
    }
  } catch (err) {
    console.error('Boot seeder failed:', err);
  }
  startCronLoop();
  logSystem('info', 'system', 'API started', { host: env.host, port: env.port }).catch(() => {});
});
