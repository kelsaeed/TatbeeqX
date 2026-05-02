import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';

class SystemPage extends ConsumerStatefulWidget {
  const SystemPage({super.key});

  @override
  ConsumerState<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends ConsumerState<SystemPage> {
  Map<String, dynamic>? _info;
  List<Map<String, dynamic>> _connections = [];
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
      final info = await api.getJson('/system/info');
      List<Map<String, dynamic>> conns = [];
      try {
        final cs = await api.getJson('/system/database/connections');
        conns = (cs['items'] as List).cast<Map<String, dynamic>>();
      } catch (_) { /* non-super-admin */ }
      if (!mounted) return;
      setState(() {
        _info = info;
        _connections = conns;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('${t.error}: $_error'));
    final info = _info!;
    final counts = (info['counts'] as Map?) ?? {};
    final memory = (info['memory'] as Map?) ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.system,
            subtitle: t.systemSubtitle,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                tooltip: t.refresh,
              ),
            ],
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _infoCard('Node', info['node']?.toString() ?? '-'),
              _infoCard('Platform', '${info['platform']} (${info['arch']})'),
              _infoCard('Hostname', info['hostname']?.toString() ?? '-'),
              _infoCard('Uptime', '${info['uptimeSec']}s'),
              _infoCard(t.database, '${info['databaseProvider']}'),
              _infoCard('Heap', '${_mb(memory['heapUsed'])} / ${_mb(memory['heapTotal'])} MB'),
              _infoCard(t.users, counts['users']?.toString() ?? '0'),
              _infoCard(t.audit, counts['auditLogs']?.toString() ?? '0'),
              _infoCard(t.systemLogs, counts['systemLogs']?.toString() ?? '0'),
              _infoCard(t.loginActivity, counts['loginEvents']?.toString() ?? '0'),
              _infoCard(t.pages, counts['pages']?.toString() ?? '0'),
              _infoCard(t.customEntities, counts['customEntities']?.toString() ?? '0'),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Text(t.databaseConnectionsHeader, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(t.addConnectionLabel),
                onPressed: () => _showConnectionDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                if (_connections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.noConnectionsYet),
                  ),
                ..._connections.map(
                  (c) => ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text('${c['name']} (${c['code']})'),
                    subtitle: Text('${c['provider']} — ${c['url']}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        if (c['isPrimary'] == true)
                          Chip(label: Text(t.primaryChip), backgroundColor: const Color(0xFFE0F2FE)),
                        IconButton(
                          icon: const Icon(Icons.upload, size: 18),
                          tooltip: t.promoteToPrimary,
                          onPressed: () => _promote(c['id'] as int),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: t.delete,
                          onPressed: c['isPrimary'] == true ? null : () => _delete(c['id'] as int),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(t.initDatabaseHeader, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            t.initDatabaseHint,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          _SqlInitBox(onSubmit: (sql) async {
            final api = ref.read(apiClientProvider);
            final res = await api.postJson('/system/database/sql/init', body: {'sql': sql});
            return res;
          }),
        ],
      ),
    );
  }

  String _mb(dynamic bytes) {
    if (bytes is num) return (bytes / 1024 / 1024).toStringAsFixed(1);
    return '0';
  }

  Widget _infoCard(String label, String value) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Future<void> _showConnectionDialog() async {
    final t = AppLocalizations.of(context);
    final code = TextEditingController();
    final name = TextEditingController();
    final provider = ValueNotifier<String>('postgresql');
    final url = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.addDatabaseConnection),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'Code (e.g. cloud_pg)')),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              ValueListenableBuilder<String>(
                valueListenable: provider,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  initialValue: v,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: const [
                    DropdownMenuItem(value: 'sqlite', child: Text('SQLite')),
                    DropdownMenuItem(value: 'postgresql', child: Text('PostgreSQL')),
                    DropdownMenuItem(value: 'mysql', child: Text('MySQL')),
                    DropdownMenuItem(value: 'sqlserver', child: Text('SQL Server')),
                    DropdownMenuItem(value: 'mongodb', child: Text('MongoDB')),
                  ],
                  onChanged: (s) { if (s != null) provider.value = s; },
                ),
              ),
              TextField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'Connection URL',
                  hintText: 'postgresql://user:pass@host:5432/db',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
        ],
      ),
    );

    if (ok == true) {
      final api = ref.read(apiClientProvider);
      try {
        await api.postJson('/system/database/connections', body: {
          'code': code.text,
          'name': name.text,
          'provider': provider.value,
          'url': url.text,
        });
        await _load();
      } catch (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
      }
    }
  }

  Future<void> _promote(int id) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.promoteToPrimaryTitle),
        content: Text(t.promoteWarn),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.promoteAction)),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ref.read(apiClientProvider);
    final res = await api.postJson('/system/database/connections/$id/promote');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message']?.toString() ?? t.updatedRestartRequired),
      duration: const Duration(seconds: 8),
    ));
    await _load();
  }

  Future<void> _delete(int id) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteConnectionTitle),
        content: Text(t.deleteConnectionBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete)),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ref.read(apiClientProvider);
    await api.deleteJson('/system/database/connections/$id');
    await _load();
  }
}

class _SqlInitBox extends StatefulWidget {
  const _SqlInitBox({required this.onSubmit});
  final Future<Map<String, dynamic>> Function(String sql) onSubmit;

  @override
  State<_SqlInitBox> createState() => _SqlInitBoxState();
}

class _SqlInitBoxState extends State<_SqlInitBox> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'CREATE TABLE my_table (...);\nINSERT INTO my_table VALUES (...);',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(_running ? AppLocalizations.of(context).running : AppLocalizations.of(context).runStatements),
          onPressed: _running
              ? null
              : () async {
                  setState(() { _running = true; _results = []; });
                  try {
                    final res = await widget.onSubmit(_controller.text);
                    if (!mounted) return;
                    setState(() {
                      _results = (res['results'] as List? ?? []).cast<Map<String, dynamic>>();
                      _running = false;
                    });
                  } catch (err) {
                    if (!context.mounted) return;
                    setState(() { _running = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
                  }
                },
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._results.map((r) {
            final ok = r['ok'] == true;
            return Card(
              color: ok ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05),
              child: ListTile(
                leading: Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red),
                title: Text(r['stmt']?.toString() ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                subtitle: ok ? null : Text(r['error']?.toString() ?? ''),
              ),
            );
          }),
        ],
      ],
    );
  }
}
