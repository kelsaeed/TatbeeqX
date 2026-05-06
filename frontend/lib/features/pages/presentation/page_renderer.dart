import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/paginated_search_table.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/i18n/locale_controller.dart';
import 'iframe_renderer.dart';

class PageRenderer extends ConsumerStatefulWidget {
  const PageRenderer({super.key, this.slug, this.route})
      : assert(slug != null || route != null, 'PageRenderer needs a slug or a route');
  final String? slug;
  final String? route;

  @override
  ConsumerState<PageRenderer> createState() => _PageRendererState();
}

class _PageRendererState extends ConsumerState<PageRenderer> {
  Map<String, dynamic>? _page;
  List<Map<String, dynamic>> _blocks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PageRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug || oldWidget.route != widget.route) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getJson('/pages/by-route', query: {
        if (widget.slug != null) 'code': widget.slug,
        if (widget.route != null) 'route': widget.route,
      });
      if (!mounted) return;
      setState(() {
        _page = (res['page'] as Map).cast<String, dynamic>();
        _blocks = (res['blocks'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    final p = _page!;
    final auth = ref.watch(authControllerProvider);
    final localeCode = ref.watch(localeControllerProvider).languageCode;
    final visibleTopLevel = _blocks
        .where((b) => b['parentId'] == null)
        .where((b) => isBlockVisible(b, auth))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: _resolveTitle(p, localeCode),
            subtitle: p['description']?.toString(),
          ),
          ...visibleTopLevel.map((b) => _renderBlock(context, b, _blocks, auth)),
        ],
      ),
    );
  }
}

/// Phase 4.8 — picks the locale-specific title from `Page.titles` JSON,
/// falling back to the canonical `title` column when missing.
String _resolveTitle(Map<String, dynamic> page, String localeCode) {
  final titles = page['titles'];
  if (titles is Map) {
    final v = titles[localeCode];
    if (v is String && v.isNotEmpty) return v;
  }
  return page['title']?.toString() ?? 'Page';
}

/// Phase 4.5 — evaluates `config.visibleWhen` against the current user.
///
/// Supported shapes (all optional, ANDed together):
///   visibleWhen: { permission: "users.view" }
///   visibleWhen: { permissions: ["users.view", "roles.view"], match: "any"|"all" }
///   visibleWhen: { isSuperAdmin: true }
///   visibleWhen: { isLoggedIn: true }
bool isBlockVisible(Map<String, dynamic> block, AuthState auth) {
  final config = ((block['config'] as Map?) ?? const {}).cast<String, dynamic>();
  final rule = config['visibleWhen'];
  if (rule is! Map) return true;

  final r = rule.cast<String, dynamic>();
  if (r['isLoggedIn'] == true && !auth.isLoggedIn) return false;
  if (r['isSuperAdmin'] == true && auth.user?.isSuperAdmin != true) return false;

  final single = r['permission']?.toString();
  if (single != null && single.isNotEmpty && !auth.can(single)) return false;

  final multi = r['permissions'];
  if (multi is List && multi.isNotEmpty) {
    final codes = multi.map((e) => e.toString()).toList();
    final mode = (r['match']?.toString() ?? 'all').toLowerCase();
    if (mode == 'any') {
      if (!codes.any(auth.can)) return false;
    } else {
      if (!codes.every(auth.can)) return false;
    }
  }

  return true;
}

