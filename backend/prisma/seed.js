import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { applyPreset, PRESETS } from '../src/lib/business_presets.js';

const prisma = new PrismaClient();

const SEED = {
  username: process.env.SEED_SUPERADMIN_USERNAME || 'superadmin',
  email: process.env.SEED_SUPERADMIN_EMAIL || 'superadmin@local',
  password: process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026',
};

const ACTION_LABEL = {
  view: 'View',
  create: 'Create',
  edit: 'Edit',
  delete: 'Delete',
  approve: 'Approve',
  export: 'Export',
  print: 'Print',
  manage_settings: 'Manage Settings',
  manage_users: 'Manage Users',
  manage_roles: 'Manage Roles',
  run: 'Run',
};

const MODULES = [
  { code: 'dashboard', name: 'Dashboard', icon: 'dashboard', actions: ['view'], menu: { label: 'Dashboard', route: '/dashboard', icon: 'dashboard', sortOrder: 10 } },
  { code: 'companies', name: 'Companies', icon: 'business', actions: ['view', 'create', 'edit', 'delete', 'approve', 'export', 'print'], menu: { label: 'Companies', route: '/companies', icon: 'business', sortOrder: 20 } },
  { code: 'branches', name: 'Branches', icon: 'store', actions: ['view', 'create', 'edit', 'delete', 'export', 'print'], menu: { label: 'Branches', route: '/branches', icon: 'store', sortOrder: 30 } },
  { code: 'users', name: 'Users', icon: 'people', actions: ['view', 'create', 'edit', 'delete', 'approve', 'export', 'print', 'manage_users'], menu: { label: 'Users', route: '/users', icon: 'people', sortOrder: 40 } },
  { code: 'roles', name: 'Roles', icon: 'shield', actions: ['view', 'create', 'edit', 'delete', 'manage_roles'], menu: { label: 'Roles', route: '/roles', icon: 'shield', sortOrder: 50 } },
  { code: 'permissions', name: 'Permissions', icon: 'key', actions: ['view'], menu: null },
  { code: 'audit', name: 'Audit Logs', icon: 'history', actions: ['view', 'export'], menu: { label: 'Audit Logs', route: '/audit', icon: 'history', sortOrder: 60 } },
  { code: 'settings', name: 'Settings', icon: 'settings', actions: ['view', 'manage_settings'], menu: { label: 'Settings', route: '/settings', icon: 'settings', sortOrder: 70 } },
  { code: 'themes', name: 'Appearance', icon: 'palette', actions: ['view', 'manage_settings'], menu: { label: 'Appearance', route: '/themes', icon: 'palette', sortOrder: 80 } },
  { code: 'reports', name: 'Reports', icon: 'reports', actions: ['view', 'create', 'edit', 'delete', 'export', 'print'], menu: { label: 'Reports', route: '/reports', icon: 'reports', sortOrder: 65 } },
  { code: 'database', name: 'Database', icon: 'history', actions: ['view'], menu: { label: 'Database', route: '/database', icon: 'history', sortOrder: 90 } },
  { code: 'custom_entities', name: 'Custom entities', icon: 'reports', actions: ['view'], menu: { label: 'Custom entities', route: '/custom-entities', icon: 'reports', sortOrder: 91 } },
  { code: 'templates', name: 'Templates', icon: 'palette', actions: ['view'], menu: { label: 'Templates', route: '/templates', icon: 'palette', sortOrder: 92 } },
  { code: 'pages', name: 'Pages', icon: 'reports', actions: ['view', 'create', 'edit', 'delete'], menu: { label: 'Pages', route: '/pages', icon: 'reports', sortOrder: 93 } },
  { code: 'system', name: 'System', icon: 'settings', actions: ['view', 'manage_settings'], menu: { label: 'System', route: '/system', icon: 'settings', sortOrder: 95 } },
  { code: 'system_logs', name: 'System Logs', icon: 'history', actions: ['view', 'delete', 'export'], menu: { label: 'System Logs', route: '/system-logs', icon: 'history', sortOrder: 96 } },
  { code: 'login_events', name: 'Login Activity', icon: 'history', actions: ['view', 'export'], menu: { label: 'Login Activity', route: '/login-events', icon: 'history', sortOrder: 97 } },
  { code: 'approvals', name: 'Approvals', icon: 'shield', actions: ['view', 'approve'], menu: { label: 'Approvals', route: '/approvals', icon: 'shield', sortOrder: 55 } },
  { code: 'report_schedules', name: 'Report Schedules', icon: 'reports', actions: ['view', 'create', 'edit', 'delete'], menu: { label: 'Report Schedules', route: '/report-schedules', icon: 'reports', sortOrder: 67 } },
  { code: 'webhooks', name: 'Webhooks', icon: 'settings', actions: ['view', 'create', 'edit', 'delete'], menu: { label: 'Webhooks', route: '/webhooks', icon: 'settings', sortOrder: 98 } },
  { code: 'workflows', name: 'Workflows', icon: 'settings', actions: ['view', 'create', 'edit', 'delete', 'run'], menu: { label: 'Workflows', route: '/workflows', icon: 'settings', sortOrder: 68 } },
  { code: 'backups', name: 'Backups', icon: 'history', actions: ['view', 'create', 'delete'], menu: { label: 'Backups', route: '/backups', icon: 'history', sortOrder: 99 } },
  { code: 'translations', name: 'Translations', icon: 'palette', actions: ['view'], menu: { label: 'Translations', route: '/translations', icon: 'palette', sortOrder: 100 } },
];

