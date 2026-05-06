// Phase 4.21 (c) — Pivot / group-by UI.
//
// Frontend-only transformation layer over the report's raw rows. The
// API response is unchanged; the page derives a "display" view from
// the rows by applying optional group-by + per-column aggregations,
// and optionally a pivot column that turns categorical values into
// new columns.
//
// State is session-only — closing the runner resets the view. No
// per-user persistence, no "save this view" — we keep that as
// follow-up work once the basic shape settles.

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

  // Raw response from the API.
  List<Map<String, dynamic>> _rawColumns = [];
  List<Map<String, dynamic>> _rawRows = [];

  // Derived view that the table + chart actually render. Equals raw
  // when no transform is active; otherwise the result of group-by /
  // pivot.
  List<Map<String, dynamic>> _displayColumns = [];
  List<Map<String, dynamic>> _displayRows = [];

  bool _showAsChart = false;

  // Group-by / pivot state.
  String? _groupBy;
  String? _pivotBy;
  String? _pivotValueCol;
  String _pivotValueAgg = 'sum';
  // Per-column aggregation when grouping without pivot. Key = column
  // key, value = aggregation name. Missing entries get a default
  // based on the column's `numeric` flag at apply time.
  final Map<String, String> _aggregations = {};

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
        _rawColumns = (res['columns'] as List).cast<Map<String, dynamic>>();
        _rawRows = (res['rows'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
      _applyTransform();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Aggregation. Skips null / empty-string values so "missing input
  // → missing output" matches the formula evaluator + SQL convention.
  // Returns null when no values remain (e.g. avg of an empty group).
  dynamic _aggregate(String agg, List<dynamic> values) {
    final nonNull = values.where((v) => v != null && v != '').toList();
    num? numOf(dynamic v) {
      if (v is num) return v;
      return num.tryParse('$v');
    }
    switch (agg) {
      case 'sum':
        var s = 0.0;
        var any = false;
        for (final v in nonNull) {
          final n = numOf(v);
          if (n != null) { s += n; any = true; }
        }
        return any ? s : null;
      case 'avg':
        var s = 0.0;
        var c = 0;
        for (final v in nonNull) {
          final n = numOf(v);
          if (n != null) { s += n; c++; }
        }
        return c == 0 ? null : s / c;
      case 'min':
      case 'max': {
        num? best;
        for (final v in nonNull) {
          final n = numOf(v);
          if (n == null) continue;
          if (best == null || (agg == 'min' ? n < best : n > best)) best = n;
        }
        return best;
      }
      case 'count':
        return nonNull.length;
      case 'count_distinct':
        return nonNull.toSet().length;
      case 'first':
        return nonNull.isEmpty ? null : nonNull.first;
      case 'hide':
        return null;
      default:
        return null;
    }
  }

  String _aggLabel(String agg) {
    switch (agg) {
      case 'sum': return 'sum';
      case 'avg': return 'avg';
      case 'min': return 'min';
      case 'max': return 'max';
      case 'count': return 'count';
      case 'count_distinct': return 'distinct';
      case 'first': return 'first';
      case 'hide': return 'hide';
      default: return agg;
    }
  }

  bool _isNumericAgg(String agg) {
    return agg == 'sum' || agg == 'avg' || agg == 'min' || agg == 'max' || agg == 'count' || agg == 'count_distinct';
  }

  String _defaultAggForColumn(Map<String, dynamic> col) {
    return col['numeric'] == true ? 'sum' : 'first';
  }

  void _applyTransform() {
    if (_groupBy == null || _rawColumns.isEmpty) {
      setState(() {
        _displayColumns = _rawColumns;
        _displayRows = _rawRows;
      });
      return;
    }
    final groupByCol = _rawColumns.firstWhere(
      (c) => c['key'] == _groupBy,
      orElse: () => const <String, dynamic>{},
    );
    if (groupByCol.isEmpty) {
      // Group-by column was removed by some other state change — fall
      // back to raw view rather than producing a confusing empty
      // table.
      setState(() {
        _displayColumns = _rawColumns;
        _displayRows = _rawRows;
        _groupBy = null;
      });
      return;
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in _rawRows) {
      final key = (row[_groupBy] ?? '').toString();
      groups.putIfAbsent(key, () => []).add(row);
    }
    final sortedGroupKeys = groups.keys.toList()..sort();

    if (_pivotBy != null && _pivotValueCol != null) {
      // Pivot: distinct values of _pivotBy become new columns; cells
      // are agg(value column) for the (groupBy, pivotBy) intersection.
      final distinctPivotVals = <String>{};
      for (final row in _rawRows) {
        distinctPivotVals.add((row[_pivotBy] ?? '').toString());
      }
      final sortedPivotVals = distinctPivotVals.toList()..sort();
      final outRows = <Map<String, dynamic>>[];
      for (final gk in sortedGroupKeys) {
        final r = <String, dynamic>{_groupBy!: gk};
        for (final pv in sortedPivotVals) {
          final cell = groups[gk]!.where(
            (row) => (row[_pivotBy] ?? '').toString() == pv,
          ).toList();
          r[pv] = _aggregate(_pivotValueAgg, cell.map((row) => row[_pivotValueCol]).toList());
        }
        outRows.add(r);
      }
      final outCols = <Map<String, dynamic>>[
        {'key': _groupBy!, 'label': groupByCol['label']},
        for (final pv in sortedPivotVals)
          {'key': pv, 'label': pv.isEmpty ? '(blank)' : pv, 'numeric': true},
      ];
      setState(() {
        _displayColumns = outCols;
        _displayRows = outRows;
      });
      return;
    }

    // Plain group-by — one row per group, per-column aggregations.
    final aggCols = _rawColumns.where((c) {
      if (c['key'] == _groupBy) return false;
      final agg = _aggregations[c['key']] ?? _defaultAggForColumn(c);
      return agg != 'hide';
    }).toList();

    final outRows = <Map<String, dynamic>>[];
    for (final gk in sortedGroupKeys) {
      final r = <String, dynamic>{_groupBy!: gk};
      for (final c in aggCols) {
        final agg = _aggregations[c['key']] ?? _defaultAggForColumn(c);
        r[c['key']] = _aggregate(agg, groups[gk]!.map((row) => row[c['key']]).toList());
      }
      outRows.add(r);
    }
    final outCols = <Map<String, dynamic>>[
      {'key': _groupBy!, 'label': groupByCol['label']},
      ...aggCols.map((c) {
        final agg = _aggregations[c['key']] ?? _defaultAggForColumn(c);
        return {
          'key': c['key'],
          'label': '${c['label']} (${_aggLabel(agg)})',
          'numeric': _isNumericAgg(agg),
        };
      }),
    ];
    setState(() {
      _displayColumns = outCols;
      _displayRows = outRows;
    });
  }

  void _resetTransform() {
    setState(() {
      _groupBy = null;
      _pivotBy = null;
      _pivotValueCol = null;
      _pivotValueAgg = 'sum';
      _aggregations.clear();
    });
    _applyTransform();
  }

  bool get _chartable {
    if (_displayColumns.length < 2) return false;
    return _displayColumns.any((c) => c['numeric'] == true);
  }

  List<BarChartData> _buildBars() {
    final labelKey = _displayColumns.first['key'].toString();
    final numericCol = _displayColumns.firstWhere(
      (c) => c['numeric'] == true,
      orElse: () => _displayColumns[1],
    );
    final valKey = numericCol['key'].toString();
    return _displayRows.map((r) {
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
            else if (_rawRows.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No rows')))
            else ...[
              _GroupPanel(
                rawColumns: _rawColumns,
                groupBy: _groupBy,
                pivotBy: _pivotBy,
                pivotValueCol: _pivotValueCol,
                pivotValueAgg: _pivotValueAgg,
                aggregations: _aggregations,
                onChanged: (next) {
                  setState(() {
                    _groupBy = next.groupBy;
                    _pivotBy = next.pivotBy;
                    _pivotValueCol = next.pivotValueCol;
                    _pivotValueAgg = next.pivotValueAgg;
                    _aggregations
                      ..clear()
                      ..addAll(next.aggregations);
                  });
                  _applyTransform();
                },
                onReset: _resetTransform,
              ),
              const SizedBox(height: 12),
              if (_displayRows.isEmpty)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No rows after transform')))
              else if (_showAsChart)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(height: 320, child: SimpleBarChart(bars: _buildBars())),
                  ),
                )
              else
                _ResultTable(columns: _displayColumns, rows: _displayRows),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransformConfig {
  const _TransformConfig({
    required this.groupBy,
    required this.pivotBy,
    required this.pivotValueCol,
    required this.pivotValueAgg,
    required this.aggregations,
  });
  final String? groupBy;
  final String? pivotBy;
  final String? pivotValueCol;
  final String pivotValueAgg;
  final Map<String, String> aggregations;
}

class _GroupPanel extends StatelessWidget {
  const _GroupPanel({
    required this.rawColumns,
    required this.groupBy,
    required this.pivotBy,
    required this.pivotValueCol,
    required this.pivotValueAgg,
    required this.aggregations,
    required this.onChanged,
    required this.onReset,
  });

  final List<Map<String, dynamic>> rawColumns;
  final String? groupBy;
  final String? pivotBy;
  final String? pivotValueCol;
  final String pivotValueAgg;
  final Map<String, String> aggregations;
  final ValueChanged<_TransformConfig> onChanged;
  final VoidCallback onReset;

  static const _aggOptions = <String, String>{
    'sum': 'Sum',
    'avg': 'Average',
    'min': 'Min',
    'max': 'Max',
    'count': 'Count',
    'count_distinct': 'Count distinct',
    'first': 'First',
    'hide': 'Hide',
  };

  static const _numericAggOptions = <String>{'sum', 'avg', 'min', 'max', 'count', 'count_distinct', 'hide'};

  bool get _isActive => groupBy != null;

  String _summary() {
    if (groupBy == null) return 'Off';
    final g = groupBy!;
    if (pivotBy != null && pivotValueCol != null) {
      return 'Pivot — group: $g, pivot: $pivotBy, value: $pivotValueAgg($pivotValueCol)';
    }
    return 'Group by: $g';
  }

  void _emit({
    String? Function()? groupByFn,
    String? Function()? pivotByFn,
    String? Function()? pivotValueColFn,
    String? pivotValueAgg,
    Map<String, String>? aggregations,
  }) {
    onChanged(_TransformConfig(
      groupBy: groupByFn != null ? groupByFn() : groupBy,
      pivotBy: pivotByFn != null ? pivotByFn() : pivotBy,
      pivotValueCol: pivotValueColFn != null ? pivotValueColFn() : pivotValueCol,
      pivotValueAgg: pivotValueAgg ?? this.pivotValueAgg,
      aggregations: aggregations ?? Map.from(this.aggregations),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groupByOptions = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
      ...rawColumns.map((c) => DropdownMenuItem<String?>(
        value: c['key'].toString(),
        child: Text(c['label']?.toString() ?? c['key'].toString()),
      )),
    ];
    final pivotByOptions = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
      ...rawColumns.where((c) => c['key'] != groupBy).map((c) => DropdownMenuItem<String?>(
        value: c['key'].toString(),
        child: Text(c['label']?.toString() ?? c['key'].toString()),
      )),
    ];
    final numericCols = rawColumns.where((c) => c['numeric'] == true).toList();
    final pivotValueColOptions = numericCols.isEmpty
        ? rawColumns.map((c) => DropdownMenuItem<String?>(
              value: c['key'].toString(),
              child: Text(c['label']?.toString() ?? c['key'].toString()),
            )).toList()
        : numericCols.map((c) => DropdownMenuItem<String?>(
              value: c['key'].toString(),
              child: Text(c['label']?.toString() ?? c['key'].toString()),
            )).toList();

    final pivoting = pivotBy != null;

    return Card(
      child: Theme(
        // Strip the default ExpansionTile divider in the collapsed
        // state — looks cleaner above the table.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isActive,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.functions, color: _isActive ? cs.primary : cs.outline),
          title: const Text('Group / Pivot'),
          subtitle: Text(_summary(), style: TextStyle(fontSize: 12, color: cs.outline)),
          trailing: _isActive
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                  ),
                  const Icon(Icons.expand_more),
                ])
              : null,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: groupBy,
                    decoration: const InputDecoration(
                      labelText: 'Group by',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: groupByOptions,
                    onChanged: (v) => _emit(
                      groupByFn: () => v,
                      // Reset pivot if group cleared.
                      pivotByFn: v == null ? () => null : null,
                      pivotValueColFn: v == null ? () => null : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: pivotBy,
                    decoration: InputDecoration(
                      labelText: 'Pivot by',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      helperText: groupBy == null ? 'Set Group by first' : null,
                    ),
                    items: pivotByOptions,
                    onChanged: groupBy == null
                        ? null
                        : (v) {
                            // Setting pivot for the first time? Default
                            // value column to the first numeric column
                            // that isn't groupBy/pivotBy.
                            String? nextValueCol = pivotValueCol;
                            if (v != null && nextValueCol == null) {
                              final candidate = numericCols.firstWhere(
                                (c) => c['key'] != groupBy && c['key'] != v,
                                orElse: () => const <String, dynamic>{},
                              );
                              if (candidate.isNotEmpty) nextValueCol = candidate['key'].toString();
                            }
                            if (v == null) nextValueCol = null;
                            _emit(
                              pivotByFn: () => v,
                              pivotValueColFn: () => nextValueCol,
                            );
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pivoting)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: pivotValueCol,
                      decoration: const InputDecoration(
                        labelText: 'Value column',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: pivotValueColOptions,
                      onChanged: (v) => _emit(pivotValueColFn: () => v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: pivotValueAgg,
                      decoration: const InputDecoration(
                        labelText: 'Aggregation',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _numericAggOptions
                          .map((a) => DropdownMenuItem(value: a, child: Text(_aggOptions[a]!)))
                          .toList(),
                      onChanged: (v) => _emit(pivotValueAgg: v ?? 'sum'),
                    ),
                  ),
                ],
              )
            else if (groupBy != null) ...[
              Text('Aggregations', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: rawColumns.where((c) => c['key'] != groupBy).map((c) {
                  final key = c['key'].toString();
                  final isNum = c['numeric'] == true;
                  final current = aggregations[key] ?? (isNum ? 'sum' : 'first');
                  // For text columns, hide the numeric aggregations.
                  final allowed = isNum
                      ? _aggOptions.keys
                      : _aggOptions.keys.where((a) => a == 'count' || a == 'count_distinct' || a == 'first' || a == 'hide');
                  return SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: allowed.contains(current) ? current : allowed.first,
                      decoration: InputDecoration(
                        labelText: c['label']?.toString() ?? key,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: allowed
                          .map((a) => DropdownMenuItem(value: a, child: Text(_aggOptions[a]!)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final next = Map<String, String>.from(aggregations);
                        next[key] = v;
                        _emit(aggregations: next);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
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

  String _formatCell(dynamic v) {
    if (v == null) return '';
    if (v is double) {
      // Drop trailing zeros for cleaner display of avg/sum results.
      if (v == v.truncate()) return v.toInt().toString();
      return v.toStringAsFixed(2);
    }
    return v.toString();
  }

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
                          child: Text(_formatCell(row[c['key']])),
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
