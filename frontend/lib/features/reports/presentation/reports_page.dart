import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';
import 'report_runner_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).getJson('/reports');
      setState(() {
        _reports = (res['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).loadFailed(e.toString()))),
      );
    }
  }

  void _open(Map<String, dynamic> report) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportRunnerPage(report: report)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    if (!auth.can('reports.view')) {
      return Center(child: Text(t.noPermissionReports));
    }
    final byCat = <String, List<Map<String, dynamic>>>{};
    for (final r in _reports) {
      final c = r['category']?.toString() ?? 'general';
      byCat.putIfAbsent(c, () => []).add(r);
    }
    final cats = byCat.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.reports,
            subtitle: t.reportsSubtitle,
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: LoadingView())
          else if (_reports.isEmpty)
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(t.noReportsDefined)))
          else
            for (final cat in cats) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(cat.toUpperCase(), style: Theme.of(context).textTheme.bodySmall),
              ),
              LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 700 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.4,
                  children: byCat[cat]!.map((r) => _ReportCard(data: r, onOpen: () => _open(r))).toList(),
                );
              }),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.data, required this.onOpen});
  final Map<String, dynamic> data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_outlined, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'].toString(), style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (data['description'] != null)
                      Text(
                        data['description'].toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
