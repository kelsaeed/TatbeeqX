import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class SqlRunnerPanel extends ConsumerStatefulWidget {
  const SqlRunnerPanel({super.key});

  @override
  ConsumerState<SqlRunnerPanel> createState() => _SqlRunnerPanelState();
}

class _SqlRunnerPanelState extends ConsumerState<SqlRunnerPanel> {
  final _sql = TextEditingController(text: 'SELECT * FROM products LIMIT 50;');
  bool _allowWrite = false;
  bool _running = false;
  Map<String, dynamic>? _result;
  String? _error;

  List<Map<String, dynamic>> _saved = [];
  bool _savedLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSaved);
  }

  @override
  void dispose() {
    _sql.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final res = await ref.read(apiClientProvider).getJson('/db/queries');
      setState(() {
        _saved = (res['items'] as List).cast<Map<String, dynamic>>();
        _savedLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _savedLoading = false);
    }
  }

  Future<void> _run() async {
    final sql = _sql.text.trim();
    if (sql.isEmpty) return;
    if (_allowWrite) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Run write query?'),
          content: const Text(
            'You are about to run SQL with write mode enabled. Make sure you know what this does. Core auth tables are still protected.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await ref.read(apiClientProvider).postJson('/db/query', body: {
        'sql': sql,
        'allowWrite': _allowWrite,
      });
      setState(() {
        _result = res;
        _running = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _running = false;
      });
    }
  }

  Future<void> _saveCurrent() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save query'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).postJson('/db/queries', body: {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'sql': _sql.text,
        'isReadOnly': !_allowWrite,
      });
      _loadSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Query saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _delete(int id) async {
    try {
      await ref.read(apiClientProvider).deleteJson('/db/queries/$id');
      _loadSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('SQL runner', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Row(
                  children: [
                    const Text('Write mode'),
                    Switch(
                      value: _allowWrite,
                      onChanged: (v) => setState(() => _allowWrite = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sql,
              maxLines: 6,
              minLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'SELECT * FROM products LIMIT 50;',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saveCurrent,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_result != null) _ResultView(result: _result!),
            const SizedBox(height: 18),
            Text('Saved queries', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_savedLoading)
              const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
            else if (_saved.isEmpty)
              Text('Nothing saved yet.', style: Theme.of(context).textTheme.bodySmall)
            else
              Column(
                children: _saved.map((q) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(q['name'].toString()),
                  subtitle: Text(
                    q['description']?.toString().isNotEmpty == true ? q['description'].toString() : q['sql'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Load',
                        icon: const Icon(Icons.upload_outlined, size: 18),
                        onPressed: () => setState(() => _sql.text = q['sql'].toString()),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _delete(q['id'] as int),
                      ),
                    ],
                  ),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final kind = result['kind']?.toString();
    if (kind == 'affected') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.06),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('${result['affectedRows'] ?? 0} row(s) affected', style: const TextStyle(color: Colors.green)),
      );
    }
    final cols = (result['columns'] as List? ?? const []).cast<String>();
    final rows = (result['rows'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (cols.isEmpty || rows.isEmpty) {
      return Padding(padding: const EdgeInsets.all(12), child: Text('No rows returned (${result['rowCount'] ?? 0}).'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${rows.length} row(s)${result['truncated'] == true ? ' (truncated)' : ''}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: cols.map((c) => DataColumn(label: Text(c))).toList(),
            rows: rows.map((r) => DataRow(
              cells: cols.map((c) => DataCell(Text(r[c]?.toString() ?? ''))).toList(),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
