import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';

class PagesPage extends ConsumerStatefulWidget {
  const PagesPage({super.key});

  @override
  ConsumerState<PagesPage> createState() => _PagesPageState();
}

class _PagesPageState extends ConsumerState<PagesPage> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    setState(() { _loading = true; _error = null; });
    try {
      final res = await api.getJson('/pages');
      Map<String, dynamic>? analytics;
      try {
        analytics = await api.getJson('/pages/analytics');
      } catch (_) {
        // pages.view sufficient for both, but tolerate non-fatal failure
      }
      if (!mounted) return;
      setState(() {
        _items = (res['items'] as List).cast<Map<String, dynamic>>();
        _analytics = analytics;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  Widget _buildAnalyticsPanel(BuildContext context) {
    final a = _analytics;
    if (a == null) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final byType = (a['byType'] as List? ?? const []).cast<Map<String, dynamic>>();
    final emptyPages = (a['emptyPages'] as List? ?? const []).cast<Map<String, dynamic>>();
    final pageCount = (a['pageCount'] as num?)?.toInt() ?? 0;
    final blockCount = (a['blockCount'] as num?)?.toInt() ?? 0;
    final perPage = (a['blocksPerPage'] as num?)?.toDouble() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _stat(t.pagesStatLabel, '$pageCount'),
                const SizedBox(width: 24),
                _stat(t.blocksStatLabel, '$blockCount'),
                const SizedBox(width: 24),
                _stat(t.avgBlocksPerPage, perPage.toStringAsFixed(1)),
              ],
            ),
            if (byType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(t.blockUsage, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: byType.map((b) {
                  return Chip(
                    label: Text('${b['type']}  ×${b['count']}'),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            if (emptyPages.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Empty pages (${emptyPages.length}): '
                '${emptyPages.map((p) => p['title'] ?? p['code']).join(', ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('${t.error}: $_error'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsPanel(context),
          if (_analytics != null) const SizedBox(height: 12),
          PageHeader(
            title: t.pages,
            subtitle: t.pagesSubtitle,
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(t.newPage),
                onPressed: _newPage,
              ),
            ],
          ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t.noPagesYet),
            ),
          ..._items.map((p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.web_outlined),
                  title: Text(p['title']?.toString() ?? p['code']?.toString() ?? '-'),
                  subtitle: Text('${p['route']} ${p['isActive'] == true ? '' : '(inactive)'}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: t.openInBuilder,
                        onPressed: () => context.go('/pages/edit/${p['id']}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        tooltip: t.openPage,
                        onPressed: () => context.go(p['route']?.toString() ?? '/'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: t.delete,
                        onPressed: () => _delete(p['id'] as int),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _newPage() async {
    final t = AppLocalizations.of(context);
    final code = TextEditingController();
    final title = TextEditingController();
    final route = TextEditingController(text: '/');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.newPage),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: code, decoration: InputDecoration(labelText: t.codeLowerSnake)),
              TextField(controller: title, decoration: InputDecoration(labelText: t.titleField)),
              TextField(controller: route, decoration: const InputDecoration(labelText: 'Route (must start with /)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.create)),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(apiClientProvider);
    try {
      await api.postJson('/pages', body: {
        'code': code.text.trim(),
        'title': title.text.trim(),
        'route': route.text.trim(),
      });
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Future<void> _delete(int id) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deletePageTitle),
        content: Text(t.deletePageBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete)),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ref.read(apiClientProvider);
    await api.deleteJson('/pages/$id');
    await _load();
  }
}
