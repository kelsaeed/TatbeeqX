// Phase 4.17 — workflows page (engine v1).
//
// JSON-edited definition + run history. Visual builder is v2; v1 is a
// power-user surface keyed off /api/workflows. The engine spec lives
// at docs/48-workflow-engine.md.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/page_header.dart';

class WorkflowsPage extends ConsumerStatefulWidget {
  const WorkflowsPage({super.key});

  @override
  ConsumerState<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends ConsumerState<WorkflowsPage> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _catalog = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getJson('/workflows');
      final cat = await api.getJson('/workflows/triggers');
      if (!mounted) return;
      setState(() {
        _items = (res['items'] as List).cast<Map<String, dynamic>>();
        _catalog = cat;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Workflows',
            subtitle: 'Run actions when records change, events fire, or on a schedule.',
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New workflow'),
                onPressed: _newWorkflow,
              ),
            ],
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No workflows yet. Create one to automate something.'),
            ),
          ..._items.map(_renderRow),
        ],
      ),
    );
  }

  Widget _renderRow(Map<String, dynamic> w) {
    final triggerType = w['triggerType']?.toString() ?? '';
    final triggerCfg = (w['triggerConfig'] as Map?) ?? const {};
    final actions = (w['actions'] as List?) ?? const [];
    final summary = _summarizeTrigger(triggerType, triggerCfg);
    return Card(
      child: ListTile(
        leading: Icon(
          w['enabled'] == true ? Icons.bolt : Icons.bolt_outlined,
          color: w['enabled'] == true ? Colors.green : Colors.grey,
        ),
        title: Text('${w['name']}  •  ${w['code']}'),
        subtitle: Text(
          'Trigger: $summary\n${actions.length} action(s)'
          '${w['description'] != null && (w['description'] as String).isNotEmpty ? '  •  ${w['description']}' : ''}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: Icon(w['enabled'] == true ? Icons.pause : Icons.play_arrow, size: 18),
              tooltip: w['enabled'] == true ? 'Disable' : 'Enable',
              onPressed: () => _toggle(w['id'] as int, !(w['enabled'] == true)),
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_outline, size: 18),
              tooltip: 'Run now',
              onPressed: () => _runNow(w['id'] as int),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: () => _editWorkflow(w),
            ),
            IconButton(
              icon: const Icon(Icons.history, size: 18),
              tooltip: 'Recent runs',
              onPressed: () => _showRuns(w['id'] as int, w['name']?.toString() ?? '-'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              onPressed: () => _delete(w['id'] as int),
            ),
          ],
        ),
      ),
    );
  }

  String _summarizeTrigger(String type, Map cfg) {
    switch (type) {
      case 'record':
        final ops = (cfg['on'] as List?)?.join(',') ?? 'all ops';
        return 'record  •  ${cfg['entity'] ?? '?'}  •  $ops';
      case 'event':
        return 'event  •  ${cfg['event'] ?? '?'}';
      case 'schedule':
        return 'schedule  •  ${cfg['frequency'] ?? '?'}';
      default:
        return type;
    }
  }

  Future<void> _toggle(int id, bool enabled) async {
    final api = ref.read(apiClientProvider);
    await api.putJson('/workflows/$id', body: {'enabled': enabled});
    await _load();
  }

  Future<void> _runNow(int id) async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.postJson('/workflows/$id/run');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Run ${res['runId']}: ${res['status']}')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete workflow?'),
        content: const Text('All run history is purged with it. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(apiClientProvider);
    await api.deleteJson('/workflows/$id');
    await _load();
  }

  Future<void> _showRuns(int id, String name) async {
    final api = ref.read(apiClientProvider);
    final res = await api.getJson('/workflows/$id/runs', query: {'page': 1, 'pageSize': 50});
    if (!mounted) return;
    final items = (res['items'] as List).cast<Map<String, dynamic>>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Recent runs for $name'),
        content: SizedBox(
          width: 720,
          child: items.isEmpty
              ? const Text('No runs yet.')
              : ListView(
                  shrinkWrap: true,
                  children: items.map((r) {
                    final iso = r['startedAt'] as String?;
                    final t = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
                    final ok = r['status'] == 'success';
                    return ListTile(
                      leading: Icon(
                        ok ? Icons.check_circle : Icons.error,
                        color: ok ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      title: Text('${r['triggerEvent']}  •  ${r['status']}'),
                      subtitle: Text(
                        '${t == null ? '' : DateFormat('yyyy-MM-dd HH:mm:ss').format(t)}'
                        '${r['error'] != null ? '\n${r['error']}' : ''}',
                      ),
                      dense: true,
                      onTap: () async {
                        final detail = await api.getJson('/workflows/runs/${r['id']}');
                        if (!mounted) return;
                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Run #${r['id']}  •  ${r['status']}'),
                            content: SizedBox(
                              width: 720,
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  const JsonEncoder.withIndent('  ').convert(detail),
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _newWorkflow() => _editWorkflow(null);

  Future<void> _editWorkflow(Map<String, dynamic>? existing) async {
    final isEdit = existing != null;
    final code = TextEditingController(text: existing?['code']?.toString() ?? '');
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final desc = TextEditingController(text: existing?['description']?.toString() ?? '');
    String triggerType = existing?['triggerType']?.toString() ?? 'event';
    final triggerCfg = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(existing?['triggerConfig'] ?? const {}),
    );
    final actionsJson = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(existing?['actions'] ?? const []),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isEdit ? 'Edit workflow' : 'New workflow'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: code,
                    enabled: !isEdit,  // code is unique + audit-anchor; never re-key
                    decoration: const InputDecoration(labelText: 'code (lower_snake, unique)'),
                  ),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: triggerType,
                    items: ((_catalog['triggerTypes'] as List?) ?? const ['record', 'event', 'schedule'])
                        .map((t) => DropdownMenuItem(value: t.toString(), child: Text(t.toString())))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setSt(() {
                        triggerType = v;
                        triggerCfg.text = const JsonEncoder.withIndent('  ').convert(_defaultCfg(v));
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Trigger type'),
                  ),
                  const SizedBox(height: 8),
                  Text('Trigger config (JSON)  •  hint: ${_triggerHint(triggerType)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  TextField(
                    controller: triggerCfg,
                    maxLines: 6,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Actions (JSON array)  •  types: ${(_catalog['actionTypes'] as List?)?.join(", ") ?? "—"}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  TextField(
                    controller: actionsJson,
                    maxLines: 12,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Save' : 'Create')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    Map<String, dynamic> parsedCfg;
    List<dynamic> parsedActions;
    try {
      parsedCfg = jsonDecode(triggerCfg.text) as Map<String, dynamic>;
      parsedActions = jsonDecode(actionsJson.text) as List<dynamic>;
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid JSON: $err')));
      return;
    }

    final api = ref.read(apiClientProvider);
    try {
      if (isEdit) {
        await api.putJson('/workflows/${existing['id']}', body: {
          'name': name.text.trim(),
          'description': desc.text.trim(),
          'triggerType': triggerType,
          'triggerConfig': parsedCfg,
          'actions': parsedActions,
        });
      } else {
        await api.postJson('/workflows', body: {
          'code': code.text.trim(),
          'name': name.text.trim(),
          'description': desc.text.trim(),
          'triggerType': triggerType,
          'triggerConfig': parsedCfg,
          'actions': parsedActions,
        });
      }
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Map<String, dynamic> _defaultCfg(String type) {
    switch (type) {
      case 'record': return {'entity': 'leads', 'on': ['created']};
      case 'event': return {'event': 'approval.approved'};
      case 'schedule': return {'frequency': 'daily', 'timeOfDay': '08:00'};
      default: return {};
    }
  }

  String _triggerHint(String type) {
    switch (type) {
      case 'record':
        return 'entity (string), on: ["created","updated","deleted"], optional filter';
      case 'event':
        return 'event (string) — e.g. "approval.approved" or "*"';
      case 'schedule':
        return 'frequency: daily/hourly/cron + timeOfDay/dayOfWeek/dayOfMonth/cron';
      default:
        return '';
    }
  }
}
