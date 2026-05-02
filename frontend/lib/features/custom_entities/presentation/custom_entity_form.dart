import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';

class _Column {
  _Column({
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.unique = false,
    this.searchable = false,
    this.showInList = true,
    this.defaultValue,
    this.targetEntity,
    this.formula,
    this.viewPermission,
    this.editPermission,
  });

  String name;
  String label;
  String type;
  bool required;
  bool unique;
  bool searchable;
  bool showInList;
  String? defaultValue;
  // Phase 4.15 — set on `relation` (single-FK) and `relations`
  // (many-to-many) columns. Stores the code of the entity being
  // referenced.
  String? targetEntity;
  // Phase 4.16 — set on `formula` columns. Expression in the safe
  // formula language (see backend/src/lib/formula.js).
  String? formula;
  // Phase 4.16 — field-level permissions. Optional permission codes
  // that gate per-column view/edit. Super-admin always bypasses.
  String? viewPermission;
  String? editPermission;

  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'type': type,
        'required': required,
        'unique': unique,
        'searchable': searchable,
        'showInList': showInList,
        if (defaultValue != null && defaultValue!.isNotEmpty) 'defaultValue': defaultValue,
        if (targetEntity != null && targetEntity!.isNotEmpty) 'targetEntity': targetEntity,
        if (formula != null && formula!.isNotEmpty) 'formula': formula,
        if (viewPermission != null && viewPermission!.isNotEmpty) 'viewPermission': viewPermission,
        if (editPermission != null && editPermission!.isNotEmpty) 'editPermission': editPermission,
      };

  factory _Column.fromJson(Map<String, dynamic> j) => _Column(
        name: j['name']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        type: j['type']?.toString() ?? 'text',
        required: j['required'] == true,
        unique: j['unique'] == true,
        searchable: j['searchable'] == true,
        showInList: j['showInList'] != false,
        defaultValue: j['defaultValue']?.toString(),
        targetEntity: j['targetEntity']?.toString(),
        formula: j['formula']?.toString(),
        viewPermission: j['viewPermission']?.toString(),
        editPermission: j['editPermission']?.toString(),
      );
}

const _types = ['text', 'longtext', 'integer', 'number', 'bool', 'date', 'datetime', 'relation', 'relations', 'formula'];

