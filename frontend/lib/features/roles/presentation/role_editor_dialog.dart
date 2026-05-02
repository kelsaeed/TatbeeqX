import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class RoleEditorDialog extends ConsumerStatefulWidget {
  const RoleEditorDialog({super.key, this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends ConsumerState<RoleEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;

  Set<int> _selected = {};
  List<Map<String, dynamic>> _permissions = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?['code']?.toString() ?? '');
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _description = TextEditingController(text: e?['description']?.toString() ?? '');
    _selected = ((e?['permissionIds'] as List? ?? const []).cast<int>()).toSet();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final res = await api.getJson('/permissions');
    if (!mounted) return;
    setState(() {
      _permissions = (res['items'] as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  void _applyPreset(List<Map<String, dynamic>> modulePerms, List<String> actions) {
    final wanted = actions.toSet();
    setState(() {
      for (final p in modulePerms) {
        final id = p['id'] as int;
        final action = p['action']?.toString() ?? '';
        if (wanted.contains(action)) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final body = {
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'permissionIds': _selected.toList(),
    };
    try {
      if (widget.existing == null) {
        await api.postJson('/roles', body: body);
      } else {
        await api.putJson('/roles/${widget.existing!['id']}', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byModule = groupBy<Map<String, dynamic>, String>(_permissions, (p) => p['module'].toString());
    final modules = byModule.keys.toList()..sort();

    return AlertDialog(
      title: Text(widget.existing == null ? 'New role' : 'Edit role'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _code,
                        decoration: const InputDecoration(labelText: 'Code (e.g. accountant)'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        enabled: widget.existing?['isSystem'] != true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Display name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                else
                  ...modules.map((mod) {
                    final perms = byModule[mod]!..sort((a, b) => a['action'].toString().compareTo(b['action'].toString()));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(mod, style: Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _PresetChip(label: 'None', onTap: () => _applyPreset(perms, const [])),
                              _PresetChip(label: 'View', onTap: () => _applyPreset(perms, const ['view'])),
                              _PresetChip(label: 'View + edit', onTap: () => _applyPreset(perms, const ['view', 'create', 'edit'])),
                              _PresetChip(label: 'View + edit + delete', onTap: () => _applyPreset(perms, const ['view', 'create', 'edit', 'delete'])),
                              _PresetChip(label: 'Full', onTap: () => _applyPreset(perms, const ['view', 'create', 'edit', 'delete', 'approve', 'export', 'print', 'manage_settings', 'manage_users', 'manage_roles'])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: perms.map((p) {
                              final id = p['id'] as int;
                              return FilterChip(
                                label: Text(p['action'].toString()),
                                selected: _selected.contains(id),
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
