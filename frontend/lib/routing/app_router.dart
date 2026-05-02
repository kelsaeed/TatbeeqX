import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Phase 4.16 — `// MOD: <code>` markers tag *optional* modules so the
// build-subsystem pruner can strip lines whose code isn't in the
// template's `modules` array. Unmarked lines (auth/dashboard/users/etc.)
// are core/infra and always kept. Multi-line GoRoute blocks for
// optional modules are wrapped in `// MOD-BEGIN: <code>` /
// `// MOD-END: <code>`. See tools/build-subsystem/prune.mjs.

import '../core/subsystem/subsystem_info.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/setup/setup_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/reset_password_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/dashboard/presentation/dashboard_shell.dart';
import '../features/users/presentation/users_page.dart';
import '../features/roles/presentation/roles_page.dart';
import '../features/companies/presentation/companies_page.dart';
import '../features/companies/presentation/branches_page.dart';
import '../features/audit/presentation/audit_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/themes/presentation/themes_page.dart';                     // MOD: themes
import '../features/themes/presentation/theme_builder_page.dart';              // MOD: themes
import '../features/reports/presentation/reports_page.dart';
import '../features/setup/setup_page.dart';
import '../features/database/presentation/database_page.dart';                 // MOD: database
import '../features/custom_entities/presentation/custom_entities_page.dart';   // MOD: custom-entities
import '../features/custom/presentation/custom_list_page.dart';                // MOD: custom-entities
import '../features/templates/presentation/templates_page.dart';               // MOD: templates
import '../features/system/presentation/system_page.dart';                     // MOD: system
import '../features/system_logs/presentation/system_logs_page.dart';           // MOD: system-logs
import '../features/login_events/presentation/login_events_page.dart';         // MOD: login-events
import '../features/pages/presentation/pages_page.dart';                       // MOD: pages
import '../features/pages/presentation/page_builder_page.dart';                // MOD: pages
import '../features/pages/presentation/page_renderer.dart';                    // MOD: pages
import '../features/approvals/presentation/approvals_page.dart';               // MOD: approvals
import '../features/report_schedules/presentation/report_schedules_page.dart'; // MOD: report-schedules
import '../features/webhooks/presentation/webhooks_page.dart';                 // MOD: webhooks
import '../features/workflows/presentation/workflows_page.dart';               // MOD: workflows
import '../features/backups/presentation/backups_page.dart';
import '../features/translations/presentation/translations_page.dart';         // MOD: translations
import '../features/translations/presentation/translations_editor_page.dart';  // MOD: translations
import '../features/sessions/presentation/sessions_page.dart';