class CustomEntityForm extends ConsumerStatefulWidget {
  const CustomEntityForm({super.key, this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<CustomEntityForm> createState() => _CustomEntityFormState();
}

class _CustomEntityFormState extends ConsumerState<CustomEntityForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _tableName;
  late final TextEditingController _label;
  late final TextEditingController _singular;
  late final TextEditingController _category;
  late final TextEditingController _icon;
  bool _saving = false;

  List<_Column> _cols = [];
  bool _isEdit = false;
  bool _isSystem = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _isEdit = e != null;
    _isSystem = e?['isSystem'] == true;
    _code = TextEditingController(text: e?['code']?.toString() ?? '');
    _tableName = TextEditingController(text: e?['tableName']?.toString() ?? '');
    _label = TextEditingController(text: e?['label']?.toString() ?? '');
    _singular = TextEditingController(text: e?['singular']?.toString() ?? '');
    _category = TextEditingController(text: e?['category']?.toString() ?? 'custom');
    _icon = TextEditingController(text: e?['icon']?.toString() ?? 'reports');

    if (e != null) {
      final cols = (e['config']?['columns'] as List? ?? const []);
      _cols = cols.map((c) => _Column.fromJson(c as Map<String, dynamic>)).toList();
    } else {
      _cols = [
        _Column(name: 'name', label: 'Name', type: 'text', required: true, searchable: true),
      ];
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _tableName.dispose();
    _label.dispose();
    _singular.dispose();
    _category.dispose();
    _icon.dispose();
    super.dispose();
  }

  void _onCodeChanged(String v) {
    if (_isEdit) return;
    if (_tableName.text.isEmpty) _tableName.text = v;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final t = AppLocalizations.of(context);
    if (_cols.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.addAtLeastOneColumn)));
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = {
        'code': _code.text.trim(),
        'tableName': _tableName.text.trim(),
        'label': _label.text.trim(),
        'singular': _singular.text.trim().isEmpty ? _label.text.trim() : _singular.text.trim(),
        'icon': _icon.text.trim(),
        'category': _category.text.trim(),
        'columns': _cols.map((c) => c.toJson()).toList(),
      };
      if (_isEdit) {
        await api.putJson('/custom-entities/${_code.text.trim()}', body: body);
      } else {
        await api.postJson('/custom-entities', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.saveFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(_isEdit ? t.editEntity : t.newEntity, style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _code,
                              decoration: InputDecoration(labelText: t.codeUsedInUrl),
                              validator: (v) => (v == null || !RegExp(r'^[a-z][a-z0-9_]{0,62}$').hasMatch(v)) ? 'lowercase, digits, underscore' : null,
                              enabled: !_isEdit,
                              onChanged: _onCodeChanged,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _tableName,
                              decoration: InputDecoration(labelText: t.sqlTableName),
                              validator: (v) => (v == null || !RegExp(r'^[a-z][a-z0-9_]{0,62}$').hasMatch(v)) ? 'lowercase, digits, underscore' : null,
                              enabled: !_isEdit,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _label,
                              decoration: InputDecoration(labelText: t.displayLabelPlural),
                              validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _singular,
                              decoration: InputDecoration(labelText: t.singularName),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _category,
                              decoration: InputDecoration(labelText: t.categoryField),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _icon,
                              decoration: InputDecoration(labelText: t.iconNameField, hintText: t.iconNameHint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(t.columnsLabel, style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _isSystem
                                ? null
                                : () => setState(() => _cols.add(_Column(name: 'field${_cols.length + 1}', label: 'Field ${_cols.length + 1}', type: 'text'))),
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(t.addColumn),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isSystem)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(t.systemEntitiesAlterWarn),
                        ),
                      const SizedBox(height: 8),
                      ...List.generate(_cols.length, (i) => _ColumnRow(
                        column: _cols[i],
                        labels: t,
                        onChanged: () => setState(() {}),
                        onRemove: _isSystem ? null : () => setState(() => _cols.removeAt(i)),
                      )),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                    child: Text(t.cancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? t.saving : (_isEdit ? t.updateLabel : t.create)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnRow extends StatelessWidget {
  const _ColumnRow({required this.column, required this.labels, required this.onChanged, this.onRemove});
  final _Column column;
  final AppLocalizations labels;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: column.name,
                  decoration: InputDecoration(labelText: labels.fieldNameSnakeCase),
                  onChanged: (v) {
                    column.name = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: column.label,
                  decoration: InputDecoration(labelText: labels.labelField),
                  onChanged: (v) {
                    column.label = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: column.type,
                  decoration: InputDecoration(labelText: labels.typeField),
                  items: _types.map((tp) => DropdownMenuItem(value: tp, child: Text(tp))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      column.type = v;
                      onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: column.defaultValue,
                  decoration: InputDecoration(labelText: labels.defaultLabel),
                  onChanged: (v) {
                    column.defaultValue = v;
                    onChanged();
                  },
                ),
              ),
              if (onRemove != null)
                IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline, size: 18)),
            ],
          ),
          if (column.type == 'relation' || column.type == 'relations') ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: column.targetEntity,
              decoration: InputDecoration(
                labelText: labels.targetEntityLabel,
                hintText: 'products',
              ),
              onChanged: (v) {
                column.targetEntity = v.trim();
                onChanged();
              },
            ),
          ],
          if (column.type == 'formula') ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: column.formula,
              decoration: InputDecoration(
                labelText: labels.formulaLabel,
                hintText: 'qty * price',
                helperText: labels.formulaHelp,
              ),
              style: const TextStyle(fontFamily: 'monospace'),
              onChanged: (v) {
                column.formula = v.trim();
                onChanged();
              },
            ),
          ],
          // Phase 4.16 — field-level permissions. Optional permission
          // codes that gate per-column view/edit at the engine layer.
          // Leave blank to inherit the entity's standard permissions.
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: column.viewPermission,
                  decoration: InputDecoration(
                    labelText: labels.viewPermissionLabel,
                    hintText: 'finance.read',
                    helperText: labels.fieldPermissionHelp,
                  ),
                  onChanged: (v) {
                    column.viewPermission = v.trim();
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: column.editPermission,
                  decoration: InputDecoration(
                    labelText: labels.editPermissionLabel,
                    hintText: 'finance.write',
                  ),
                  onChanged: (v) {
                    column.editPermission = v.trim();
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              FilterChip(
                label: Text(labels.requiredLabel),
                selected: column.required,
                onSelected: (v) {
                  column.required = v;
                  onChanged();
                },
              ),
              FilterChip(
                label: Text(labels.uniqueLabel),
                selected: column.unique,
                onSelected: (v) {
                  column.unique = v;
                  onChanged();
                },
              ),
              FilterChip(
                label: Text(labels.searchableLabel),
                selected: column.searchable,
                onSelected: (v) {
                  column.searchable = v;
                  onChanged();
                },
              ),
              FilterChip(
                label: Text(labels.showInList),
                selected: column.showInList,
                onSelected: (v) {
                  column.showInList = v;
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
