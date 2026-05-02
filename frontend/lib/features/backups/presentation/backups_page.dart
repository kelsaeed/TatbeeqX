import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';

class BackupsPage extends ConsumerStatefulWidget {
  const BackupsPage({super.key});

  @override
  ConsumerState<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends ConsumerState<BackupsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).getJson('/admin/backups');
      if (!mounted) return;
      setState(() {
        _items = (res['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  Future<void> _create() async {
    final t = AppLocalizations.of(context);
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.createBackup),
        content: TextField(
          controller: label,
          decoration: InputDecoration(
            labelText: t.backupLabelField,
            hintText: t.backupLabelExample,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.create)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).postJson('/admin/backups', body: {
        if (label.text.trim().isNotEmpty) 'label': label.text.trim(),
      });
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String name) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteBackupTitle),
        content: Text(t.deleteBackupWarn(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(apiClientProvider).deleteJson('/admin/backups/$name');
    await _load();
  }

  Future<void> _restore(String name) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.restoreBackupTitle),
        content: Text(t.restoreBackupWarn(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t.restore),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).postJson('/admin/backups/$name/restore');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? t.restoreCompleteRestart),
        duration: const Duration(seconds: 8),
      ));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
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
          PageHeader(
            title: t.backups,
            subtitle: t.backupsSubtitle,
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: t.refresh),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(_busy ? '${t.create}…' : t.newItem),
                onPressed: _busy ? null : _create,
              ),
            ],
          ),
          if (_items.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(t.noBackupsYet)),
          ..._items.map((b) {
            final iso = b['createdAt'] as String?;
            final dt = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(b['name']?.toString() ?? '-'),
                subtitle: Text(
                  '${dt == null ? '' : DateFormat('yyyy-MM-dd HH:mm:ss').format(dt)}'
                  '   •   ${_humanSize((b['size'] as num?)?.toInt() ?? 0)}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore, size: 18),
                      tooltip: t.restore,
                      onPressed: () => _restore(b['name'] as String),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: t.delete,
                      onPressed: () => _delete(b['name'] as String),
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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
