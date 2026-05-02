import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';
import 'sql_runner_panel.dart';

class DatabasePage extends ConsumerStatefulWidget {
  const DatabasePage({super.key});

  @override
  ConsumerState<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends ConsumerState<DatabasePage> {
  bool _loading = true;
  List<Map<String, dynamic>> _tables = [];
  String? _selected;
  Map<String, dynamic>? _details;
  List<Map<String, dynamic>> _preview = [];
  bool _detailsLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadTables);
  }

  Future<void> _loadTables() async {
    final api = ref.read(apiClientProvider);
    setState(() => _loading = true);
    try {
      final res = await api.getJson('/db/tables');
      setState(() {
        _tables = (res['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
        if (_selected == null && _tables.isNotEmpty) {
          _selected = _tables.first['name'].toString();
          _loadDetails(_selected!);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).loadFailed(e.toString()))),
      );
    }
  }

  Future<void> _loadDetails(String name) async {
    final api = ref.read(apiClientProvider);
    setState(() => _detailsLoading = true);
    try {
      final info = await api.getJson('/db/tables/$name');
      final preview = await api.getJson('/db/tables/$name/preview', query: {'limit': 50});
      setState(() {
        _details = info;
        _preview = (preview['items'] as List).cast<Map<String, dynamic>>();
        _detailsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).describeFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    if (!auth.user!.isSuperAdmin) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text(t.databaseRestricted)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.database,
            subtitle: t.databaseSubtitle,
            actions: [
              OutlinedButton.icon(
                onPressed: _loadTables,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(t.refresh),
              ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: LoadingView())
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 280,
                  child: Card(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.table_chart_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text('${_tables.length} tables', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 600),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _tables.length,
                            itemBuilder: (_, i) {
                              final t = _tables[i];
                              final selected = _selected == t['name'];
                              return ListTile(
                                dense: true,
                                selected: selected,
                                title: Text(t['name'].toString()),
                                subtitle: Text('${t['rowCount']} rows', style: Theme.of(context).textTheme.bodySmall),
                                onTap: () {
                                  setState(() => _selected = t['name'].toString());
                                  _loadDetails(_selected!);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selected != null)
                        _DetailsCard(
                          loading: _detailsLoading,
                          details: _details,
                          preview: _preview,
                        ),
                      const SizedBox(height: 16),
                      const SqlRunnerPanel(),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.loading, required this.details, required this.preview});
  final bool loading;
  final Map<String, dynamic>? details;
  final List<Map<String, dynamic>> preview;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (loading) {
      return const Card(child: Padding(padding: EdgeInsets.all(40), child: LoadingView()));
    }
    if (details == null) return const SizedBox.shrink();
    final cols = (details!['columns'] as List? ?? const []).cast<Map<String, dynamic>>();
    final fks = (details!['foreignKeys'] as List? ?? const []);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details!['name'].toString(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).columnsHeader, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    color: cs.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: const [
                        Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Default', style: TextStyle(fontWeight: FontWeight.w600))),
                        SizedBox(width: 50, child: Text('PK', style: TextStyle(fontWeight: FontWeight.w600))),
                        SizedBox(width: 60, child: Text('NULL', style: TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  for (final c in cols) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(c['name'].toString())),
                          Expanded(flex: 2, child: Text(c['type']?.toString() ?? '')),
                          Expanded(flex: 2, child: Text(c['default']?.toString() ?? '')),
                          SizedBox(width: 50, child: c['pk'] == true ? const Icon(Icons.key, size: 14) : const SizedBox()),
                          SizedBox(width: 60, child: Text(c['notnull'] == true ? 'NO' : 'YES', style: Theme.of(context).textTheme.bodySmall)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (fks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context).foreignKeysHeader, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final fk in fks)
                Text('• ${fk['from']} → ${fk['table']}.${fk['to']}', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).previewHeader(preview.length), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: preview.first.keys.map((k) => DataColumn(label: Text(k))).toList(),
                  rows: preview.map((row) => DataRow(
                    cells: row.values.map((v) => DataCell(Text(v?.toString() ?? ''))).toList(),
                  )).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