Widget _renderBlock(BuildContext context, Map<String, dynamic> block, List<Map<String, dynamic>> all, AuthState auth) {
  final type = block['type']?.toString() ?? '';
  final config = ((block['config'] as Map?) ?? const {}).cast<String, dynamic>();
  final blockId = block['id'];
  final children = all.where((b) => b['parentId'] == blockId).where((b) => isBlockVisible(b, auth)).toList();

  Widget child;
  switch (type) {
    case 'text':
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(config['text']?.toString() ?? '', style: Theme.of(context).textTheme.bodyMedium),
      );
      break;
    case 'heading':
      final level = (config['level'] as num?)?.toInt() ?? 2;
      final style = level <= 1
          ? Theme.of(context).textTheme.displaySmall
          : level == 2
              ? Theme.of(context).textTheme.headlineSmall
              : level == 3
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.titleMedium;
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(config['text']?.toString() ?? '', style: style),
      );
      break;
    case 'image':
      final url = config['url']?.toString() ?? '';
      final fit = _fitFrom(config['fit']?.toString());
      child = url.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(_resolveUrl(url), fit: fit),
              ),
            );
      break;
    case 'button':
      // Phase 4.17 v2 — `workflowCode` (optional) makes the button a
      // workflow trigger instead of a navigation. When set, tap fires
      // `POST /api/workflows/by-code/<code>/run` with `payload`. When
      // absent, falls back to the existing route navigation.
      final label = config['label']?.toString() ?? 'Button';
      final route = config['route']?.toString() ?? '/';
      final variant = config['variant']?.toString() ?? 'filled';
      final workflowCode = config['workflowCode']?.toString();
      final workflowPayload = config['workflowPayload'];
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _PageButton(
            label: label,
            variant: variant,
            workflowCode: (workflowCode != null && workflowCode.isNotEmpty) ? workflowCode : null,
            workflowPayload: workflowPayload is Map ? Map<String, dynamic>.from(workflowPayload) : null,
            navigateTo: route,
          ),
        ),
      );
      break;
    case 'card':
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((config['title'] as String?)?.isNotEmpty ?? false)
                  Text(config['title'].toString(), style: Theme.of(context).textTheme.titleMedium),
                if ((config['title'] as String?)?.isNotEmpty ?? false) const SizedBox(height: 8),
                if ((config['body'] as String?)?.isNotEmpty ?? false)
                  Text(config['body'].toString()),
                if (children.isNotEmpty) const SizedBox(height: 12),
                ...children.map((c) => _renderBlock(context, c, all, auth)),
              ],
            ),
          ),
        ),
      );
      break;
    case 'container':
      final direction = config['direction']?.toString() ?? 'column';
      final gap = (config['gap'] as num?)?.toDouble() ?? 12.0;
      final separated = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        if (i > 0) separated.add(SizedBox(width: gap, height: gap));
        separated.add(_renderBlock(context, children[i], all, auth));
      }
      child = direction == 'row'
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: separated.map((w) => Expanded(child: w)).toList())
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: separated);
      break;
    case 'divider':
      child = const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider());
      break;
    case 'spacer':
      final h = (config['height'] as num?)?.toDouble() ?? 16;
      child = SizedBox(height: h);
      break;
    case 'list':
      final items = (config['items'] as List? ?? const []).cast();
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((it) {
          if (it is Map) {
            final m = it.cast<String, dynamic>();
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(m['label']?.toString() ?? ''),
              subtitle: m['sub'] != null ? Text(m['sub'].toString()) : null,
            );
          }
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(it.toString()),
          );
        }).toList(),
      );
      break;
    case 'table':
      final cols = (config['columns'] as List? ?? const [])
          .cast<Map>()
          .map((c) => c.cast<String, dynamic>())
          .toList();
      final rows = (config['rows'] as List? ?? const []).cast<List>();
      child = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: cols.map((c) => DataColumn(label: Text(c['label']?.toString() ?? c['key']?.toString() ?? ''))).toList(),
          rows: rows.map((r) => DataRow(
                cells: List.generate(cols.length, (i) => DataCell(Text(i < r.length ? '${r[i]}' : ''))),
              )).toList(),
        ),
      );
      break;
    case 'chart':
      final kind = config['kind']?.toString() ?? 'bar';
      final data = (config['data'] as List? ?? const [])
          .cast<Map>()
          .map((d) => d.cast<String, dynamic>())
          .toList();
      child = SizedBox(
        height: 240,
        child: kind == 'pie' ? _PieChartView(data: data) : _BarChartView(data: data),
      );
      break;
    case 'iframe':
      final h = (config['height'] as num?)?.toDouble() ?? 400;
      final url = config['url']?.toString();
      child = buildIframeBlock(url: url, height: h);
      break;
    case 'html':
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(config['html']?.toString() ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      );
      break;
    case 'custom_entity_list':
      child = _CustomEntityBlock(entityCode: config['entityCode']?.toString() ?? '');
      break;
    case 'report':
      child = _ReportBlock(reportCode: config['reportCode']?.toString() ?? '');
      break;
    default:
      child = const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: child,
  );
}

BoxFit _fitFrom(String? s) {
  switch (s) {
    case 'contain': return BoxFit.contain;
    case 'fill':    return BoxFit.fill;
    case 'cover':
    default:        return BoxFit.cover;
  }
}

String _resolveUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = AppConfig.apiBaseUrl;
  final stripped = base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  return '$stripped$url';
}

// Phase 4.17 v2 — runtime button. When `workflowCode` is set, tap fires
// the workflow via POST /workflows/by-code/<code>/run instead of
// navigating. Lives as a widget (not inline) so it can read the API
// client from Riverpod without threading `ref` through every block.
class _PageButton extends ConsumerStatefulWidget {
  final String label;
  final String variant;
  final String? workflowCode;
  final Map<String, dynamic>? workflowPayload;
  final String navigateTo;

  const _PageButton({
    required this.label,
    required this.variant,
    required this.workflowCode,
    required this.workflowPayload,
    required this.navigateTo,
  });