// Phase 4.7 — sidebar label translations. The English value lives in
// `menu_items.label` (back-compat); Arabic/French in `menu_items.labels`
// JSON. Frontend MenuController falls back to `label` when a locale is
// missing, so partial translations are safe.
const MENU_LABELS = {
  dashboard:        { en: 'Dashboard',         ar: 'لوحة التحكم',     fr: 'Tableau de bord' },
  companies:        { en: 'Companies',         ar: 'الشركات',          fr: 'Sociétés' },
  branches:         { en: 'Branches',          ar: 'الفروع',           fr: 'Succursales' },
  users:            { en: 'Users',             ar: 'المستخدمون',       fr: 'Utilisateurs' },
  roles:            { en: 'Roles',             ar: 'الأدوار',          fr: 'Rôles' },
  audit:            { en: 'Audit Logs',        ar: 'سجلات التدقيق',    fr: "Journaux d'audit" },
  settings:         { en: 'Settings',          ar: 'الإعدادات',        fr: 'Paramètres' },
  themes:           { en: 'Appearance',        ar: 'المظهر',           fr: 'Apparence' },
  reports:          { en: 'Reports',           ar: 'التقارير',         fr: 'Rapports' },
  database:         { en: 'Database',          ar: 'قاعدة البيانات',   fr: 'Base de données' },
  custom_entities:  { en: 'Custom entities',   ar: 'الكيانات المخصصة', fr: 'Entités personnalisées' },
  templates:        { en: 'Templates',         ar: 'القوالب',          fr: 'Modèles' },
  pages:            { en: 'Pages',             ar: 'الصفحات',          fr: 'Pages' },
  system:           { en: 'System',            ar: 'النظام',           fr: 'Système' },
  system_logs:      { en: 'System Logs',       ar: 'سجلات النظام',     fr: 'Journaux système' },
  login_events:     { en: 'Login Activity',    ar: 'نشاط الدخول',      fr: 'Activité de connexion' },
  approvals:        { en: 'Approvals',         ar: 'الموافقات',        fr: 'Approbations' },
  report_schedules: { en: 'Report Schedules',  ar: 'جداول التقارير',   fr: 'Planifications de rapports' },
  webhooks:         { en: 'Webhooks',          ar: 'Webhooks',         fr: 'Webhooks' },
  workflows:        { en: 'Workflows',         ar: 'سير العمل',          fr: 'Workflows' },
  backups:          { en: 'Backups',           ar: 'النسخ الاحتياطية', fr: 'Sauvegardes' },
  translations:     { en: 'Translations',      ar: 'الترجمات',         fr: 'Traductions' },
};