// IMPORTANT: do NOT `ref.watch` auth/setup at the provider level here.
// Doing so rebuilds the GoRouter on every auth/setup state change, which
// in turn forces `MaterialApp.router` to remount the entire navigator
// tree (the ShellRoute and every page inside it). That's why a server log
// at boot used to show `/api/menus`, `/api/companies`, `/api/dashboard/*`
// firing 2-3× — every state change re-ran every `initState`. Instead:
//
//   1. The redirect closure `ref.read`s state at call time (closures
//      capture `ref`, and the redirect runs per-navigation).
//   2. A `refreshListenable` adapter pokes the existing router whenever
//      auth or setup state changes, so redirects re-evaluate without
//      recreating the router or remounting anything.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refreshListenable,
    redirect: (ctx, state) {
      final auth = ref.read(authControllerProvider);
      final setup = ref.read(setupControllerProvider);
      final subsystem = ref.read(subsystemInfoProvider).valueOrNull
          ?? SubsystemInfo.empty;
      if (!auth.bootstrapped) return null;
      final path = state.matchedLocation;
      final loggingIn = path == '/login';
      // Phase 4.16 follow-up — /reset-password is a public route.
      // The user redeeming a token may not be logged in (most common
      // case). Skip the auth-gate for this path.
      final resetting = path == '/reset-password';
      if (!auth.isLoggedIn && !loggingIn && !resetting) return '/login';
      if (auth.isLoggedIn && loggingIn) return '/dashboard';

      // Phase 4.12 — in lockdown, redirect away from super-admin surfaces.
      // Backend permission checks still enforce; this is UX cleanup so a
      // bookmarked or typed URL doesn't leak the super-admin pages.
      if (auth.isLoggedIn && subsystem.isPathBlocked(path)) {
        return '/dashboard';
      }

      if (auth.isLoggedIn && auth.user!.isSuperAdmin) {
        final s = setup.valueOrNull;
        if (s != null && !s.configured && path != '/setup' && path != '/themes' && !path.startsWith('/themes/')) {
          return '/setup';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      // Phase 4.16 follow-up — public reset-password page. Reads
      // `?token=...` from the query so admin-shared reset URLs
      // pre-fill the field.
      GoRoute(
        path: '/reset-password',
        builder: (_, st) => ResetPasswordPage(
          initialToken: st.uri.queryParameters['token'],
        ),
      ),
      GoRoute(path: '/setup', builder: (_, __) => const SetupPage()),
      ShellRoute(
        builder: (ctx, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/users', builder: (_, __) => const UsersPage()),
          GoRoute(path: '/roles', builder: (_, __) => const RolesPage()),
          GoRoute(path: '/companies', builder: (_, __) => const CompaniesPage()),
          GoRoute(path: '/branches', builder: (_, __) => const BranchesPage()),
          GoRoute(path: '/audit', builder: (_, __) => const AuditPage()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsPage()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
          // MOD-BEGIN: database
          GoRoute(path: '/database', builder: (_, __) => const DatabasePage()),
          // MOD-END: database
          // MOD-BEGIN: custom-entities
          GoRoute(path: '/custom-entities', builder: (_, __) => const CustomEntitiesPage()),
          // MOD-END: custom-entities
          // MOD-BEGIN: templates
          GoRoute(path: '/templates', builder: (_, __) => const TemplatesPage()),
          // MOD-END: templates
          // MOD-BEGIN: system
          GoRoute(path: '/system', builder: (_, __) => const SystemPage()),
          // MOD-END: system
          // MOD-BEGIN: system-logs
          GoRoute(path: '/system-logs', builder: (_, __) => const SystemLogsPage()),
          // MOD-END: system-logs
          // MOD-BEGIN: login-events
          GoRoute(path: '/login-events', builder: (_, __) => const LoginEventsPage()),
          // MOD-END: login-events
          // MOD-BEGIN: approvals
          GoRoute(path: '/approvals', builder: (_, __) => const ApprovalsPage()),
          // MOD-END: approvals
          // MOD-BEGIN: report-schedules
          GoRoute(path: '/report-schedules', builder: (_, __) => const ReportSchedulesPage()),
          // MOD-END: report-schedules
          // MOD-BEGIN: webhooks
          GoRoute(path: '/webhooks', builder: (_, __) => const WebhooksPage()),
          // MOD-END: webhooks
          // MOD-BEGIN: workflows
          GoRoute(path: '/workflows', builder: (_, __) => const WorkflowsPage()),
          // MOD-END: workflows
          GoRoute(path: '/backups', builder: (_, __) => const BackupsPage()),
          // Phase 4.16 follow-up — per-user sessions / active devices
          // page. Always available to authenticated users; no module
          // gating since every account needs to manage its own
          // refresh tokens.
          GoRoute(path: '/sessions', builder: (_, __) => const SessionsPage()),
          // MOD-BEGIN: translations
          GoRoute(
            path: '/translations',
            builder: (_, __) => const TranslationsPage(),
            routes: [
              GoRoute(
                path: 'edit/:locale',
                builder: (_, st) => TranslationsEditorPage(
                  locale: st.pathParameters['locale']!,
                ),
              ),
            ],
          ),
          // MOD-END: translations
          // MOD-BEGIN: pages
          GoRoute(
            path: '/pages',
            builder: (_, __) => const PagesPage(),
            routes: [
              GoRoute(
                path: 'edit/:id',
                builder: (_, st) => PageBuilderPage(pageId: int.parse(st.pathParameters['id']!)),
              ),
            ],
          ),
          GoRoute(
            path: '/p/:slug',
            builder: (_, st) => PageRenderer(slug: st.pathParameters['slug']!),
          ),
          // MOD-END: pages
          // MOD-BEGIN: custom-entities
          GoRoute(
            path: '/c/:code',
            builder: (_, st) => CustomListPage(code: st.pathParameters['code']!),
          ),
          // MOD-END: custom-entities
          // MOD-BEGIN: themes
          GoRoute(
            path: '/themes',
            builder: (_, __) => const ThemesPage(),
            routes: [
              GoRoute(
                path: 'edit/:id',
                builder: (_, st) => ThemeBuilderPage(themeId: int.parse(st.pathParameters['id']!)),
              ),
            ],
          ),
          // MOD-END: themes
        ],
      ),
    ],
    errorBuilder: (_, st) => Scaffold(body: Center(child: Text('Route error: ${st.error}'))),
  );
});

// Bridges Riverpod state changes to a Listenable that GoRouter can listen
// to. Each notify just tells the router "re-evaluate your redirect for the
// current location" — the router instance, the navigator stack, and every
// mounted route stay in place.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    _authSub = ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
    _setupSub = ref.listen<AsyncValue>(
      setupControllerProvider,
      (_, __) => notifyListeners(),
    );
    // Phase 4.12 — lockdown info also affects redirects, so re-evaluate
    // when the subsystem info finally loads (it's an async bootstrap).
    _subsysSub = ref.listen<AsyncValue<SubsystemInfo>>(
      subsystemInfoProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _authSub;
  late final ProviderSubscription<AsyncValue> _setupSub;
  late final ProviderSubscription<AsyncValue<SubsystemInfo>> _subsysSub;

  @override
  void dispose() {
    _authSub.close();
    _setupSub.close();
    _subsysSub.close();
    super.dispose();
  }
}
