// Restaurant demo seeder — Phase: dev/testing helper.
//
// Does exactly what the app does when a Super Admin picks "Restaurant"
// in the Setup Wizard, then fills the new tables with sample rows:
//
//   1. POST /api/auth/login            → get an access token
//   2. GET  /api/business/state        → is a preset applied?
//   3. POST /api/business/apply        → create the 5 restaurant tables
//   4. POST /api/c/<entity>            → insert demo rows (one call per row)
//   5. GET  /api/c/<entity>            → read them back and print a summary
//
// Idempotent: an entity that already has rows is left untouched, so you
// can run this as many times as you like without duplicate/unique errors.
//
//   node scripts/seed-restaurant-demo.mjs
//
// Override the target / credentials with env vars:
//   API_BASE   (default http://localhost:4040/api)
//   ADMIN_USER (default superadmin)
//   ADMIN_PASS (default ChangeMe!2026)

// Note: 127.0.0.1, not "localhost" — the backend binds IPv4 (0.0.0.0)
// and Node's fetch resolves "localhost" to IPv6 (::1) first on Windows,
// which fails with no fallback.
const API = process.env.API_BASE || 'http://127.0.0.1:4040/api';
const USER = process.env.ADMIN_USER || 'superadmin';
const PASS = process.env.ADMIN_PASS || 'ChangeMe!2026';

let token = '';

async function api(method, path, body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  let json;
  try { json = text ? JSON.parse(text) : null; } catch { json = text; }
  if (!res.ok) {
    const msg = json && json.error ? json.error : (typeof json === 'string' ? json : res.statusText);
    throw new Error(`${method} ${path} → ${res.status} ${msg}`);
  }
  return json;
}

// Insert a list of rows into a custom entity, skipping the whole entity
// if it already holds data. Returns the created rows (for FK wiring).
async function seed(code, rows) {
  const existing = await api('GET', `/c/${code}?page=1&pageSize=1`);
  if ((existing.total ?? 0) > 0) {
    console.log(`  • ${code}: already has ${existing.total} row(s) — skipped`);
    const all = await api('GET', `/c/${code}?page=1&pageSize=100`);
    return all.items || [];
  }
  const created = [];
  for (const r of rows) {
    created.push(await api('POST', `/c/${code}`, r));
  }
  console.log(`  • ${code}: inserted ${created.length} row(s)`);
  return created;
}

const now = new Date();
const iso = (d) => d.toISOString().slice(0, 19).replace('T', ' '); // "YYYY-MM-DD HH:MM:SS"
const plusH = (h) => iso(new Date(now.getTime() + h * 3600_000));
const today = now.toISOString().slice(0, 10);

