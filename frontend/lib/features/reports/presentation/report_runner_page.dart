import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/charts.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';

class ReportRunnerPage extends ConsumerStatefulWidget {
  const ReportRunnerPage({super.key, required this.report});
  final Map<String, dynamic> report;

  @override
  ConsumerState<ReportRunnerPage> createState() => _ReportRunnerPageState();
}

class _ReportRunnerPageState extends ConsumerState<ReportRunnerPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _columns = [];
  List<Map<String, dynamic>> _rows = [];
  bool _showAsChart = false;

  late final Map<String, dynamic> _params;

  @override
  void initState() {
    super.initState();
    _params = Map<String, dynamic>.from((widget.report['config'] as Map?) ?? const {});
    Future.microtask(_run);
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .postJson('/reports/${widget.report['id']}/run', body: _params);
      setState(() {
        _columns = (res['columns'] as List).cast<Map<String, dynamic>>();
        _rows = (res['rows'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _chartable {
    if (_columns.length < 2) return false;
    final numericCols = _columns.where((c) => c['numeric'] == true).toList();
    return numericCols.isNotEmpty;
  }

  List<BarChartData> _buildBars() {
    final labelKey = _columns.first['key'].toString();
    final numericCol = _columns.firstWhere(
      (c) => c['numeric'] == true,
      orElse: () => _columns[1],
    );
    final valKey = numericCol['key'].toString();
    return _rows.map((r) {
      final v = r[valKey];
      final num n = v is num ? v : num.tryParse('$v') ?? 0;
      return BarChartData(label: r[labelKey].toString(), value: n.toDouble());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.report['name'].toString()),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.refresh),
          ),
          if (_chartable)
            IconButton(
              tooltip: _showAsChart ? 'Show table' : 'Show chart',
              onPressed: () => setState(() => _showAsChart = !_showAsChart),
              icon: Icon(_showAsChart ? Icons.table_chart_outlined : Icons.bar_chart_outlined),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: widget.report['name'].toString(),
              subtitle: widget.report['description']?.toString(),
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: LoadingView())
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Run failed: $_error', style: const TextStyle(color: Colors.red)),
              )
            else if (_rows.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No rows')))
            else if (_showAsChart)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(height: 320, child: SimpleBarChart(bars: _buildBars())),
                ),
              )
            else
              _ResultTable(columns: _columns, rows: _rows),
          ],
        ),
      ),
    );
  }
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.columns, required this.rows});
  final List<Map<String, dynamic>> columns;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          Container(
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                for (final c in columns)
                  Expanded(
                    child: Align(
                      alignment: c['numeric'] == true ? Alignment.centerRight : Alignment.centerLeft,
                      child: Text(c['label'].toString(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline),
            itemBuilder: (_, i) {
              final row = rows[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    for (final c in columns)
                      Expanded(
                        child: Align(
                          alignment: c['numeric'] == true ? Alignment.centerRight : Alignment.centerLeft,
                          child: Text(row[c['key']]?.toString() ?? ''),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
