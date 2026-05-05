// Phase 4.17 v2 — visual chain builder for the workflow editor.
//
// The v1 editor had two raw-JSON textareas (trigger + actions). This
// version renders structured forms for the common path and keeps the
// raw-JSON fallback behind an "Advanced" switch so power users still
// have an escape hatch. Free-form sub-objects (`fields`, `headers`,
// `payload`, `context`, request `body`) stay JSON inside the structured
// card — going fully visual on those is v3 territory.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

const _kTriggerTypes = ['record', 'event', 'schedule', 'webhook'];
const _kActionTypes = [
  'set_field', 'create_record', 'http_request',
  'dispatch_event', 'create_approval', 'log',
];
const _kRecordOps = ['created', 'updated', 'deleted'];
const _kScheduleFrequencies = [
  'every_minute', 'every_5_minutes', 'hourly',
  'daily', 'weekly', 'monthly', 'cron',
];
const _kConditionOps = [
  'equals', 'notEquals', 'gt', 'gte', 'lt', 'lte',
  'in', 'contains', 'isNull', 'isNotNull', 'matches',
];
// Composers read separately; they're "all"/"any"/"not" wrappers.
const _kConditionComposers = ['all', 'any', 'not'];

class WorkflowEditorDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final Map<String, dynamic> catalog;  // /api/workflows/triggers response
  const WorkflowEditorDialog({super.key, this.existing, required this.catalog});

  @override
  ConsumerState<WorkflowEditorDialog> createState() => _WorkflowEditorDialogState();
}

class _WorkflowEditorDialogState extends ConsumerState<WorkflowEditorDialog> {
  late TextEditingController _code;
  late TextEditingController _name;
  late TextEditingController _desc;
  late String _triggerType;
  late Map<String, dynamic> _triggerCfg;
  late List<Map<String, dynamic>> _actions;

  bool _advanced = false;
  late TextEditingController _triggerCfgJson;
  late TextEditingController _actionsJson;

  // For event trigger — populated lazily from /api/webhooks/events.
  List<String> _knownEvents = [];

