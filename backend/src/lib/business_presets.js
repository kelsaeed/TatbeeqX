import { prisma } from './prisma.js';
import {
  buildCreateTableSQL,
  buildJoinTableSQL,
  ensureMenuItem,
  ensureModule,
  ensurePermissions,
  grantToSuperAdminAndCompanyAdmin,
  isRelationsCol,
  tableExists,
} from './custom_entity_engine.js';

const text = (extras = {}) => ({ type: 'text', ...extras });
const longtext = (extras = {}) => ({ type: 'longtext', ...extras });
const number = (extras = {}) => ({ type: 'number', ...extras });
const integer = (extras = {}) => ({ type: 'integer', ...extras });
const bool = (extras = {}) => ({ type: 'bool', ...extras });
const dateField = (extras = {}) => ({ type: 'date', ...extras });
const datetimeField = (extras = {}) => ({ type: 'datetime', ...extras });

function col(name, label, def, opts = {}) {
  return {
    name,
    label,
    required: false,
    unique: false,
    searchable: false,
    showInList: true,
    ...def,
    ...opts,
  };
}

function entity({ code, label, singular, icon, category, columns }) {
  return {
    code,
    tableName: code,
    label,
    singular,
    icon,
    category,
    permissionPrefix: code,
    columns,
  };
}

const products = entity({
  code: 'products',
  label: 'Products',
  singular: 'Product',
  icon: 'reports',
  category: 'catalog',
  columns: [
    col('sku', 'SKU', text({ unique: true, searchable: true, required: true })),
    col('name', 'Name', text({ required: true, searchable: true })),
    col('category', 'Category', text({ searchable: true })),
    col('price', 'Price', number({ required: true })),
    col('cost', 'Cost', number()),
    col('stock', 'Stock', integer()),
    col('barcode', 'Barcode', text({ searchable: true })),
    col('description', 'Description', longtext({ showInList: false })),
    col('is_active', 'Active', bool({ defaultValue: 1 })),
  ],
});

const customers = entity({
  code: 'customers',
  label: 'Customers',
  singular: 'Customer',
  icon: 'people',
  category: 'crm',
  columns: [
    col('code', 'Code', text({ unique: true, searchable: true })),
    col('full_name', 'Full name', text({ required: true, searchable: true })),
    col('email', 'Email', text({ searchable: true })),
    col('phone', 'Phone', text({ searchable: true })),
    col('address', 'Address', text({ showInList: false })),
    col('balance', 'Balance', number()),
    col('notes', 'Notes', longtext({ showInList: false })),
  ],
});

const suppliers = entity({
  code: 'suppliers',
  label: 'Suppliers',
  singular: 'Supplier',
  icon: 'business',
  category: 'catalog',
  columns: [
    col('code', 'Code', text({ unique: true, searchable: true })),
    col('name', 'Name', text({ required: true, searchable: true })),
    col('contact', 'Contact', text()),
    col('phone', 'Phone', text({ searchable: true })),
    col('email', 'Email', text({ searchable: true })),
    col('address', 'Address', text({ showInList: false })),
  ],
});

const sales = entity({
  code: 'sales',
  label: 'Sales',
  singular: 'Sale',
  icon: 'reports',
  category: 'sales',
  columns: [
    col('reference', 'Reference', text({ unique: true, searchable: true, required: true })),
    col('customer_id', 'Customer ID', integer({ searchable: true })),
    col('total', 'Total', number({ required: true })),
    col('paid', 'Paid', number()),
    col('status', 'Status', text({ defaultValue: 'open' })),
    col('sale_date', 'Date', dateField({ required: true })),
    col('notes', 'Notes', longtext({ showInList: false })),
  ],
});

const payments = entity({
  code: 'payments',
  label: 'Payments',
  singular: 'Payment',
  icon: 'reports',
  category: 'sales',
  columns: [
    col('reference', 'Reference', text({ unique: true, searchable: true })),
    col('sale_id', 'Sale ID', integer()),
    col('amount', 'Amount', number({ required: true })),
    col('method', 'Method', text({ defaultValue: 'cash' })),
    col('paid_at', 'Paid at', datetimeField({ required: true })),
    col('notes', 'Notes', longtext({ showInList: false })),
  ],
});

