// Phase 4.21 (b) — Report editor surface.
//
// The studio gains create/edit/delete on top of the read-only listing
// it had since Phase 2. Includes a structured editor for formula
// columns (the headline feature from Phase 4.21a — until this commit
// they could only be configured by hitting the API directly).
//
// System reports (`isSystem: true`) are partially editable: name /
// description / category / config / formulaColumns can be changed,
// but `builder` is locked and Delete is refused (matches the
// backend's `routes/reports.js` enforcement).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';
import 'report_runner_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).getJson('/reports');
      setState(() {
        _reports = (res['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).loadFailed(e.toString()))),
      );
    }
  }

  void _open(Map<String, dynamic> report) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportRunnerPage(report: report)));
  }

  Future<void> _addReport() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ReportEditorDialog(),
    );
    if (saved == true) await _load();
  }

  Future<void> _editReport(Map<String, dynamic> report) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ReportEditorDialog(report: report),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    if (report['isSystem'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System reports cannot be deleted.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete report?'),
        content: Text('Permanently delete "${report['name']}". This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deleteJson('/reports/${report['id']}');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    if (!auth.can('reports.view')) {
      return Center(child: Text(t.noPermissionReports));
    }
    final canCreate = auth.can('reports.create');
    final canEdit = auth.can('reports.edit');
    final canDelete = auth.can('reports.delete');

    final byCat = <String, List<Map<String, dynamic>>>{};
    for (final r in _reports) {
      final c = r['category']?.toString() ?? 'general';
      byCat.putIfAbsent(c, () => []).add(r);
    }
    final cats = byCat.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.reports,
            subtitle: t.reportsSubtitle,
            actions: [
              if (canCreate)
                FilledButton.icon(
                  onPressed: _addReport,
                  icon: const Icon(Icons.add),
                  label: const Text('New report'),
                ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: LoadingView())
          else if (_reports.isEmpty)
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(t.noReportsDefined)))
          else
            for (final cat in cats) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(cat.toUpperCase(), style: Theme.of(context).textTheme.bodySmall),
              ),
              LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 700 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.4,
                  children: byCat[cat]!.map((r) => _ReportCard(
                    data: r,
                    canEdit: canEdit,
                    canDelete: canDelete,
                    onOpen: () => _open(r),
                    onEdit: () => _editReport(r),
                    onDelete: () => _deleteReport(r),
                  )).toList(),
                );
              }),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.data,
    required this.canEdit,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> data;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSystem = data['isSystem'] == true;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_outlined, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(data['name'].toString(), style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isSystem) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'System report — builder is locked, cannot be deleted',
                          child: Icon(Icons.lock_outline, size: 14, color: cs.outline),
                        ),
                      ],
                    ]),
                    if (data['description'] != null)
                      Text(
                        data['description'].toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (canEdit || canDelete)
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (canEdit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    if (canDelete && !isSystem)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Delete', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                  ],
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportEditorDialog extends ConsumerStatefulWidget {
  const _ReportEditorDialog({this.report});
  final Map<String, dynamic>? report;

  @override
  ConsumerState<_ReportEditorDialog> createState() => _ReportEditorDialogState();
}

class _ReportEditorDialogState extends ConsumerState<_ReportEditorDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _configCtrl;
  String? _builder;
  List<Map<String, dynamic>> _formulaColumns = [];
  List<String> _builders = const [];
  bool _loadingBuilders = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.report != null;
  bool get _isSystem => widget.report?['isSystem'] == true;

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    _codeCtrl = TextEditingController(text: r?['code']?.toString() ?? '');
    _nameCtrl = TextEditingController(text: r?['name']?.toString() ?? '');
    _descCtrl = TextEditingController(text: r?['description']?.toString() ?? '');
    _categoryCtrl = TextEditingController(text: r?['category']?.toString() ?? 'general');
    _builder = r?['builder']?.toString();

    final cfg = (r?['config'] as Map?) ?? const {};
    // Pull formulaColumns out of config so it gets a structured editor;
    // the rest of config goes into the raw JSON textarea. On save we
    // merge the structured list back in.
    final fcRaw = (cfg['formulaColumns'] as List?) ?? const [];
    _formulaColumns = fcRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final cfgWithoutFormulas = Map<String, dynamic>.from(cfg)..remove('formulaColumns');
    _configCtrl = TextEditingController(
      text: cfgWithoutFormulas.isEmpty ? '' : const JsonEncoder.withIndent('  ').convert(cfgWithoutFormulas),
    );

    Future.microtask(_loadBuilders);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _configCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBuilders() async {
    try {
      final res = await ref.read(apiClientProvider).getJson('/reports/builders');
      if (!mounted) return;
      setState(() {
        _builders = ((res['items'] as List?) ?? const []).map((e) => e.toString()).toList();
        // If editing and the builder isn't in the list (legacy report),
        // pin the existing value so the dropdown still shows it.
        if (_isEdit && _builder != null && !_builders.contains(_builder)) {
          _builders = [_builder!, ..._builders];
        }
        _loadingBuilders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBuilders = false;
        _error = 'Failed to load builders: $e';
      });
    }
  }

  Map<String, dynamic>? _parseConfig() {
    final raw = _configCtrl.text.trim();
    if (raw.isEmpty) return {};
    try {
      final parsed = json.decode(raw);
      if (parsed is! Map<String, dynamic>) {
        setState(() => _error = 'Config must be a JSON object');
        return null;
      }
      return parsed;
    } catch (e) {
      setState(() => _error = 'Config JSON parse error: $e');
      return null;
    }
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty || _builder == null) {
      setState(() => _error = 'Code, name, and builder are required.');
      return;
    }
    final config = _parseConfig();
    if (config == null) return;
    if (_formulaColumns.isNotEmpty) {
      config['formulaColumns'] = _formulaColumns;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = {
        'name': name,
        'description': _descCtrl.text.trim(),
        'category': _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        'builder': _builder,
        'config': config,
      };
      if (_isEdit) {
        await ref.read(apiClientProvider).putJson(
          '/reports/${widget.report!['id']}',
          body: body,
        );
      } else {
        body['code'] = code;
        await ref.read(apiClientProvider).postJson('/reports', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _addFormulaColumn() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _FormulaColumnDialog(),
    );
    if (result != null) {
      setState(() => _formulaColumns = [..._formulaColumns, result]);
    }
  }

  Future<void> _editFormulaColumn(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FormulaColumnDialog(initial: _formulaColumns[index]),
    );
    if (result != null) {
      setState(() {
        final next = [..._formulaColumns];
        next[index] = result;
        _formulaColumns = next;
      });
    }
  }

  void _removeFormulaColumn(int index) {
    setState(() {
      final next = [..._formulaColumns];
      next.removeAt(index);
      _formulaColumns = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit report' : 'New report',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl,
                            enabled: !_isEdit,
                            decoration: InputDecoration(
                              labelText: 'Code',
                              helperText: _isEdit ? 'Code is immutable' : 'e.g. sales.by_month',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _categoryCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _loadingBuilders
                              ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                              : DropdownButtonFormField<String>(
                                  initialValue: _builder,
                                  decoration: InputDecoration(
                                    labelText: 'Builder',
                                    border: const OutlineInputBorder(),
                                    helperText: _isSystem ? 'Locked on system reports' : null,
                                  ),
                                  items: _builders
                                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                      .toList(),
                                  onChanged: _isSystem ? null : (v) => setState(() => _builder = v),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionHeading(label: 'Config (raw JSON)', hint: 'Builder-specific params, e.g. {"days": 30}'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _configCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '{}',
                      ),
                      maxLines: 5,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeading(
                      label: 'Formula columns',
                      hint: 'Computed columns appended after the builder runs. Reference other columns by key.',
                    ),
                    const SizedBox(height: 8),
                    if (_formulaColumns.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'No formula columns. Click "Add formula column" to compute values from other columns.',
                          style: TextStyle(color: cs.outline),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < _formulaColumns.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              ListTile(
                                title: Row(children: [
                                  Text(
                                    _formulaColumns[i]['key']?.toString() ?? '?',
                                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formulaColumns[i]['label']?.toString() ?? '',
                                      style: TextStyle(color: cs.outline),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ]),
                                subtitle: Text(
                                  _formulaColumns[i]['formula']?.toString() ?? '',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _editFormulaColumn(i),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove',
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: () => _removeFormulaColumn(i),
                                  ),
                                ]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addFormulaColumn,
                        icon: const Icon(Icons.add),
                        label: const Text('Add formula column'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save' : 'Create'),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, this.hint});
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        if (hint != null)
          Text(hint!, style: TextStyle(fontSize: 12, color: cs.outline)),
      ],
    );
  }
}

class _FormulaColumnDialog extends StatefulWidget {
  const _FormulaColumnDialog({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_FormulaColumnDialog> createState() => _FormulaColumnDialogState();
}

class _FormulaColumnDialogState extends State<_FormulaColumnDialog> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _formulaCtrl;
  bool _numeric = true;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.initial?['key']?.toString() ?? '');
    _labelCtrl = TextEditingController(text: widget.initial?['label']?.toString() ?? '');
    _formulaCtrl = TextEditingController(text: widget.initial?['formula']?.toString() ?? '');
    // numeric defaults to true (matches the backend default).
    _numeric = widget.initial?['numeric'] != false;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _labelCtrl.dispose();
    _formulaCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final key = _keyCtrl.text.trim();
    final label = _labelCtrl.text.trim();
    final formula = _formulaCtrl.text.trim();
    if (key.isEmpty || label.isEmpty || formula.isEmpty) {
      setState(() => _error = 'Key, label, and formula are required.');
      return;
    }
    // Match the server validator's identifier rule (a-z A-Z 0-9 _ ;
    // first char a letter or underscore). Keeps formula refs valid.
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
      setState(() => _error = 'Key must be a simple identifier (letters / digits / underscore, no spaces).');
      return;
    }
    Navigator.pop(context, {
      'key': key,
      'label': label,
      'formula': formula,
      'numeric': _numeric,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit formula column' : 'Add formula column'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _keyCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Key',
                helperText: 'Column key — used in formulas. e.g. ratio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label',
                helperText: 'Display label shown in the table header',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _formulaCtrl,
              decoration: const InputDecoration(
                labelText: 'Formula',
                helperText: 'e.g. users / branches  or  qty * price',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _numeric,
              onChanged: (v) => setState(() => _numeric = v),
              title: const Text('Numeric'),
              subtitle: const Text('Right-aligned in the table; chart-eligible'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(_isEdit ? 'Save' : 'Add')),
      ],
    );
  }
}
