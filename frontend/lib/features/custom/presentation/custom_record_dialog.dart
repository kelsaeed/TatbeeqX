import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';

class CustomRecordDialog extends ConsumerStatefulWidget {
  const CustomRecordDialog({super.key, required this.entity, this.row});
  final Map<String, dynamic> entity;
  final Map<String, dynamic>? row;

  @override
  ConsumerState<CustomRecordDialog> createState() => _CustomRecordDialogState();
}

class _CustomRecordDialogState extends ConsumerState<CustomRecordDialog> {
  final _form = GlobalKey<FormState>();
  final _values = <String, dynamic>{};
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;

  List<Map<String, dynamic>> get _columns =>
      (widget.entity['config']?['columns'] as List? ?? const []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    for (final c in _columns) {
      final name = c['name'].toString();
      final type = c['type']?.toString();
      final initial = widget.row?[name];
      if (type == 'relations') {
        // Server returns relations as List<int> on getRow / listRows.
        // Stash a defensive copy so the picker mutates a local list.
        _values[name] = (initial is List)
            ? initial.map((v) => v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0).where((v) => v > 0).toList()
            : <int>[];
      } else {
        _values[name] = initial;
        if (type != 'bool') {
          _controllers[name] = TextEditingController(text: initial?.toString() ?? '');
        }
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{};
      for (final c in _columns) {
        final name = c['name'].toString();
        final type = c['type']?.toString();
        if (type == 'bool') {
          body[name] = _values[name] == true ? 1 : 0;
        } else if (type == 'relations') {
          // Already stored as List<int> in _values — pass through verbatim.
          body[name] = (_values[name] as List?)?.cast<int>() ?? const <int>[];
        } else {
          final v = _controllers[name]?.text ?? '';
          if (v.isEmpty) {
            body[name] = null;
          } else if (type == 'integer') {
            body[name] = int.tryParse(v);
          } else if (type == 'number') {
            body[name] = double.tryParse(v);
          } else {
            body[name] = v;
          }
        }
      }
      final code = widget.entity['code'].toString();
      if (widget.row == null) {
        await api.postJson('/c/$code', body: body);
      } else {
        await api.putJson('/c/$code/${widget.row!['id']}', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Phase 4.16 — field-level permission guard. Returns true if the
  // current user can view this column. Backend already strips data
  // for restricted columns; this hides the empty input on the
  // frontend so the operator doesn't see a phantom blank field.
  bool _canView(Map<String, dynamic> c) {
    final code = c['viewPermission']?.toString();
    if (code == null || code.isEmpty) return true;
    return ref.read(authControllerProvider).can(code);
  }

  // True if the user can edit this column. editPermission falls back
  // to viewPermission to match the backend's `canEditCol` semantics.
  bool _canEdit(Map<String, dynamic> c) {
    final code = (c['editPermission']?.toString().isNotEmpty == true)
        ? c['editPermission']!.toString()
        : c['viewPermission']?.toString();
    if (code == null || code.isEmpty) return true;
    return ref.read(authControllerProvider).can(code);
  }

  Widget _fieldFor(Map<String, dynamic> c, AppLocalizations t) {
    final name = c['name'].toString();
    final label = c['label']?.toString() ?? name;
    final type = c['type']?.toString() ?? 'text';
    final required = c['required'] == true;
    final readOnly = !_canEdit(c);

    if (type == 'bool') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SwitchListTile(
          title: Text(label),
          contentPadding: EdgeInsets.zero,
          value: _values[name] == 1 || _values[name] == true,
          onChanged: readOnly ? null : (v) => setState(() => _values[name] = v),
        ),
      );
    }

    if (type == 'relations') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _RelationsField(
          label: label,
          targetCode: c['targetEntity']?.toString(),
          initial: (_values[name] as List?)?.cast<int>() ?? const <int>[],
          onChanged: readOnly ? (_) {} : (ids) => _values[name] = ids,
          readOnly: readOnly,
        ),
      );
    }

    if (type == 'formula') {
      // Phase 4.16 — formula columns are computed server-side; render
      // as a read-only display showing the most recently saved value
      // (or "—" on a fresh record where the row hasn't round-tripped
      // yet). After Save, the dialog closes; on next open the
      // computed value is back from the server.
      final v = _values[name];
      final display = v == null ? '—' : v.toString();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: AppLocalizations.of(context).computedHelp,
            suffixIcon: const Tooltip(
              message: '',
              child: Icon(Icons.functions, size: 18),
            ),
          ),
          child: Text(display),
        ),
      );
    }

    if (type == 'longtext') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextFormField(
          controller: _controllers[name],
          decoration: InputDecoration(labelText: label),
          minLines: 2,
          maxLines: 5,
          readOnly: readOnly,
          enabled: !readOnly,
          validator: required ? (v) => (v == null || v.isEmpty) ? t.required : null : null,
        ),
      );
    }

    final keyboard = (type == 'integer' || type == 'number')
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: _controllers[name],
        keyboardType: keyboard,
        readOnly: readOnly,
        enabled: !readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: type == 'date'
              ? 'YYYY-MM-DD'
              : type == 'datetime'
                  ? 'YYYY-MM-DD HH:MM'
                  : null,
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? t.required : null : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isEdit = widget.row != null;
    final singular = widget.entity['singular'].toString();
    return AlertDialog(
      title: Text(isEdit ? t.editEntitySingular(singular) : t.newEntitySingular(singular)),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              children: _columns
                  .where((c) => c['name'] != 'id' && _canView(c))
                  .map((c) => _fieldFor(c, t))
                  .toList(),
            ),
          ),
        ),
      ),
      actions: [
        if (isEdit && widget.row?['id'] != null)
          TextButton.icon(
            onPressed: _saving ? null : _showHistory,
            icon: const Icon(Icons.history, size: 16),
            label: Text(t.recordHistory),
          ),
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(t.cancel)),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? t.saving : t.save)),
      ],
    );
  }

  // Phase 4.16 follow-up — open a dialog showing this record's audit
  // history. Reads from /api/audit/by-record/:entity/:entityId. The
  // entity code is the custom-entity code (which is also what the
  // backend writes to AuditLog.entity in custom_records.js).
  Future<void> _showHistory() async {
    final id = widget.row!['id'];
    final code = widget.entity['code'].toString();
    await showDialog(
      context: context,
      builder: (_) => _RecordHistoryDialog(entityCode: code, entityId: id),
    );
  }
}