const menuItems = entity({
  code: 'menu_items',
  label: 'Menu items',
  singular: 'Menu item',
  icon: 'reports',
  category: 'restaurant',
  columns: [
    col('code', 'Code', text({ unique: true, searchable: true })),
    col('name', 'Name', text({ required: true, searchable: true })),
    col('section', 'Section', text({ searchable: true })),
    col('price', 'Price', number({ required: true })),
    col('cost', 'Cost', number()),
    col('available', 'Available', bool({ defaultValue: 1 })),
    col('description', 'Description', longtext({ showInList: false })),
  ],
});

const restaurantTables = entity({
  code: 'restaurant_tables',
  label: 'Tables',
  singular: 'Table',
  icon: 'store',
  category: 'restaurant',
  columns: [
    col('code', 'Code', text({ unique: true, required: true })),
    col('seats', 'Seats', integer()),
    col('area', 'Area', text({ searchable: true })),
    col('status', 'Status', text({ defaultValue: 'free' })),
  ],
});

const orders = entity({
  code: 'orders',
  label: 'Orders',
  singular: 'Order',
  icon: 'reports',
  category: 'restaurant',
  columns: [
    col('reference', 'Reference', text({ unique: true, searchable: true, required: true })),
    col('table_id', 'Table ID', integer()),
    col('status', 'Status', text({ defaultValue: 'open' })),
    col('total', 'Total', number()),
    col('opened_at', 'Opened at', datetimeField({ required: true })),
    col('closed_at', 'Closed at', datetimeField()),
  ],
});

const reservations = entity({
  code: 'reservations',
  label: 'Reservations',
  singular: 'Reservation',
  icon: 'reports',
  category: 'restaurant',
  columns: [
    col('customer_name', 'Customer name', text({ required: true, searchable: true })),
    col('phone', 'Phone', text({ searchable: true })),
    col('party_size', 'Party size', integer()),
    col('reserved_for', 'Reserved for', datetimeField({ required: true })),
    col('table_id', 'Table ID', integer()),
    col('status', 'Status', text({ defaultValue: 'pending' })),
    col('notes', 'Notes', longtext({ showInList: false })),
  ],
});

const patients = entity({
  code: 'patients',
  label: 'Patients',
  singular: 'Patient',
  icon: 'people',
  category: 'clinic',
  columns: [
    col('code', 'Code', text({ unique: true, searchable: true })),
    col('full_name', 'Full name', text({ required: true, searchable: true })),
    col('birth_date', 'Birth date', dateField()),
    col('gender', 'Gender', text()),
    col('phone', 'Phone', text({ searchable: true })),
    col('email', 'Email', text({ searchable: true })),
    col('blood_type', 'Blood type', text()),
    col('allergies', 'Allergies', longtext({ showInList: false })),
    col('history', 'Medical history', longtext({ showInList: false })),
  ],
});

const appointments = entity({
  code: 'appointments',
  label: 'Appointments',
  singular: 'Appointment',
  icon: 'reports',
  category: 'clinic',
  columns: [
    col('patient_id', 'Patient ID', integer({ required: true })),
    col('doctor', 'Doctor', text({ searchable: true })),
    col('appointment_at', 'Date', datetimeField({ required: true })),
    col('reason', 'Reason', text({ searchable: true })),
    col('status', 'Status', text({ defaultValue: 'scheduled' })),
    col('notes', 'Notes', longtext({ showInList: false })),
  ],
});

const treatments = entity({
  code: 'treatments',
  label: 'Treatments',
  singular: 'Treatment',
  icon: 'reports',
  category: 'clinic',
  columns: [
    col('patient_id', 'Patient ID', integer({ required: true })),
    col('appointment_id', 'Appointment ID', integer()),
    col('diagnosis', 'Diagnosis', text({ required: true, searchable: true })),
    col('prescription', 'Prescription', longtext({ showInList: false })),
    col('cost', 'Cost', number()),
    col('treated_at', 'Date', dateField({ required: true })),
  ],
});

const rawMaterials = entity({
  code: 'raw_materials',
  label: 'Raw materials',
  singular: 'Material',
  icon: 'reports',
  category: 'factory',
  columns: [
    col('code', 'Code', text({ unique: true, searchable: true, required: true })),
    col('name', 'Name', text({ required: true, searchable: true })),
    col('unit', 'Unit', text()),
    col('stock', 'Stock', number()),
    col('reorder_point', 'Reorder point', number()),
    col('supplier_id', 'Supplier ID', integer()),
  ],
});

