import { Router } from 'express';
// Phase 4.16 — `// MOD: <code>` markers tag *optional* modules so the
// build-subsystem pruner can strip lines whose code isn't in the
// template's `modules` array. Unmarked lines (auth/dashboard/users/etc.)
// are core/infra and always kept regardless. See tools/build-subsystem/prune.mjs.
import auth from './auth.js';
import users from './users.js';
import roles from './roles.js';
import permissions from './permissions.js';
import companies from './companies.js';
import branches from './branches.js';
import menus from './menus.js';
import audit from './audit.js';
import settings from './settings.js';
import themes from './themes.js';                     // MOD: themes
import dashboard from './dashboard.js';
import reports from './reports.js';
import uploads from './uploads.js';
import database from './database.js';                 // MOD: database
import customEntities from './custom_entities.js';    // MOD: custom-entities
import customRecords from './custom_records.js';      // MOD: custom-entities
import business from './business.js';                 // MOD: business
import templates from './templates.js';               // MOD: templates
import pages from './pages.js';                       // MOD: pages
import systemLogs from './system_logs.js';            // MOD: system-logs
import loginEvents from './login_events.js';          // MOD: login-events
import system from './system.js';                     // MOD: system
import approvals from './approvals.js';               // MOD: approvals
import reportSchedules from './report_schedules.js';  // MOD: report-schedules
import webhooks from './webhooks.js';                 // MOD: webhooks
import workflows from './workflows.js';               // MOD: workflows
import notifications from './notifications.js';       // MOD: notifications
import admin from './admin.js';
import subsystem from './subsystem.js';

const router = Router();

router.get('/health', (_req, res) => res.json({ ok: true, time: new Date().toISOString() }));

// Phase 4.12 — public, no auth. See routes/subsystem.js for why.
router.use('/subsystem', subsystem);

router.use('/auth', auth);
router.use('/users', users);
router.use('/roles', roles);
router.use('/permissions', permissions);
router.use('/companies', companies);
router.use('/branches', branches);
router.use('/menus', menus);
router.use('/audit', audit);
router.use('/settings', settings);
router.use('/themes', themes);                  // MOD: themes
router.use('/dashboard', dashboard);
router.use('/reports', reports);
router.use('/uploads', uploads);
router.use('/db', database);                    // MOD: database
router.use('/custom-entities', customEntities); // MOD: custom-entities
router.use('/c/:code', customRecords);          // MOD: custom-entities
router.use('/business', business);              // MOD: business
router.use('/templates', templates);            // MOD: templates
router.use('/pages', pages);                    // MOD: pages
router.use('/system-logs', systemLogs);         // MOD: system-logs
router.use('/login-events', loginEvents);       // MOD: login-events
router.use('/system', system);                  // MOD: system
router.use('/approvals', approvals);            // MOD: approvals
router.use('/report-schedules', reportSchedules); // MOD: report-schedules
router.use('/webhooks', webhooks);              // MOD: webhooks
router.use('/workflows', workflows);            // MOD: workflows
router.use('/notifications', notifications);    // MOD: notifications
router.use('/admin', admin);

export default router;
