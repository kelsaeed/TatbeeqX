// Captures the current setup as a "full" template via the real API
// (same path as the /templates page "Capture" button), then writes the
// template payload to a JSON file the build-subsystem CLI can consume.
//
//   node scripts/capture-restaurant-template.mjs <output-json-path>
//
// 127.0.0.1, not localhost — see node-fetch-localhost-ipv6 note.

import { writeFileSync } from 'node:fs';

const API = process.env.API_BASE || 'http://127.0.0.1:4040/api';
const USER = process.env.ADMIN_USER || 'superadmin';
const PASS = process.env.ADMIN_PASS || 'ChangeMe!2026';
const OUT = process.argv[2] || './restaurant_template.json';

let token = '';
async function api(method, path, body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  let json; try { json = text ? JSON.parse(text) : null; } catch { json = text; }
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status} ${json && json.error ? json.error : text}`);
  return json;
}

const login = await api('POST', '/auth/login', { username: USER, password: PASS });
if (login.requires2FA) throw new Error('superadmin has 2FA on — disable it for this demo.');
token = login.accessToken;
console.log(`✓ Logged in as ${login.user.username}`);

const captured = await api('POST', '/templates/capture', {
  code: 'restaurant_demo',
  name: 'Restaurant Demo',
  description: 'Auto-captured restaurant preset + demo data for a subsystem build.',
  kind: 'full',
});
console.log(`✓ Captured template #${captured.id} (kind=${captured.kind})`);

// `captured.data` is the template payload the build CLI expects. Add a
// branding block so the built app shows "Restaurant" instead of the
// studio default. (The CLI also takes --name; this makes the in-app
// title/theme follow too.)
const payload = captured.data || {};
payload.branding = {
  appName: 'Restaurant',
  primaryColor: payload.branding?.primaryColor || '#c0392b',
  ...payload.branding,
  appName: 'Restaurant',
};

const entityCount = Array.isArray(payload.entities) ? payload.entities.length : 0;
writeFileSync(OUT, JSON.stringify(payload, null, 2));
console.log(`✓ Wrote ${OUT}  (kind=${payload.kind}, entities=${entityCount})`);
