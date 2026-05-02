import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/page_header.dart';

class TranslationsPage extends ConsumerStatefulWidget {
  const TranslationsPage({super.key});

  @override
  ConsumerState<TranslationsPage> createState() => _TranslationsPageState();
}

class _TranslationsPageState extends ConsumerState<TranslationsPage> {
  List<Map<String, dynamic>> _locales = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).getJson('/admin/translations');
      if (!mounted) return;
      setState(() {
        _locales = (res['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  // Phase 4.11 — open the per-key editor at /translations/edit/<code>.
  // The legacy raw-JSON dialog is still available via the overflow menu
  // on each row.
  void _openEditor(String locale) {
    context.go('/translations/edit/$locale');
  }

  Future<void> _editRawJson(String locale) async {
    final api = ref.read(apiClientProvider);
    final res = await api.getJson('/admin/translations/$locale');
    if (!mounted) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(res['data']);
    final controller = TextEditingController(text: pretty);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit raw JSON — $locale'),
        content: SizedBox(
          width: 720,
          height: 480,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      final parsed = jsonDecode(controller.text);
      if (parsed is! Map) throw const FormatException('Top-level value must be a JSON object');
      await api.putJson('/admin/translations/$locale', body: {'data': parsed});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Saved. Run `flutter gen-l10n` and rebuild the app for changes to take effect.',
        ),
        duration: Duration(seconds: 6),
      ));
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $err')));
    }
  }

  Future<void> _exportLocale(String locale) async {
    final api = ref.read(apiClientProvider);
    final res = await api.getJson('/admin/translations/$locale');
    if (!mounted) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(res['data']);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Exported app_$locale.arb'),
        content: SizedBox(
          width: 720,
          height: 480,
          child: SelectableText(pretty, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _newLocale() async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New locale'),
        content: TextField(
          controller: code,
          decoration: const InputDecoration(
            labelText: 'Code (e.g. de, es, ja, en_US)',
            hintText: 'two-letter ISO + optional _<region>',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    final locale = code.text.trim();
    if (locale.isEmpty) return;
    try {
      // Seed the new locale by copying English (so the editor starts with all keys).
      final api = ref.read(apiClientProvider);
      final en = await api.getJson('/admin/translations/en');
      await api.putJson('/admin/translations/$locale', body: {'data': en['data']});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Created $locale (seeded from English). Add it to supportedLocales and run gen-l10n.'),
        duration: const Duration(seconds: 6),
      ));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Translations',
            subtitle:
                'Edit ARB files used by the Flutter UI. Changes require a flutter gen-l10n + rebuild to take effect.',
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New locale'),
                onPressed: _newLocale,
              ),
            ],
          ),
          if (_locales.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('No ARB files found.')),
          ..._locales.map((l) {
            final iso = l['updatedAt'] as String?;
            final t = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.translate),
                title: Text('${l['locale']}  •  ${l['file']}'),
                subtitle: Text(
                  '${l['keyCount']} keys  •  ${_humanSize((l['size'] as num?)?.toInt() ?? 0)}'
                  '${t == null ? '' : '  •  edited ${DateFormat('yyyy-MM-dd HH:mm').format(t)}'}'
                  '${l['isSupported'] != true ? '  •  not yet in supportedLocales' : ''}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit (per-key)',
                      onPressed: () => _openEditor(l['locale'] as String),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, size: 18),
                      tooltip: 'Export',
                      onPressed: () => _exportLocale(l['locale'] as String),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (v) {
                        if (v == 'raw') _editRawJson(l['locale'] as String);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'raw',
                          child: Text('Edit raw JSON…'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