  @override
  ConsumerState<_PageButton> createState() => _PageButtonState();
}

class _PageButtonState extends ConsumerState<_PageButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    if (widget.workflowCode == null) {
      GoRouter.of(context).go(widget.navigateTo);
      return;
    }
    setState(() => _busy = true);
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.postJson(
        '/workflows/by-code/${widget.workflowCode}/run',
        body: {if (widget.workflowPayload != null) 'payload': widget.workflowPayload},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workflow ${res['status'] ?? 'fired'} (run ${res['runId'] ?? '?'})')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(widget.label);
    switch (widget.variant) {
      case 'outlined':
        return OutlinedButton(onPressed: _busy ? null : _onPressed, child: child);
      case 'text':
        return TextButton(onPressed: _busy ? null : _onPressed, child: child);
      default:
        return FilledButton(onPressed: _busy ? null : _onPressed, child: child);
    }
  }
}

class _BarChartView extends StatelessWidget {
  const _BarChartView({required this.data});
  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data'));
    final cs = Theme.of(context).colorScheme;
    final maxV = data
        .map((d) => (d['value'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: data.map((d) {
        final v = (d['value'] as num?)?.toDouble() ?? 0;
        final pct = (v / safeMax).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  d['label']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 14,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  v.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PieChartView extends StatelessWidget {
  const _PieChartView({required this.data});
  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data'));
    const palette = Colors.primaries;
    final total = data
        .map((d) => (d['value'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const Center(child: Text('No data'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(data.length, (i) {
        final v = (data[i]['value'] as num?)?.toDouble() ?? 0;
        final pct = v / total;
        final color = palette[i % palette.length];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 10, height: 10, color: color),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: Text(
                  data[i]['label']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 12,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${(pct * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CustomEntityBlock extends ConsumerWidget {
  const _CustomEntityBlock({required this.entityCode});
  final String entityCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entityCode.isEmpty) {
      return const Padding(padding: EdgeInsets.all(8), child: Text('Set entityCode in this block.'));
    }
    final api = ref.watch(apiClientProvider);
    return SizedBox(
      height: 360,
      child: PaginatedSearchTable<Map<String, dynamic>>(
        searchable: true,
        fetch: ({required page, required pageSize, required search}) async {
          final res = await api.getJson('/c/$entityCode', query: {
            'page': page,
            'pageSize': pageSize,
            if (search.isNotEmpty) 'q': search,
          });
          final items = (res['items'] as List).cast<Map<String, dynamic>>();
          return (items: items, total: (res['total'] as int?) ?? items.length);
        },
        columns: [
          TableColumn(label: 'ID', flex: 1, cell: (r) => Text(r['id']?.toString() ?? '')),
          TableColumn(label: 'Data', flex: 5, cell: (r) {
            final shown = Map.of(r)..remove('id')..remove('createdAt')..remove('updatedAt');
            return Text(shown.entries.take(5).map((e) => '${e.key}: ${e.value}').join('  •  '), maxLines: 2, overflow: TextOverflow.ellipsis);
          }),
        ],
      ),
    );
  }
}

class _ReportBlock extends ConsumerStatefulWidget {
  const _ReportBlock({required this.reportCode});
  final String reportCode;

  @override
  ConsumerState<_ReportBlock> createState() => _ReportBlockState();
}

class _ReportBlockState extends ConsumerState<_ReportBlock> {
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (widget.reportCode.isEmpty) { setState(() => _error = 'Set reportCode'); return; }
    try {
      final api = ref.read(apiClientProvider);
      final list = await api.getJson('/reports', query: {});
      final reports = (list['items'] as List).cast<Map<String, dynamic>>();
      final found = reports.firstWhere((r) => r['code'] == widget.reportCode, orElse: () => const {});
      if (found.isEmpty) { setState(() => _error = 'Report not found: ${widget.reportCode}'); return; }
      final res = await api.postJson('/reports/${found['id']}/run');
      if (!mounted) return;
      setState(() => _result = res);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Padding(padding: const EdgeInsets.all(8), child: Text('Report error: $_error'));
    if (_result == null) return const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    final cols = (_result!['columns'] as List? ?? const []).cast<Map>().map((c) => c.cast<String, dynamic>()).toList();
    final rows = (_result!['rows'] as List? ?? const []).cast<Map>().map((r) => r.cast<String, dynamic>()).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: cols.map((c) => DataColumn(label: Text(c['label']?.toString() ?? c['key']?.toString() ?? ''))).toList(),
        rows: rows.map((r) => DataRow(
              cells: cols.map((c) => DataCell(Text(r[c['key']]?.toString() ?? ''))).toList(),
            )).toList(),
      ),
    );
  }
}