const SAMPLE_REPORTS = [
  {
    code: 'users.by_role',
    name: 'Users by role',
    description: 'How many users are assigned to each role.',
    category: 'users',
    builder: 'users.by_role',
    config: {},
  },
  {
    code: 'users.active_status',
    name: 'Active vs inactive users',
    description: 'Count of active and inactive user accounts.',
    category: 'users',
    builder: 'users.active_status',
    config: {},
  },
  {
    code: 'companies.summary',
    name: 'Companies overview',
    description: 'Companies with branch and user counts.',
    category: 'organization',
    builder: 'companies.summary',
    config: {},
  },
  {
    code: 'audit.actions_summary',
    name: 'Audit — actions summary',
    description: 'Audit events grouped by action over a window.',
    category: 'audit',
    builder: 'audit.actions_summary',
    config: { days: 30 },
  },
  {
    code: 'audit.entities_summary',
    name: 'Audit — entities summary',
    description: 'Audit events grouped by target entity.',
    category: 'audit',
    builder: 'audit.entities_summary',
    config: { days: 30 },
  },
];

const ROLE_LABELS = {
  super_admin:   { en: 'Super Admin',    ar: 'المدير العام',   fr: 'Super Administrateur' },
  chairman:      { en: 'Chairman',       ar: 'رئيس مجلس الإدارة', fr: 'Président' },
  company_admin: { en: 'Company Admin',  ar: 'مدير الشركة',     fr: 'Administrateur Société' },
  manager:       { en: 'Manager',        ar: 'مدير',            fr: 'Gestionnaire' },
  employee:      { en: 'Employee',       ar: 'موظف',            fr: 'Employé' },
};

const ROLES = [
  {
    code: 'super_admin',
    name: 'Super Admin',
    description: 'Full system control. Bypasses permission checks.',
    isSystem: true,
    grants: 'all',
  },
  {
    code: 'chairman',
    name: 'Chairman',
    description: 'High-level visibility and approvals across all companies.',
    isSystem: true,
    grants: (p) => p.action === 'view' || p.action === 'approve' || p.action === 'export' || p.action === 'print',
  },
  {
    code: 'company_admin',
    name: 'Company Admin',
    description: 'Manages users, roles, branches, and settings inside a company.',
    isSystem: true,
    grants: (p) => {
      if (p.module === 'themes') return p.action === 'view';
      if (p.module === 'companies') return p.action !== 'delete';
      return true;
    },
  },
  {
    code: 'manager',
    name: 'Manager',
    description: 'Limited management of operational data.',
    isSystem: true,
    grants: (p) => {
      const allowed = ['view', 'create', 'edit', 'export', 'print', 'approve'];
      if (p.module === 'roles' || p.module === 'permissions' || p.module === 'themes') return p.action === 'view';
      if (p.module === 'audit') return p.action === 'view';
      if (p.module === 'settings') return p.action === 'view';
      // Phase 4.17 — managers can run workflows but not author/edit them.
      if (p.module === 'workflows') return p.action === 'view' || p.action === 'run';
      return allowed.includes(p.action);
    },
  },
  {
    code: 'employee',
    name: 'Employee',
    description: 'Default role for staff. Only the permissions explicitly granted.',
    isSystem: true,
    grants: (p) => p.module === 'dashboard' && p.action === 'view',
  },
];