async function main() {
  console.log(`→ API: ${API}`);

  // 1. Login
  const login = await api('POST', '/auth/login', { username: USER, password: PASS });
  if (login.requires2FA) throw new Error('Super Admin has 2FA enabled — disable it or use a non-2FA admin for the demo.');
  token = login.accessToken;
  console.log(`✓ Logged in as ${login.user.username}`);

  // 2. Current business state
  const state = await api('GET', '/business/state');
  console.log(`✓ Business state before: applied=${state.applied} code=${state.code ?? '—'} entities=${state.entityCount ?? 0}`);

  // 3. Apply the Restaurant preset (idempotent server-side: CREATE TABLE IF NOT EXISTS + permission upserts)
  const applied = await api('POST', '/business/apply', { code: 'restaurant' });
  console.log(`✓ Applied "restaurant" preset → tables: ${applied.applied.join(', ')}`);

  // 4. Seed dummy data
  console.log('→ Seeding demo data...');

  const tables = await seed('restaurant_tables', [
    { code: 'T1', seats: 2, area: 'Indoor',  status: 'free' },
    { code: 'T2', seats: 4, area: 'Indoor',  status: 'occupied' },
    { code: 'T3', seats: 4, area: 'Patio',   status: 'free' },
    { code: 'T4', seats: 6, area: 'Patio',   status: 'reserved' },
    { code: 'T5', seats: 8, area: 'VIP Room', status: 'free' },
  ]);

  await seed('menu_items', [
    { code: 'M01', name: 'Margherita Pizza', section: 'Pizza',    price: 9.50,  cost: 3.20, available: true,  description: 'Tomato, mozzarella, basil.' },
    { code: 'M02', name: 'Pepperoni Pizza',  section: 'Pizza',    price: 11.00, cost: 4.10, available: true,  description: 'Double pepperoni.' },
    { code: 'M03', name: 'Caesar Salad',     section: 'Starters', price: 6.75,  cost: 2.00, available: true,  description: 'Romaine, croutons, parmesan.' },
    { code: 'M04', name: 'Hummus Plate',     section: 'Starters', price: 5.00,  cost: 1.40, available: true,  description: 'With warm pita.' },
    { code: 'M05', name: 'Lentil Soup',      section: 'Starters', price: 4.25,  cost: 0.90, available: true,  description: 'Served with lemon.' },
    { code: 'M06', name: 'Grilled Chicken',  section: 'Mains',    price: 13.50, cost: 5.00, available: true,  description: 'With rice and salad.' },
    { code: 'M07', name: 'Beef Burger',      section: 'Mains',    price: 12.00, cost: 4.80, available: true,  description: '200g beef, cheddar, fries.' },
    { code: 'M08', name: 'Falafel Wrap',     section: 'Mains',    price: 7.50,  cost: 2.10, available: true,  description: 'Tahini, pickles, fries.' },
    { code: 'M09', name: 'Tiramisu',         section: 'Dessert',  price: 5.50,  cost: 1.80, available: true,  description: 'House-made.' },
    { code: 'M10', name: 'Fresh Lemonade',   section: 'Drinks',   price: 3.00,  cost: 0.60, available: true,  description: 'Mint optional.' },
    { code: 'M11', name: 'Espresso',         section: 'Drinks',   price: 2.50,  cost: 0.40, available: true,  description: 'Single or double.' },
    { code: 'M12', name: 'Seasonal Special', section: 'Mains',    price: 15.00, cost: 6.00, available: false, description: 'Currently off the menu.' },
  ]);

  const customers = await seed('customers', [
    { code: 'C001', full_name: 'Ahmed Khalil',  email: 'ahmed@example.com',  phone: '0790000001', address: 'Amman, Jordan',  balance: 0,     notes: 'Regular — likes window seats.' },
    { code: 'C002', full_name: 'Sara Mansour',  email: 'sara@example.com',   phone: '0790000002', address: 'Amman, Jordan',  balance: 12.50, notes: 'Loyalty member.' },
    { code: 'C003', full_name: 'John Smith',    email: 'john@example.com',   phone: '0790000003', address: 'Dubai, UAE',     balance: 0,     notes: '' },
    { code: 'C004', full_name: 'Layla Haddad',  email: 'layla@example.com',  phone: '0790000004', address: 'Irbid, Jordan',  balance: -5.00, notes: 'Owes for last visit.' },
  ]);

  const tId = (i) => tables[i] ? tables[i].id : null;

  await seed('orders', [
    { reference: 'ORD-1001', table_id: tId(1), status: 'closed', total: 34.25, opened_at: plusH(-3), closed_at: plusH(-2) },
    { reference: 'ORD-1002', table_id: tId(1), status: 'open',   total: 21.00, opened_at: plusH(-1), closed_at: null },
    { reference: 'ORD-1003', table_id: tId(3), status: 'open',   total: 47.50, opened_at: plusH(-0.5), closed_at: null },
    { reference: 'ORD-1004', table_id: tId(0), status: 'closed', total: 9.50,  opened_at: plusH(-5), closed_at: plusH(-4.5) },
  ]);

  await seed('reservations', [
    { customer_name: 'Ahmed Khalil', phone: '0790000001', party_size: 2, reserved_for: plusH(2),  table_id: tId(0), status: 'confirmed', notes: 'Anniversary.' },
    { customer_name: 'Sara Mansour', phone: '0790000002', party_size: 6, reserved_for: plusH(5),  table_id: tId(3), status: 'pending',   notes: 'Birthday party, needs high chairs.' },
    { customer_name: 'Walk-in',      phone: '',           party_size: 4, reserved_for: plusH(26), table_id: tId(2), status: 'pending',   notes: '' },
  ]);

  // Use one customer so the var is "used" even when customers are skipped.
  void customers;

  // 5. Read back a summary
  console.log('→ Verifying (reading rows back through the API)...');
  const summary = await api('GET', '/business/state');
  for (const code of ['menu_items', 'restaurant_tables', 'orders', 'reservations', 'customers']) {
    const list = await api('GET', `/c/${code}?page=1&pageSize=3`);
    const sample = (list.items || []).map((r) => r.name || r.code || r.reference || r.customer_name || r.full_name).filter(Boolean);
    console.log(`  • ${code}: total=${list.total}  sample=[${sample.join(', ')}]`);
  }
  console.log(`✓ Business state after: applied=${summary.applied} code=${summary.code} entities=${summary.entityCount}`);
  console.log(`✓ Done — date used for relative timestamps: ${today}`);
}

main().catch((e) => { console.error('✗ ' + e.message); process.exit(1); });
