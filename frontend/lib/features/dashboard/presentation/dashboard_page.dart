import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/charts.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';

// Single boot fetch — bundles summary + audit-by-day + audit-by-module
// into one round-trip. The three providers below derive their shapes
// from this one Future, so they all light up together when the bundled
// payload arrives. See backend/src/routes/dashboard.js — `/bootstrap`.
final _dashboardBootstrapProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getJson('/dashboard/bootstrap', query: {
    'auditByDayDays': 14,
    'auditByModuleDays': 30,
  });
});

final _dashboardSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final boot = await ref.watch(_dashboardBootstrapProvider.future);
  return (boot['summary'] as Map).cast<String, dynamic>();
});

final _auditByDayProvider = FutureProvider.autoDispose<List<BarChartData>>((ref) async {
  final boot = await ref.watch(_dashboardBootstrapProvider.future);
  final res = (boot['auditByDay'] as Map).cast<String, dynamic>();
  final series = (res['series'] as List? ?? const []).cast<Map<String, dynamic>>();
  return series.map((m) {
    final d = DateTime.tryParse(m['date'].toString());
    final label = d == null ? m['date'].toString() : DateFormat('MM-dd').format(d);
    return BarChartData(label: label, value: (m['count'] as num).toDouble());
  }).toList();
});

final _auditByModuleProvider = FutureProvider.autoDispose<List<BarChartData>>((ref) async {
  final boot = await ref.watch(_dashboardBootstrapProvider.future);
  final res = (boot['auditByModule'] as Map).cast<String, dynamic>();
  final series = (res['series'] as List? ?? const []).cast<Map<String, dynamic>>();
  return series.map((m) => BarChartData(
        label: m['entity'].toString(),
        value: (m['count'] as num).toDouble(),
      )).toList();
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 4.20 perf — narrow watches with select() so the page
    // doesn't rebuild on every transient AuthState change (loading
    // flips, unreadNotifications poll updates, etc). Only the user
    // field is read here.
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final summary = ref.watch(_dashboardSummaryProvider);
    final byDay = ref.watch(_auditByDayProvider);
    final byModule = ref.watch(_auditByModuleProvider);

    final t = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: user != null
                ? '${t.dashboard} — ${user.fullName.split(' ').first}'
                : t.dashboard,
            subtitle: t.dashboardSubtitle,
          ),
          summary.when(
            loading: () => const SizedBox(height: 240, child: LoadingView()),
            error: (e, _) => _ErrorBox(message: e.toString()),
            data: (data) => _DashboardBody(data: data, byDay: byDay, byModule: byModule),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data, required this.byDay, required this.byModule});
  final Map<String, dynamic> data;
  final AsyncValue<List<BarChartData>> byDay;
  final AsyncValue<List<BarChartData>> byModule;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Phase 4.20 perf — hoist these so the inline list mappings don't
    // walk the inherited-widget tree once per item.
    final smallText = Theme.of(context).textTheme.bodySmall;
    final counts = (data['counts'] as Map<String, dynamic>? ?? const {});
    final recentLogins = (data['recentLogins'] as List? ?? const []);
    final recentAudit = (data['recentAudit'] as List? ?? const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (ctx, c) {
          final cols = c.maxWidth >= 1100 ? 5 : c.maxWidth >= 800 ? 3 : 2;
          final cards = [
            _StatCard(label: t.users, value: '${counts['users'] ?? 0}', icon: Icons.people_outline),
            _StatCard(label: t.companies, value: '${counts['companies'] ?? 0}', icon: Icons.business_outlined),
            _StatCard(label: t.branches, value: '${counts['branches'] ?? 0}', icon: Icons.store_outlined),
            _StatCard(label: t.roles, value: '${counts['roles'] ?? 0}', icon: Icons.shield_outlined),
            _StatCard(label: t.auditEventsCount, value: '${counts['audit'] ?? 0}', icon: Icons.history),
          ];
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.4,
            children: cards,
          );
        }),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (ctx, c) {
          final stacked = c.maxWidth < 900;
          final left = _PanelCard(
            title: t.auditEventsLast14,
            child: SizedBox(
              height: 220,
              child: byDay.when(
                loading: () => const LoadingView(),
                error: (e, _) => Text(t.failedShort(e.toString()), style: const TextStyle(color: Colors.red)),
                data: (bars) => bars.isEmpty
                    ? Center(child: Text(t.noActivityYet))
                    : SimpleBarChart(bars: bars),
              ),
            ),
          );
          final rightLogins = _PanelCard(
            title: t.recentLogins,
            child: Column(
              children: [
                if (recentLogins.isEmpty)
                  Padding(padding: const EdgeInsets.all(12), child: Text(t.noDataYet)),
                ...recentLogins.map((u) {
                  final m = u as Map<String, dynamic>;
                  final dt = m['lastLoginAt'] as String?;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(((m['fullName'] ?? m['username']) as String).substring(0, 1).toUpperCase())),
                    title: Text((m['fullName'] ?? m['username']) as String),
                    subtitle: Text(m['username'] as String),
                    trailing: Text(_fmtDate(dt), style: smallText),
                  );
                }),
              ],
            ),
          );
          if (stacked) {
            return Column(children: [left, const SizedBox(height: 16), rightLogins]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: rightLogins),
            ],
          );
        }),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (ctx, c) {
          final stacked = c.maxWidth < 900;
          final left = _PanelCard(
            title: t.auditByEntityLast30,
            child: byModule.when(
              loading: () => const LoadingView(),
              error: (e, _) => Text(t.failedShort(e.toString()), style: const TextStyle(color: Colors.red)),
              data: (bars) => HorizontalBarList(bars: bars),
            ),
          );
          final right = _PanelCard(
            title: t.recentAuditEvents,
            child: Column(
              children: [
                if (recentAudit.isEmpty)
                  Padding(padding: const EdgeInsets.all(12), child: Text(t.noAuditEntriesYet)),
                ...recentAudit.map((e) {
                  final m = e as Map<String, dynamic>;
                  final user = m['user'] as Map<String, dynamic>?;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text('${m['action']} → ${m['entity']}${m['entityId'] != null ? ' #${m['entityId']}' : ''}'),
                    subtitle: Text(user?['fullName']?.toString() ?? user?['username']?.toString() ?? t.systemUserLabel),
                    trailing: Text(_fmtDate(m['createdAt'] as String?), style: smallText),
                  );
                }),
              ],
            ),
          );
          if (stacked) return Column(children: [left, const SizedBox(height: 16), right]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: right),
            ],
          );
        }),
      ],
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    return DateFormat('MMM d, HH:mm').format(d);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(AppLocalizations.of(context).loadFailed(message), style: const TextStyle(color: Colors.red)),
    );
  }
}