class _RecordHistoryDialog extends ConsumerStatefulWidget {
  const _RecordHistoryDialog({required this.entityCode, required this.entityId});
  final String entityCode;
  final dynamic entityId;

  @override
  ConsumerState<_RecordHistoryDialog> createState() => _RecordHistoryDialogState();
}

class _RecordHistoryDialogState extends ConsumerState<_RecordHistoryDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).getJson(
        '/audit/by-record/${widget.entityCode}/${widget.entityId}',
        query: {'pageSize': 100},
      );
      if (!mounted) return;
      setState(() {
        _items = ((res['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.recordHistory),
      content: SizedBox(
        width: 540,
        height: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(t.loadFailed(_error!)))
                : _items.isEmpty
                    ? Center(child: Text(t.noHistoryYet))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final entry = _items[i];
                          final user = entry['user'] as Map?;
                          final actor = user?['fullName']?.toString()
                              ?? user?['username']?.toString()
                              ?? t.systemActor;
                          final action = entry['action']?.toString() ?? '?';
                          final when = entry['createdAt']?.toString() ?? '';
                          return ListTile(
                            dense: true,
                            leading: Icon(_iconFor(action), size: 18),
                            title: Text('$actor • $action'),
                            subtitle: Text(when),
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close)),
      ],
    );
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'create': return Icons.add_circle_outline;
      case 'update': return Icons.edit_outlined;
      case 'delete': return Icons.delete_outline;
      case 'login': return Icons.login;
      case 'logout': return Icons.logout;
      case 'export': return Icons.file_download_outlined;
      default: return Icons.event_note_outlined;
    }
  }
}