const DEFAULT_THEME = {
  mode: 'light',
  primary: '#1F6FEB',
  secondary: '#0EA5E9',
  accent: '#22C55E',
  background: '#F4F6FA',
  surface: '#FFFFFF',
  sidebar: '#0F172A',
  sidebarText: '#E2E8F0',
  topbar: '#FFFFFF',
  topbarText: '#0F172A',
  textPrimary: '#0F172A',
  textSecondary: '#475569',
  buttonRadius: 10,
  cardRadius: 14,
  tableRadius: 10,
  fontFamily: 'Inter',
  fontSizeBase: 14,
  shadows: true,
  gradients: false,
  gradientFrom: '#1F6FEB',
  gradientTo: '#0EA5E9',
  gradientDirection: 'topLeftToBottomRight',
  loginStyle: 'split',
  dashboardLayout: 'cards',
  appName: 'TatbeeqX',
  logoUrl: null,
  faviconUrl: null,
  backgroundImageUrl: null,
  // Phase 4 — transparency & overlay
  surfaceOpacity: 1.0,
  sidebarOpacity: 1.0,
  topbarOpacity: 1.0,
  cardOpacity: 1.0,
  backgroundOpacity: 1.0,
  backgroundBlur: 0,
  backgroundOverlayColor: '#000000',
  backgroundOverlayOpacity: 0.0,
  loginOverlayColor: '#000000',
  loginOverlayOpacity: 0.35,
  enableGlass: false,
  glassBlur: 12,
  glassTint: '#FFFFFF',
  glassTintOpacity: 0.6,
};

async function seedPermissions() {
  const all = [];
  for (const mod of MODULES) {
    for (const action of mod.actions) {
      const code = `${mod.code}.${action}`;
      all.push({
        code,
        name: `${mod.name} — ${ACTION_LABEL[action] ?? action}`,
        module: mod.code,
        action,
      });
    }
  }
  for (const p of all) {
    await prisma.permission.upsert({
      where: { code: p.code },
      update: { name: p.name, module: p.module, action: p.action },
      create: p,
    });
  }
  return prisma.permission.findMany();
}

async function seedRoles(allPermissions) {
  for (const r of ROLES) {
    const labels = JSON.stringify(ROLE_LABELS[r.code] ?? {});
    const role = await prisma.role.upsert({
      where: { code: r.code },
      update: { name: r.name, labels, description: r.description, isSystem: r.isSystem },
      create: { code: r.code, name: r.name, labels, description: r.description, isSystem: r.isSystem },
    });

    const grant = (p) => (r.grants === 'all' ? true : r.grants(p));
    const targetIds = allPermissions.filter(grant).map((p) => p.id);

    await prisma.rolePermission.deleteMany({ where: { roleId: role.id } });
    if (targetIds.length) {
      await prisma.rolePermission.createMany({
        data: targetIds.map((permissionId) => ({ roleId: role.id, permissionId })),
      });
    }
  }
}

async function seedModulesAndMenus() {
  for (const [index, mod] of MODULES.entries()) {
    const m = await prisma.module.upsert({
      where: { code: mod.code },
      update: { name: mod.name, icon: mod.icon, sortOrder: (index + 1) * 10, isCore: true },
      create: { code: mod.code, name: mod.name, icon: mod.icon, sortOrder: (index + 1) * 10, isCore: true },
    });
    if (mod.menu) {
      const permissionCode = `${mod.code}.view`;
      const labels = JSON.stringify(MENU_LABELS[mod.code] ?? {});
      await prisma.menuItem.upsert({
        where: { code: `menu.${mod.code}` },
        update: {
          moduleId: m.id,
          label: mod.menu.label,
          labels,
          icon: mod.menu.icon,
          route: mod.menu.route,
          permissionCode,
          sortOrder: mod.menu.sortOrder,
          isActive: true,
        },
        create: {
          code: `menu.${mod.code}`,
          moduleId: m.id,
          label: mod.menu.label,
          labels,
          icon: mod.menu.icon,
          route: mod.menu.route,
          permissionCode,
          sortOrder: mod.menu.sortOrder,
        },
      });
    }
  }
}