const workOrders = entity({
  code: 'work_orders',
  label: 'Work orders',
  singular: 'Work order',
  icon: 'reports',
  category: 'factory',
  columns: [
    col('reference', 'Reference', text({ unique: true, searchable: true, required: true })),
    col('product_id', 'Product ID', integer()),
    col('quantity', 'Quantity', number({ required: true })),
    col('status', 'Status', text({ defaultValue: 'planned' })),
    col('starts_at', 'Starts at', datetimeField()),
    col('ends_at', 'Ends at', datetimeField()),
    col('notes', 'Notes', longtext({ showInList: false })),
  ],
});

const inventoryMoves = entity({
  code: 'inventory_movements',
  label: 'Inventory movements',
  singular: 'Movement',
  icon: 'history',
  category: 'factory',
  columns: [
    col('reference', 'Reference', text({ searchable: true })),
    col('item_type', 'Item type', text({ searchable: true })),
    col('item_id', 'Item ID', integer()),
    col('direction', 'Direction', text({ defaultValue: 'in' })),
    col('quantity', 'Quantity', number({ required: true })),
    col('reason', 'Reason', text()),
    col('moved_at', 'Moved at', datetimeField({ required: true })),
  ],
});

const invoices = entity({
  code: 'invoices',
  label: 'Invoices',
  singular: 'Invoice',
  icon: 'reports',
  category: 'finance',
  columns: [
    col('number', 'Number', text({ unique: true, searchable: true, required: true })),
    col('client_id', 'Client ID', integer()),
    col('issue_date', 'Issue date', dateField({ required: true })),
    col('due_date', 'Due date', dateField()),
    col('subtotal', 'Subtotal', number()),
    col('tax', 'Tax', number()),
    col('total', 'Total', number({ required: true })),
    col('status', 'Status', text({ defaultValue: 'draft' })),
    col('notes', 'Notes', longtext({ showInList: false })),
  ],
});

const accounts = entity({
  code: 'accounts',
  label: 'Accounts',
  singular: 'Account',
  icon: 'reports',
  category: 'finance',
  columns: [
    col('code', 'Code', text({ unique: true, searchable: true, required: true })),
    col('name', 'Name', text({ required: true, searchable: true })),
    col('type', 'Type', text({ defaultValue: 'asset' })),
    col('balance', 'Balance', number()),
    col('currency', 'Currency', text({ defaultValue: 'USD' })),
  ],
});

const transactions = entity({
  code: 'transactions',
  label: 'Transactions',
  singular: 'Transaction',
  icon: 'history',
  category: 'finance',
  columns: [
    col('reference', 'Reference', text({ searchable: true })),
    col('account_id', 'Account ID', integer()),
    col('amount', 'Amount', number({ required: true })),
    col('direction', 'Direction', text({ defaultValue: 'debit' })),
    col('description', 'Description', text({ searchable: true })),
    col('happened_at', 'Date', datetimeField({ required: true })),
  ],
});

const assets = entity({
  code: 'assets',
  label: 'Assets',
  singular: 'Asset',
  icon: 'reports',
  category: 'rental',
  columns: [
    col('code', 'Code', text({ unique: true, searchable: true, required: true })),
    col('name', 'Name', text({ required: true, searchable: true })),
    col('category', 'Category', text({ searchable: true })),
    col('daily_rate', 'Daily rate', number({ required: true })),
    col('deposit', 'Deposit', number()),
    col('status', 'Status', text({ defaultValue: 'available' })),
    col('notes', 'Notes', longtext({ showInList: false })),
  ],
});

const rentals = entity({
  code: 'rentals',
  label: 'Rentals',
  singular: 'Rental',
  icon: 'reports',
  category: 'rental',
  columns: [
    col('reference', 'Reference', text({ unique: true, searchable: true, required: true })),
    col('asset_id', 'Asset ID', integer({ required: true })),
    col('customer_id', 'Customer ID', integer()),
    col('starts_at', 'Starts at', datetimeField({ required: true })),
    col('ends_at', 'Ends at', datetimeField()),
    col('returned_at', 'Returned at', datetimeField()),
    col('total', 'Total', number()),
    col('status', 'Status', text({ defaultValue: 'open' })),
  ],
});