// Phase 4.15 — many-to-many relations picker.
//
// Lazy-loads the target entity's records on first build, lets the user
// add/remove via a popup-menu of unselected rows + chips for selected
// ones. Resolves the target row's `name` (or `label` / `title`) for
// chip text, falling back to `#id` if no display field exists. Notifies
// the parent dialog of the IDs list on every change.
class _RelationsField extends ConsumerStatefulWidget {
  const _RelationsField({
    required this.label,
    required this.targetCode,
    required this.initial,
    required this.onChanged,
    this.readOnly = false,
  });
  final String label;
  final String? targetCode;
  final List<int> initial;
  final ValueChanged<List<int>> onChanged;
  final bool readOnly;

  @override
  ConsumerState<_RelationsField> createState() => _RelationsFieldState();
}

class _RelationsFieldState extends ConsumerState<_RelationsField> {
  late List<int> _selected;
  List<Map<String, dynamic>>? _options;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _selected = List<int>.from(widget.initial);
    final code = widget.targetCode;
    if (code != null && code.isNotEmpty) {
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .getJson('/c/${widget.targetCode}?pageSize=200');
      final items = ((res['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _options = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  String _displayFor(int id) {
    final row = _options?.firstWhere(
      (r) => (r['id'] is num ? (r['id'] as num).toInt() : int.tryParse(r['id'].toString()) ?? -1) == id,
      orElse: () => const <String, dynamic>{},
    );
    if (row == null || row.isEmpty) return '#$id';
    final name = row['name']?.toString() ??
        row['label']?.toString() ??
        row['title']?.toString();
    return (name != null && name.isNotEmpty) ? '$name (#$id)' : '#$id';
  }

  void _add(int id) {
    setState(() => _selected.add(id));
    widget.onChanged(List<int>.from(_selected));
  }

  void _remove(int id) {
    setState(() => _selected.remove(id));
    widget.onChanged(List<int>.from(_selected));
  }

  int _idOf(Map<String, dynamic> row) {
    final v = row['id'];
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final code = widget.targetCode;
    final theme = Theme.of(context);

    if (code == null || code.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(labelText: widget.label),
        child: Text(t.relationsNoTarget, style: TextStyle(color: theme.disabledColor)),
      );
    }

    final available = (_options ?? const <Map<String, dynamic>>[])
        .where((r) => !_selected.contains(_idOf(r)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(widget.label, style: theme.textTheme.labelLarge),
        ),
        if (_selected.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(t.relationsEmpty, style: TextStyle(color: theme.disabledColor)),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in _selected)
                Chip(
                  label: Text(_displayFor(id)),
                  deleteIcon: widget.readOnly ? null : const Icon(Icons.close, size: 16),
                  onDeleted: widget.readOnly ? null : () => _remove(id),
                ),
            ],
          ),
        const SizedBox(height: 6),
        if (_loading)
          const SizedBox(height: 4, child: LinearProgressIndicator())
        else if (_failed)
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(t.relationsLoadFailed),
          )
        else if (!widget.readOnly)
          PopupMenuButton<int>(
            tooltip: t.relationsAddLabel(code),
            enabled: available.isNotEmpty,
            itemBuilder: (_) => [
              for (final row in available)
                PopupMenuItem<int>(
                  value: _idOf(row),
                  child: Text(_displayFor(_idOf(row))),
                ),
            ],
            onSelected: _add,
            child: OutlinedButton.icon(
              onPressed: available.isEmpty ? null : () {},
              icon: const Icon(Icons.add, size: 16),
              label: Text(t.relationsAddLabel(code)),
            ),
          ),
      ],
    );
  }
}