  // For record trigger — populated lazily from /api/custom-entities.
  List<String> _knownEntities = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?['code']?.toString() ?? '');
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _desc = TextEditingController(text: e?['description']?.toString() ?? '');
    _triggerType = e?['triggerType']?.toString() ?? 'event';
    _triggerCfg = Map<String, dynamic>.from((e?['triggerConfig'] as Map?) ?? _defaultTriggerCfg(_triggerType));
    _actions = ((e?['actions'] as List?) ?? const [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
    _triggerCfgJson = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(_triggerCfg));
    _actionsJson = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(_actions));

    // Best-effort metadata loads — UI still works if either fails.
    _loadEvents();
    _loadEntities();
  }

  Future<void> _loadEvents() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getJson('/webhooks/events');
      if (!mounted) return;
      setState(() {
        _knownEvents = (res['items'] as List).map((e) => e.toString()).toList();
      });
    } catch (_) { /* leave empty — operator falls back to free-text */ }
  }

  Future<void> _loadEntities() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getJson('/custom-entities');
      if (!mounted) return;
      setState(() {
        _knownEntities = (res['items'] as List)
            .map((e) => (e as Map)['code']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      });
    } catch (_) { /* leave empty */ }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _desc.dispose();
    _triggerCfgJson.dispose();
    _actionsJson.dispose();
    super.dispose();
  }

  Map<String, dynamic> _defaultTriggerCfg(String type) {
    switch (type) {
      case 'record': return {'entity': '', 'on': ['created']};
      case 'event': return {'event': 'approval.approved'};
      case 'schedule': return {'frequency': 'daily', 'timeOfDay': '08:00'};
      case 'webhook': return {};  // secret auto-generated server-side
      default: return {};
    }
  }

  Map<String, dynamic> _defaultActionParams(String type) {
    switch (type) {
      case 'set_field': return {'entity': '', 'id': '{{trigger.row.id}}', 'fields': {}};
      case 'create_record': return {'entity': '', 'fields': {}};
      case 'http_request': return {'method': 'POST', 'url': 'https://', 'headers': {}, 'body': {}};
      case 'dispatch_event': return {'event': '', 'payload': {}};
      case 'create_approval': return {'entity': '', 'title': '', 'payload': {}};
      case 'log': return {'level': 'info', 'message': ''};
      default: return {};
    }
  }

  // Sync the structured ↔ raw representations on toggle so neither
  // side loses edits made in the other.
  void _toggleAdvanced(bool v) {
    setState(() {
      if (v) {
        _triggerCfgJson.text = const JsonEncoder.withIndent('  ').convert(_triggerCfg);
        _actionsJson.text = const JsonEncoder.withIndent('  ').convert(_actions);
      } else {
        try {
          _triggerCfg = Map<String, dynamic>.from(jsonDecode(_triggerCfgJson.text) as Map);
          _actions = (jsonDecode(_actionsJson.text) as List)
              .map((a) => Map<String, dynamic>.from(a as Map))
              .toList();
        } catch (_) {
          // If the raw JSON can't be parsed back, keep the toggle off
          // and surface a snackbar.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Raw JSON is invalid — fix it before switching back to visual.')),
          );
          return;
        }
      }
      _advanced = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit workflow' : 'New workflow'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _code,
                enabled: !_isEdit,
                decoration: const InputDecoration(labelText: 'code (lower_snake, unique)'),
              ),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _triggerType,
                      items: _kTriggerTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _triggerType = v;
                          _triggerCfg = _defaultTriggerCfg(v);
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Trigger type'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Text('Advanced (raw JSON)'),
                      Switch(value: _advanced, onChanged: _toggleAdvanced),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_advanced) _buildAdvancedJsonEditors() else _buildVisualEditors(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        FilledButton(onPressed: _onSave, child: Text(_isEdit ? 'Save' : 'Create')),
      ],
    );
  }

  // ------------------------- Visual editors --------------------------

  Widget _buildVisualEditors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trigger', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildTriggerForm(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add action'),
              onPressed: () => setState(() {
                _actions.add({'type': 'log', 'name': '', 'params': _defaultActionParams('log')});
              }),
            ),
          ],
        ),
        if (_actions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No actions yet. Add one above.', style: TextStyle(color: Colors.grey)),
          ),
        ..._actions.asMap().entries.map((entry) => _buildActionCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildTriggerForm() {
    switch (_triggerType) {
      case 'record':
        return _buildRecordTriggerForm();
      case 'event':
        return _buildEventTriggerForm();
      case 'schedule':
        return _buildScheduleTriggerForm();
      case 'webhook':
        return _buildWebhookTriggerForm();
      default:
        return const SizedBox();
    }
  }

  Widget _buildRecordTriggerForm() {
    final entity = (_triggerCfg['entity'] as String?) ?? '';
    final ops = ((_triggerCfg['on'] as List?) ?? const ['created']).cast<String>().toSet();
    final filter = _triggerCfg['filter'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_knownEntities.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _knownEntities.contains(entity) ? entity : null,
            items: _knownEntities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _triggerCfg['entity'] = v ?? ''),
            decoration: const InputDecoration(labelText: 'Entity'),
          )
        else
          TextField(
            controller: TextEditingController(text: entity),
            decoration: const InputDecoration(labelText: 'Entity (custom-entity code)'),
            onChanged: (v) => _triggerCfg['entity'] = v,
          ),
        const SizedBox(height: 8),
        const Text('Fire on:'),
        Wrap(
          spacing: 6,
          children: _kRecordOps.map((op) {
            return FilterChip(
              label: Text(op),
              selected: ops.contains(op),
              onSelected: (sel) => setState(() {
                if (sel) {
                  ops.add(op);
                } else {
                  ops.remove(op);
                }
                _triggerCfg['on'] = ops.toList();
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text('Filter (optional):'),
        ConditionEditor(
          value: filter is Map ? Map<String, dynamic>.from(filter) : null,
          onChanged: (next) => setState(() {
            if (next == null) {
              _triggerCfg.remove('filter');
            } else {
              _triggerCfg['filter'] = next;
            }
          }),
        ),
      ],
    );
  }

  Widget _buildEventTriggerForm() {
    final cur = (_triggerCfg['event'] as String?) ?? '';
    final options = {..._knownEvents, '*'}.toList()..sort();
    if (cur.isNotEmpty && !options.contains(cur)) options.add(cur);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (options.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: options.contains(cur) ? cur : null,
            items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _triggerCfg['event'] = v ?? ''),
            decoration: const InputDecoration(labelText: 'Event'),
          ),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: cur),
          decoration: const InputDecoration(labelText: 'Or enter event name (free text)'),
          onChanged: (v) => _triggerCfg['event'] = v,
        ),
      ],
    );
  }

  Widget _buildScheduleTriggerForm() {
    final freq = (_triggerCfg['frequency'] as String?) ?? 'daily';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _kScheduleFrequencies.contains(freq) ? freq : 'daily',
          items: _kScheduleFrequencies
              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (v) => setState(() => _triggerCfg['frequency'] = v ?? 'daily'),
          decoration: const InputDecoration(labelText: 'Frequency'),
        ),
        const SizedBox(height: 8),
        if (freq == 'daily' || freq == 'weekly' || freq == 'monthly')
          TextField(
            controller: TextEditingController(text: (_triggerCfg['timeOfDay'] as String?) ?? '08:00'),
            decoration: const InputDecoration(labelText: 'Time of day (HH:MM, UTC)'),
            onChanged: (v) => _triggerCfg['timeOfDay'] = v,
          ),
        if (freq == 'weekly')
          TextField(
            controller: TextEditingController(text: ((_triggerCfg['dayOfWeek'] ?? 1).toString())),
            decoration: const InputDecoration(labelText: 'Day of week (0=Sun … 6=Sat)'),
            onChanged: (v) => _triggerCfg['dayOfWeek'] = int.tryParse(v) ?? 1,
          ),
        if (freq == 'monthly')
          TextField(
            controller: TextEditingController(text: ((_triggerCfg['dayOfMonth'] ?? 1).toString())),
            decoration: const InputDecoration(labelText: 'Day of month (1-28)'),
            onChanged: (v) => _triggerCfg['dayOfMonth'] = int.tryParse(v) ?? 1,
          ),
        if (freq == 'cron')
          TextField(
            controller: TextEditingController(text: (_triggerCfg['cron'] as String?) ?? '*/15 * * * *'),
            decoration: const InputDecoration(labelText: 'Cron expression (5 fields)'),
            onChanged: (v) => _triggerCfg['cron'] = v,
          ),
      ],
    );
  }

  Widget _buildWebhookTriggerForm() {
    final secret = (_triggerCfg['secret'] as String?) ?? '';
    final code = _code.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'External systems POST to /api/workflows/incoming/<code> with the X-Workflow-Secret header. '
          'Leave secret blank on create — the server will auto-generate one and return it ONCE.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: secret),
          decoration: InputDecoration(
            labelText: 'Shared secret (optional — auto-generated if blank)',
            suffixIcon: secret.isNotEmpty
                ? const Icon(Icons.vpn_key, size: 16)
                : null,
          ),
          onChanged: (v) => _triggerCfg['secret'] = v,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        if (_isEdit && secret.isNotEmpty && code.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Test from a shell:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          SelectableText(
            'curl -X POST http://<host>:4040/api/workflows/incoming/$code \\\n'
            '  -H "X-Workflow-Secret: $secret" \\\n'
            '  -H "Content-Type: application/json" \\\n'
            '  -d \'{"hello":"world"}\'',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildActionCard(int index, Map<String, dynamic> action) {
    final type = (action['type'] as String?) ?? 'log';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _kActionTypes.contains(type) ? type : 'log',
                    items: _kActionTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        action['type'] = v;
                        action['params'] = _defaultActionParams(v);
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Action type', isDense: true),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  tooltip: 'Move up',
                  onPressed: index > 0
                      ? () => setState(() {
                          final tmp = _actions[index - 1];
                          _actions[index - 1] = _actions[index];
                          _actions[index] = tmp;
                        })
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  tooltip: 'Move down',
                  onPressed: index < _actions.length - 1
                      ? () => setState(() {
                          final tmp = _actions[index + 1];
                          _actions[index + 1] = _actions[index];
                          _actions[index] = tmp;
                        })
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _actions.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: (action['name'] as String?) ?? ''),
              decoration: const InputDecoration(
                labelText: 'Step name (optional — referenced by later steps as {{steps.<name>.<key>}})',
                isDense: true,
              ),
              onChanged: (v) => action['name'] = v.isEmpty ? null : v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: action['stopOnError'] == true,
                  onChanged: (v) => setState(() => action['stopOnError'] = v == true),
                ),
                const Text('Stop chain on this step\'s failure'),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Condition (optional):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ConditionEditor(
              value: action['condition'] is Map ? Map<String, dynamic>.from(action['condition']) : null,
              onChanged: (next) => setState(() {
                if (next == null) {
                  action.remove('condition');
                } else {
                  action['condition'] = next;
                }
              }),
            ),
            const SizedBox(height: 8),
            const Text('Params:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            _buildActionParamsForm(type, action),
          ],
        ),
      ),
    );
  }

  Widget _buildActionParamsForm(String type, Map<String, dynamic> action) {
    final params = (action['params'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    action['params'] = params;
    switch (type) {
      case 'set_field':
        return Column(children: [
          _stringField(params, 'entity', 'Entity (custom-entity code)'),
          _stringField(params, 'id', 'Row ID (supports {{trigger.row.id}})'),
          _jsonField(params, 'fields', 'Fields to set (JSON object)'),
        ]);
      case 'create_record':
        return Column(children: [
          _stringField(params, 'entity', 'Entity (custom-entity code)'),
          _jsonField(params, 'fields', 'Fields (JSON object)'),
        ]);
      case 'http_request':
        return Column(children: [
          DropdownButtonFormField<String>(
            initialValue: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
                .contains((params['method'] as String?)?.toUpperCase()) ? (params['method'] as String?)?.toUpperCase() : 'POST',
            items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => params['method'] = v ?? 'POST',
            decoration: const InputDecoration(labelText: 'Method', isDense: true),
          ),
          _stringField(params, 'url', 'URL (https://…)'),
          _jsonField(params, 'headers', 'Headers (JSON object)'),
          _jsonField(params, 'body', 'Body (JSON object or string)'),
        ]);
      case 'dispatch_event':
        return Column(children: [
          _stringField(params, 'event', 'Event name'),
          _jsonField(params, 'payload', 'Payload (JSON)'),
        ]);
      case 'create_approval':
        return Column(children: [
          _stringField(params, 'entity', 'Entity'),
          _stringField(params, 'entityId', 'Entity ID (optional)'),
          _stringField(params, 'title', 'Title'),
          _stringField(params, 'description', 'Description (optional)'),
          _jsonField(params, 'payload', 'Payload (JSON)'),
        ]);
      case 'log':
        return Column(children: [
          DropdownButtonFormField<String>(
            initialValue: ['info', 'warn', 'error', 'debug'].contains(params['level']) ? params['level'] : 'info',
            items: ['info', 'warn', 'error', 'debug']
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => params['level'] = v ?? 'info',
            decoration: const InputDecoration(labelText: 'Level', isDense: true),
          ),
          _stringField(params, 'message', 'Message'),
          _jsonField(params, 'context', 'Context (optional, JSON)'),
        ]);
      default:
        return const SizedBox();
    }
  }

  Widget _stringField(Map<String, dynamic> params, String key, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: TextEditingController(text: params[key]?.toString() ?? ''),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) => params[key] = v,
      ),
    );
  }

  Widget _jsonField(Map<String, dynamic> params, String key, String label) {
    final initial = params[key];
    final controller = TextEditingController(
      text: initial == null
          ? ''
          : (initial is String ? initial : const JsonEncoder.withIndent('  ').convert(initial)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: controller,
        maxLines: 4,
        minLines: 1,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        onChanged: (v) {
          if (v.trim().isEmpty) {
            params.remove(key);
            return;
          }
          // Try JSON; on failure store raw string. Validation happens at save time.
          try {
            params[key] = jsonDecode(v);
          } catch (_) {
            params[key] = v;
          }
        },
      ),
    );
  }

  // ------------------------- Advanced JSON ---------------------------

  Widget _buildAdvancedJsonEditors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Trigger config (raw JSON)', style: TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          controller: _triggerCfgJson,
          maxLines: 6,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        const Text('Actions (raw JSON array)', style: TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          controller: _actionsJson,
          maxLines: 16,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  // ------------------------- Save handler ---------------------------

  Future<void> _onSave() async {
    Map<String, dynamic> outCfg;
    List<dynamic> outActions;
    if (_advanced) {
      try {
        outCfg = Map<String, dynamic>.from(jsonDecode(_triggerCfgJson.text) as Map);
        outActions = jsonDecode(_actionsJson.text) as List;
      } catch (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid JSON in raw editor: $err')),
        );
        return;
      }
    } else {
      outCfg = _triggerCfg;
      outActions = _actions;
    }

    final api = ref.read(apiClientProvider);
    try {
      Map<String, dynamic> result;
      if (_isEdit) {
        result = await api.putJson('/workflows/${widget.existing!['id']}', body: {
          'name': _name.text.trim(),
          'description': _desc.text.trim(),
          'triggerType': _triggerType,
          'triggerConfig': outCfg,
          'actions': outActions,
        });
      } else {
        result = await api.postJson('/workflows', body: {
          'code': _code.text.trim(),
          'name': _name.text.trim(),
          'description': _desc.text.trim(),
          'triggerType': _triggerType,
          'triggerConfig': outCfg,
          'actions': outActions,
        });
      }
      if (!mounted) return;
      // For webhook trigger creates, surface the auto-generated secret
      // ONCE so the operator can copy it.
      final cfg = (result['triggerConfig'] as Map?) ?? const {};
      if (!_isEdit && _triggerType == 'webhook' && cfg['secret'] != null) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Workflow webhook secret'),
            content: SelectableText(
              'Save this secret — it is only shown once on create. Senders include it as the X-Workflow-Secret header.\n\n${cfg['secret']}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }
}

// ---------------------------------------------------------------------------
// Condition editor — recursive widget for the JSON DSL.
// ---------------------------------------------------------------------------

class ConditionEditor extends StatefulWidget {
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  final int depth;

  const ConditionEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.depth = 0,
  });

  @override
  State<ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends State<ConditionEditor> {
  late Map<String, dynamic>? _v;

  @override
  void initState() {
    super.initState();
    _v = widget.value == null ? null : Map<String, dynamic>.from(widget.value!);
  }

  @override
  void didUpdateWidget(ConditionEditor old) {
    super.didUpdateWidget(old);
    // Re-sync when parent rebuilds with a new value (avoids stale reads).
    if (widget.value != old.value) {
      _v = widget.value == null ? null : Map<String, dynamic>.from(widget.value!);
    }
  }

  void _emit() => widget.onChanged(_v);

  @override
  Widget build(BuildContext context) {
    if (_v == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add condition'),
          onPressed: () => setState(() {
            _v = {'field': '', 'equals': ''};
            _emit();
          }),
        ),
      );
    }

    // Bail out at depth >= 3 — nested composers get unwieldy in v2.
    if (widget.depth >= 3) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Nested >3 deep — switch to "Advanced (raw JSON)" to edit further.',
          style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
        ),
      );
    }

    final isAll = _v!.containsKey('all');
    final isAny = _v!.containsKey('any');
    final isNot = _v!.containsKey('not');
    final isLeaf = _v!.containsKey('field');

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<String>(
                value: isAll ? 'all' : isAny ? 'any' : isNot ? 'not' : 'leaf',
                items: const [
                  DropdownMenuItem(value: 'leaf', child: Text('Single')),
                  DropdownMenuItem(value: 'all', child: Text('ALL of (AND)')),
                  DropdownMenuItem(value: 'any', child: Text('ANY of (OR)')),
                  DropdownMenuItem(value: 'not', child: Text('NOT')),
                ],
                onChanged: (v) {
                  setState(() {
                    if (v == 'leaf') {
                      _v = {'field': '', 'equals': ''};
                    } else if (v == 'all') {
                      _v = {'all': <Map<String, dynamic>>[]};
                    } else if (v == 'any') {
                      _v = {'any': <Map<String, dynamic>>[]};
                    } else if (v == 'not') {
                      _v = {'not': <String, dynamic>{'field': '', 'equals': ''}};
                    }
                    _emit();
                  });
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Remove condition',
                onPressed: () => setState(() {
                  _v = null;
                  _emit();
                }),
              ),
            ],
          ),
          if (isLeaf) _buildLeaf(),
          if (isAll || isAny) _buildList(isAll ? 'all' : 'any'),
          if (isNot) _buildNot(),
        ],
      ),
    );
  }

  Widget _buildLeaf() {
    final field = (_v!['field'] as String?) ?? '';
    String op = _kConditionOps.firstWhere(
      (o) => _v!.containsKey(o),
      orElse: () => 'equals',
    );
    if (!_kConditionOps.contains(op) || _kConditionComposers.contains(op)) op = 'equals';
    final raw = _v![op];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: TextEditingController(text: field),
            decoration: const InputDecoration(labelText: 'Field path (e.g. trigger.row.status)', isDense: true),
            onChanged: (v) {
              _v!['field'] = v;
              _emit();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            initialValue: op,
            items: _kConditionOps
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                final keep = _v!['field'];
                _v!.removeWhere((k, _) => k != 'field');
                _v!['field'] = keep;
                if (v == 'isNull' || v == 'isNotNull') {
                  _v![v] = true;
                } else {
                  _v![v] = '';
                }
                _emit();
              });
            },
            decoration: const InputDecoration(labelText: 'Operator', isDense: true),
          ),
        ),
        if (op != 'isNull' && op != 'isNotNull') ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextField(
              controller: TextEditingController(text: raw is String ? raw : raw?.toString() ?? ''),
              decoration: const InputDecoration(labelText: 'Value', isDense: true),
              onChanged: (v) {
                // For numeric ops, try to coerce to a number.
                if (['gt', 'gte', 'lt', 'lte'].contains(op)) {
                  final n = num.tryParse(v);
                  _v![op] = n ?? v;
                } else if (op == 'in') {
                  _v![op] = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                } else {
                  _v![op] = v;
                }
                _emit();
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildList(String key) {
    final list = (_v![key] as List?)?.cast<dynamic>() ?? <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...list.asMap().entries.map((entry) {
          final idx = entry.key;
          final child = entry.value is Map ? Map<String, dynamic>.from(entry.value as Map) : null;
          return Row(
            children: [
              Expanded(
                child: ConditionEditor(
                  value: child,
                  depth: widget.depth + 1,
                  onChanged: (next) {
                    setState(() {
                      if (next == null) {
                        list.removeAt(idx);
                      } else {
                        list[idx] = next;
                      }
                      _v![key] = list;
                      _emit();
                    });
                  },
                ),
              ),
            ],
          );
        }),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add condition'),
          onPressed: () => setState(() {
            list.add({'field': '', 'equals': ''});
            _v![key] = list;
            _emit();
          }),
        ),
      ],
    );
  }

  Widget _buildNot() {
    final inner = _v!['not'] is Map ? Map<String, dynamic>.from(_v!['not'] as Map) : null;
    return ConditionEditor(
      value: inner,
      depth: widget.depth + 1,
      onChanged: (next) => setState(() {
        _v!['not'] = next ?? {'field': '', 'equals': ''};
        _emit();
      }),
    );
  }
}