export const PRESETS = {
  retail: {
    code: 'retail',
    name: 'Retail / POS',
    description: 'Cashier and point-of-sale workflow with products, customers, sales and payments.',
    icon: 'store',
    entities: [products, customers, suppliers, sales, payments],
  },
  restaurant: {
    code: 'restaurant',
    name: 'Restaurant',
    description: 'Menu items, tables, orders and reservations.',
    icon: 'store',
    entities: [menuItems, restaurantTables, orders, reservations, customers],
  },
  clinic: {
    code: 'clinic',
    name: 'Clinic',
    description: 'Patient records, appointments and treatments.',
    icon: 'people',
    entities: [patients, appointments, treatments],
  },
  factory: {
    code: 'factory',
    name: 'Factory / Manufacturing',
    description: 'Raw materials, products, work orders and inventory movements.',
    icon: 'business',
    entities: [products, rawMaterials, workOrders, inventoryMoves, suppliers],
  },
  finance: {
    code: 'finance',
    name: 'Finance office',
    description: 'Clients, invoices, accounts and transactions.',
    icon: 'reports',
    entities: [customers, invoices, accounts, transactions],
  },
  rental: {
    code: 'rental',
    name: 'Rental company',
    description: 'Assets, customers and rental contracts.',
    icon: 'store',
    entities: [assets, customers, rentals, payments],
  },
  blank: {
    code: 'blank',
    name: 'Blank slate',
    description: 'No starter modules. Add your own tables and entities from the admin UI.',
    icon: 'reports',
    entities: [],
  },
};

export function listPresets() {
  return Object.values(PRESETS).map((p) => ({
    code: p.code,
    name: p.name,
    description: p.description,
    icon: p.icon,
    entityCount: p.entities.length,
    entities: p.entities.map((e) => ({ code: e.code, label: e.label, category: e.category })),
  }));
}

export async function applyPreset(code) {
  const preset = PRESETS[code];
  if (!preset) throw new Error(`Unknown business preset: ${code}`);

  const sortBase = 200;
  const seenEntities = new Set();
  let i = 0;
  for (const e of preset.entities) {
    if (seenEntities.has(e.code)) continue;
    seenEntities.add(e.code);
    await registerCustomEntity({
      code: e.code,
      tableName: e.tableName,
      label: e.label,
      singular: e.singular,
      icon: e.icon,
      category: e.category,
      columns: e.columns,
      sortOrder: sortBase + i * 10,
      isSystem: true,
    });
    i++;
  }

  const setting = await prisma.setting.findFirst({ where: { companyId: null, key: 'system.business_type' } });
  if (setting) {
    await prisma.setting.update({ where: { id: setting.id }, data: { value: preset.code } });
  } else {
    await prisma.setting.create({
      data: { companyId: null, key: 'system.business_type', value: preset.code, type: 'string', isPublic: true },
    });
  }

  return { code: preset.code, applied: preset.entities.map((e) => e.code) };
}

export async function registerCustomEntity({
  code,
  tableName,
  label,
  singular,
  icon,
  category,
  columns,
  sortOrder = 200,
  isSystem = false,
  createTable = true,
}) {
  const config = JSON.stringify({ columns });
  const permissionPrefix = code;

  const exists = await tableExists(tableName);
  if (createTable && !exists) {
    const sql = buildCreateTableSQL(tableName, columns);
    await prisma.$executeRawUnsafe(sql);
  }
  // Phase 4.15 — many-to-many `relations` columns live in their own
  // join tables. Always ensure them (idempotent), since they may be
  // added after the source table already exists.
  if (createTable) {
    for (const c of columns) {
      if (isRelationsCol(c)) {
        await prisma.$executeRawUnsafe(buildJoinTableSQL(tableName, c.name));
      }
    }
  }

  const existing = await prisma.customEntity.findUnique({ where: { code } });
  if (existing) {
    await prisma.customEntity.update({
      where: { code },
      data: { tableName, label, singular, icon, category, permissionPrefix, config, isActive: true, isSystem },
    });
  } else {
    await prisma.customEntity.create({
      data: { code, tableName, label, singular, icon, category, permissionPrefix, config, isActive: true, isSystem },
    });
  }

  await ensureModule({ code, name: label, icon, sortOrder });
  await ensurePermissions(permissionPrefix, label);
  await ensureMenuItem({
    entityCode: code,
    label,
    icon,
    sortOrder,
    permissionCode: `${permissionPrefix}.view`,
  });
  await grantToSuperAdminAndCompanyAdmin(permissionPrefix);

  return prisma.customEntity.findUnique({ where: { code } });
}
