// Phase 4.20 (Phase 2) — Subsystems Manager.
//
// Studio-only surface (hidden in lockdown builds). Lists subsystem
// bundles registered against this machine, with start/stop buttons
// and an "Add bundle" picker. Backed by /api/admin/subsystems and
// the JSON registry at <APPDATA>/TatbeeqX/subsystems.json.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';

class SubsystemsPage extends ConsumerStatefulWidget {
  const SubsystemsPage({super.key});

  @override
  ConsumerState<SubsystemsPage> createState() => _SubsystemsPageState();
}

class _SubsystemsPageState extends ConsumerState<SubsystemsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  String? _registryPath;
  // ID of the row currently in a transition (start/stop) so the
  // matching button can show a spinner without freezing the rest of
  // the list.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).getJson('/admin/subsystems');
      if (!mounted) return;
      setState(() {
        _items = ((res['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
        _registryPath = res['registryPath']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _start(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    setState(() => _busyId = id);
    try {
      await ref.read(apiClientProvider).postJson('/admin/subsystems/$id/start');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Start failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _stop(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    setState(() => _busyId = id);
    try {
      await ref.read(apiClientProvider).postJson('/admin/subsystems/$id/stop');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stop failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _restart(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    setState(() => _busyId = id);
    try {
      await ref.read(apiClientProvider).postJson('/admin/subsystems/$id/restart');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restart failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _viewLogs(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LogsDialog(
        id: item['id'] as String,
        name: item['name']?.toString() ?? 'Subsystem',
      ),
    );
  }

  Future<void> _reassignPort(Map<String, dynamic> item) async {
    final newPort = await showDialog<int>(
      context: context,
      builder: (_) => _ReassignPortDialog(currentPort: item['port'] as int),
    );
    if (newPort == null) return;
    final id = item['id'] as String;
    setState(() => _busyId = id);
    try {
      await ref.read(apiClientProvider).postJson(
        '/admin/subsystems/$id/port',
        body: {'port': newPort},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reassign failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove subsystem?'),
        content: Text('Drop "${item['name']}" from the registry. The bundle on disk is left alone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deleteJson('/admin/subsystems/${item['id']}');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remove failed: $e')),
        );
      }
    }
  }

  Future<void> _showAddDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddBundleDialog(),
    );
    if (added == true) await _load();
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'running':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(40), child: LoadingView());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text('Failed to load: $_error')),
      );
    }
    final dateFmt = DateFormat.yMd().add_Hm();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Subsystems',
            subtitle: 'Launch locally-built bundles. Registry: ${_registryPath ?? "—"}',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
              FilledButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add bundle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.business, size: 48, color: cs.outline),
                      const SizedBox(height: 12),
                      const Text(
                        'No subsystems registered yet.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Click "Add bundle" and point at a folder produced by tools/build-subsystem.',
                        style: TextStyle(color: cs.outline),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final s in _items) ...[
                    ListTile(
                      leading: Icon(
                        Icons.circle,
                        size: 14,
                        color: _statusColor(s['status']?.toString() ?? 'stopped', cs),
                      ),
                      title: Text(
                        s['name']?.toString() ?? '(unnamed)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            s['bundleDir']?.toString() ?? '',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            children: [
                              _Chip(icon: Icons.lan, label: 'port ${s['port']}'),
                              _Chip(
                                icon: Icons.power_settings_new,
                                label: (s['status'] ?? 'stopped').toString(),
                              ),
                              if (s['lastStartedAt'] != null)
                                _Chip(
                                  icon: Icons.schedule,
                                  label: 'started ${dateFmt.format(DateTime.parse(s['lastStartedAt']).toLocal())}',
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: _RowActions(
                        status: s['status']?.toString() ?? 'stopped',
                        busy: _busyId == s['id'],
                        onStart: () => _start(s),
                        onStop: () => _stop(s),
                        onRestart: () => _restart(s),
                        onLogs: () => _viewLogs(s),
                        onRemove: () => _remove(s),
                        onReassign: () => _reassignPort(s),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.outline),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.status,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onLogs,
    required this.onRemove,
    required this.onReassign,
  });
  final String status;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onLogs;
  final VoidCallback onRemove;
  final VoidCallback onReassign;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 32, height: 32,
        child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final isRunning = status == 'running' || status == 'partial';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRunning)
          IconButton(
            tooltip: 'Stop',
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
          )
        else
          IconButton(
            tooltip: 'Start',
            onPressed: onStart,
            icon: const Icon(Icons.play_circle_outline, color: Colors.green),
          ),
        IconButton(
          tooltip: isRunning ? 'Restart' : 'Start the subsystem first',
          onPressed: isRunning ? onRestart : null,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'View logs',
          onPressed: onLogs,
          icon: const Icon(Icons.terminal),
        ),
        IconButton(
          tooltip: isRunning ? 'Stop the subsystem first' : 'Reassign port',
          onPressed: isRunning ? null : onReassign,
          icon: const Icon(Icons.swap_horiz),
        ),
        IconButton(
          tooltip: 'Remove from registry',
          onPressed: isRunning ? null : onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _LogsDialog extends ConsumerStatefulWidget {
  const _LogsDialog({required this.id, required this.name});
  final String id;
  final String name;

  @override
  ConsumerState<_LogsDialog> createState() => _LogsDialogState();
}

class _LogsDialogState extends ConsumerState<_LogsDialog> {
  bool _loading = true;
  String? _error;
  List<String> _lines = const [];
  int _bytes = 0;
  String? _path;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).getJson(
        '/admin/subsystems/${widget.id}/logs',
        query: {'lines': '500'},
      );
      if (!mounted) return;
      setState(() {
        _lines = ((res['lines'] as List?) ?? const []).map((e) => e.toString()).toList();
        _bytes = (res['bytes'] as num?)?.toInt() ?? 0;
        _path = res['path']?.toString();
        _loading = false;
      });
      // Auto-scroll to bottom after the frame paints.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _humanBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logs · ${widget.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (_path != null)
                          Text(
                            '${_path!} · ${_humanBytes(_bytes)}',
                            style: TextStyle(fontSize: 11, color: cs.outline, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(child: Text('Failed to load logs: $_error')),
                        )
                      : _lines.isEmpty
                          ? Center(
                              child: Text(
                                'No log output yet. Start the subsystem to capture stdout/stderr.',
                                style: TextStyle(color: cs.outline),
                              ),
                            )
                          : Container(
                              color: cs.surfaceContainerHighest,
                              padding: const EdgeInsets.all(12),
                              child: Scrollbar(
                                controller: _scroll,
                                child: SingleChildScrollView(
                                  controller: _scroll,
                                  child: SelectableText(
                                    _lines.join('\n'),
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReassignPortDialog extends StatefulWidget {
  const _ReassignPortDialog({required this.currentPort});
  final int currentPort;

  @override
  State<_ReassignPortDialog> createState() => _ReassignPortDialogState();
}

class _ReassignPortDialogState extends State<_ReassignPortDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentPort.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _ctrl.text.trim();
    final n = int.tryParse(raw);
    if (n == null || n < 1 || n > 65535) {
      setState(() => _error = 'Port must be an integer in 1..65535');
      return;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reassign port'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Currently: ${widget.currentPort}'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'New port',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'Rewrites the bundle\'s backend/.env. The subsystem must be '
            'stopped. Doesn\'t affect start.bat\'s own port-pool scan.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Reassign')),
      ],
    );
  }
}

class _AddBundleDialog extends ConsumerStatefulWidget {
  const _AddBundleDialog();
  @override
  ConsumerState<_AddBundleDialog> createState() => _AddBundleDialogState();
}

class _AddBundleDialogState extends ConsumerState<_AddBundleDialog> {
  final _pathCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _inspected;

  @override
  void dispose() {
    _pathCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _inspected = null;
    });
    try {
      final res = await ref.read(apiClientProvider).postJson(
        '/admin/subsystems/inspect',
        body: {'bundleDir': path},
      );
      if (!mounted) return;
      setState(() {
        _inspected = res;
        if (_nameCtrl.text.trim().isEmpty) {
          _nameCtrl.text = (res['suggestedName'] ?? '').toString();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).postJson(
        '/admin/subsystems',
        body: {
          'bundleDir': _pathCtrl.text.trim(),
          'name': _nameCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRegister = _inspected != null && !_busy;
    return AlertDialog(
      title: const Text('Add subsystem bundle'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the path to a folder produced by tools/build-subsystem '
              '(the one containing backend/, app/, and start.bat).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pathCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Bundle folder path',
                hintText: r'D:\dist\factory-abc',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Inspect',
                  onPressed: _busy ? null : _inspect,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _inspect(),
            ),
            if (_inspected != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      const Text('Looks like a valid bundle.'),
                    ]),
                    const SizedBox(height: 6),
                    Text('Port: ${_inspected!['port']}'),
                    Text('Has .exe: ${_inspected!['hasExe'] == true ? "yes" : "no"}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canRegister ? _register : null,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Register'),
        ),
      ],
    );
  }
}