async function seedSampleCompany() {
  const company = await prisma.company.upsert({
    where: { code: 'DEMO' },
    update: { name: 'Demo Company' },
    create: {
      code: 'DEMO',
      name: 'Demo Company',
      legalName: 'Demo Company Ltd.',
      email: 'info@demo.local',
      phone: '+00 000 000 000',
      address: '1 Sample Street',
      isActive: true,
    },
  });
  const existingBranch = await prisma.branch.findFirst({
    where: { companyId: company.id, code: 'MAIN' },
  });
  if (!existingBranch) {
    await prisma.branch.create({
      data: {
        companyId: company.id,
        code: 'MAIN',
        name: 'Main Branch',
        address: 'Headquarters',
        isActive: true,
      },
    });
  }
  return company;
}

async function seedSuperAdmin() {
  const passwordHash = await bcrypt.hash(SEED.password, 10);
  const role = await prisma.role.findUnique({ where: { code: 'super_admin' } });
  const user = await prisma.user.upsert({
    where: { username: SEED.username },
    update: { isActive: true, isSuperAdmin: true, fullName: 'Super Admin' },
    create: {
      username: SEED.username,
      email: SEED.email,
      passwordHash,
      fullName: 'Super Admin',
      isActive: true,
      isSuperAdmin: true,
    },
  });
  if (role) {
    await prisma.userRole.upsert({
      where: { userId_roleId: { userId: user.id, roleId: role.id } },
      update: {},
      create: { userId: user.id, roleId: role.id },
    });
  }
  return user;
}

async function seedDefaultTheme() {
  const existing = await prisma.theme.findFirst({ where: { isDefault: true } });
  if (existing) return existing;
  return prisma.theme.create({
    data: {
      name: 'Default Professional',
      data: JSON.stringify(DEFAULT_THEME),
      isDefault: true,
      isActive: true,
    },
  });
}

async function seedReports() {
  for (const r of SAMPLE_REPORTS) {
    await prisma.report.upsert({
      where: { code: r.code },
      update: {
        name: r.name,
        description: r.description,
        category: r.category,
        builder: r.builder,
        config: JSON.stringify(r.config),
        isSystem: true,
        isActive: true,
      },
      create: {
        code: r.code,
        name: r.name,
        description: r.description,
        category: r.category,
        builder: r.builder,
        config: JSON.stringify(r.config),
        isSystem: true,
        isActive: true,
      },
    });
  }
}

async function seedDefaultSettings() {
  const items = [
    { key: 'app.name', value: 'TatbeeqX', isPublic: true },
    { key: 'app.locale', value: 'en', isPublic: true },
    { key: 'app.timezone', value: 'UTC', isPublic: true },
  ];
  for (const it of items) {
    const existing = await prisma.setting.findFirst({ where: { companyId: null, key: it.key } });
    if (existing) {
      await prisma.setting.update({
        where: { id: existing.id },
        data: { value: it.value, isPublic: it.isPublic, type: 'string' },
      });
    } else {
      await prisma.setting.create({
        data: { companyId: null, key: it.key, value: it.value, isPublic: it.isPublic, type: 'string' },
      });
    }
  }
}

async function main() {
  console.log('Seeding...');
  const permissions = await seedPermissions();
  await seedRoles(permissions);
  await seedModulesAndMenus();
  await seedSampleCompany();
  await seedSuperAdmin();
  await seedDefaultTheme();
  await seedReports();
  await seedDefaultSettings();

  const presetCode = (process.env.SEED_BUSINESS_TYPE || '').trim();
  if (presetCode && PRESETS[presetCode]) {
    console.log(`Applying business preset: ${presetCode}`);
    await applyPreset(presetCode);
  } else if (presetCode) {
    console.log(`Unknown SEED_BUSINESS_TYPE "${presetCode}" — pick one of: ${Object.keys(PRESETS).join(', ')}`);
  }

  console.log('Seed complete.');
  console.log(`  Login:     ${SEED.username}`);
  console.log(`  Password:  ${SEED.password}`);
  if (!presetCode) {
    console.log('  Business:  not chosen yet — pick from the in-app setup wizard or set SEED_BUSINESS_TYPE.');
  }
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
