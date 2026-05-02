import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../menus/menu_controller.dart';
import '../../setup/setup_controller.dart';

class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).getJson('/templates');
      setState(() {
        _items = (res['items'] as List).cast<Map<String, dynamic>>();
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

  Future<void> _capture() async {
    final t = AppLocalizations.of(context);
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String kind = 'full';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: Text(t.saveCurrentSetup),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code (e.g. retail_v1)')),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'What to capture'),
                  items: const [
                    DropdownMenuItem(value: 'full', child: Text('Full — theme + tables')),
                    DropdownMenuItem(value: 'theme', child: Text('Theme only')),
                    DropdownMenuItem(value: 'business', child: Text('Business — custom tables only')),
                  ],
                  onChanged: (v) => setSt(() => kind = v ?? 'full'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
          ],
        );
      }),
    );
    if (ok != true) return;
    if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).postJson('/templates/capture', body: {
        'code': codeCtrl.text.trim(),
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'kind': kind,
      });
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.templateSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.saveFailed(e.toString()))));
    }
  }

  Future<void> _apply(Map<String, dynamic> tmpl) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.applyTemplateTitle(tmpl['name'].toString())),
        content: Text(t.applyTemplateBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(t.applyAction)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).postJson('/templates/${tmpl['id']}/apply');
      await ref.read(themeControllerProvider.notifier).loadActive();
      await ref.read(menuControllerProvider.notifier).load();
      await ref.read(setupControllerProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.templateApplied)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.applyFailed(e.toString()))));
    }
  }

  Future<void> _exportToClipboard(Map<String, dynamic> tmpl) async {
    final t = AppLocalizations.of(context);
    try {
      final full = await ref.read(apiClientProvider).getJson('/templates/${tmpl['id']}');
      await Clipboard.setData(ClipboardData(text: jsonEncode(full['data'])));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.copiedJsonToClipboard)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.exportFailed(e.toString()))));
    }
  }

  Future<void> _import() async {
    final t = AppLocalizations.of(context);
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final dataCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.importTemplateTitle),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code')),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(
                controller: dataCtrl,
                decoration: const InputDecoration(labelText: 'JSON data', hintText: 'paste exported JSON'),
                minLines: 5,
                maxLines: 15,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(t.importLabel)),
        ],
      ),
    );
    if (ok != true) return;
    Object? parsed;
    try {
      parsed = jsonDecode(dataCtrl.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.invalidJson(e.toString()))));
      return;
    }
    try {
      await ref.read(apiClientProvider).postJson('/templates/import', body: {
        'code': codeCtrl.text.trim(),
        'name': nameCtrl.text.trim(),
        'data': parsed,
      });
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.templateImported)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.importFailed(e.toString()))));
    }
  }

  Future<void> _editSubsystem(Map<String, dynamic> tmpl) async {
    final t = AppLocalizations.of(context);
    Map<String, dynamic> full;
    try {
      full = await ref.read(apiClientProvider).getJson('/templates/${tmpl['id']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.loadFailed(e.toString()))));
      return;
    }
    if (!mounted) return;

    final data = (full['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final brandingMap = (data['branding'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final modulesList = ((data['modules'] as List?) ?? const [])
        .map((m) => m.toString())
        .toList();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SubsystemEditorDialog(
        templateName: tmpl['name'].toString(),
        initialBranding: Map<String, dynamic>.from(brandingMap),
        initialModules: List<String>.from(modulesList),
      ),
    );
    if (result == null) return;

    try {
      await ref.read(apiClientProvider).putJson('/templates/${tmpl['id']}/subsystem', body: result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.subsystemSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.saveFailed(e.toString()))));
    }
  }

  Future<void> _delete(Map<String, dynamic> tmpl) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteTemplateTitle),
        content: Text(t.deleteConfirm(tmpl['name'].toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deleteJson('/templates/${tmpl['id']}');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deleteFailedMsg(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    if (!auth.user!.isSuperAdmin) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text(t.templatesRestricted)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.templates,
            subtitle: t.templatesSubtitle,
            actions: [
              OutlinedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: Text(t.importJson),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _capture,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: Text(t.saveCurrent),
              ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: LoadingView())
          else if (_items.isEmpty)
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(t.noTemplatesYet)))
          else
            Card(
              child: Column(
                children: [
                  for (final tmpl in _items) ...[
                    ListTile(
                      leading: Icon(_iconForKind(tmpl['kind']?.toString())),
                      title: Text(tmpl['name'].toString()),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${tmpl['code']} • ${tmpl['kind'] ?? 'full'}${tmpl['description'] != null && (tmpl['description'] as String).isNotEmpty ? ' • ${tmpl['description']}' : ''}'),
                          _SubsystemSummaryRow(summary: (tmpl['subsystem'] as Map?)?.cast<String, dynamic>()),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(tooltip: t.applyAction, icon: const Icon(Icons.bolt_outlined, size: 18), onPressed: () => _apply(tmpl)),
                          if (tmpl['kind'] == 'full' || tmpl['kind'] == 'business')
                            IconButton(
                              tooltip: t.editSubsystemTooltip,
                              icon: const Icon(Icons.tune_outlined, size: 18),
                              onPressed: () => _editSubsystem(tmpl),
                            ),
                          IconButton(tooltip: t.copyJson, icon: const Icon(Icons.copy_outlined, size: 18), onPressed: () => _exportToClipboard(tmpl)),
                          IconButton(tooltip: t.delete, icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _delete(tmpl)),
                        ],
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

  IconData _iconForKind(String? k) {
    switch (k) {
      case 'theme':
        return Icons.palette_outlined;
      case 'business':
        return Icons.dataset_outlined;
      default:
        return Icons.layers_outlined;
    }
  }
}

class _SubsystemEditorDialog extends StatefulWidget {
  final String templateName;
  final Map<String, dynamic> initialBranding;
  final List<String> initialModules;

  const _SubsystemEditorDialog({
    required this.templateName,
    required this.initialBranding,
    required this.initialModules,
  });

  @override
  State<_SubsystemEditorDialog> createState() => _SubsystemEditorDialogState();
}

class _SubsystemEditorDialogState extends State<_SubsystemEditorDialog> {
  late final TextEditingController _appName;
  late final TextEditingController _logoUrl;
  late final TextEditingController _primaryColor;
  late final TextEditingController _iconPath;
  late final List<String> _modules;
  final TextEditingController _moduleAdd = TextEditingController();

  @override
  void initState() {
    super.initState();
    _appName = TextEditingController(text: widget.initialBranding['appName']?.toString() ?? '');
    _logoUrl = TextEditingController(text: widget.initialBranding['logoUrl']?.toString() ?? '');
    _primaryColor = TextEditingController(text: widget.initialBranding['primaryColor']?.toString() ?? '');
    _iconPath = TextEditingController(text: widget.initialBranding['iconPath']?.toString() ?? '');
    _modules = List<String>.from(widget.initialModules);
  }

  @override
  void dispose() {
    _appName.dispose();
    _logoUrl.dispose();
    _primaryColor.dispose();
    _iconPath.dispose();
    _moduleAdd.dispose();
    super.dispose();
  }

  void _addModule() {
    final v = _moduleAdd.text.trim();
    if (v.isEmpty || _modules.contains(v)) {
      _moduleAdd.clear();
      return;
    }
    setState(() {
      _modules.add(v);
      _moduleAdd.clear();
    });
  }

  void _save() {
    Navigator.pop<Map<String, dynamic>>(context, {
      'branding': {
        'appName': _appName.text.trim(),
        'logoUrl': _logoUrl.text.trim(),
        'primaryColor': _primaryColor.text.trim(),
        'iconPath': _iconPath.text.trim(),
      },
      'modules': _modules,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(t.editSubsystemTitle(widget.templateName)),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.brandingSection, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(controller: _appName, decoration: InputDecoration(labelText: t.appNameLabel)),
              const SizedBox(height: 8),
              TextField(controller: _logoUrl, decoration: InputDecoration(labelText: t.logoUrlLabel)),
              const SizedBox(height: 8),
              TextField(
                controller: _primaryColor,
                decoration: InputDecoration(labelText: t.primaryColorLabel, hintText: '#1f6feb'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _iconPath,
                decoration: InputDecoration(labelText: t.iconPathLabel, hintText: r'C:\path\to\icon.ico'),
              ),
              const SizedBox(height: 24),
              Text(t.modulesSection, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(t.modulesHelp, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              if (_modules.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in _modules)
                      Chip(
                        label: Text(m),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _modules.remove(m)),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _moduleAdd,
                      decoration: InputDecoration(
                        labelText: t.addModuleLabel,
                        hintText: 'custom:products',
                      ),
                      onSubmitted: (_) => _addModule(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.add), onPressed: _addModule),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        ElevatedButton(onPressed: _save, child: Text(t.save)),
      ],
    );
  }
}

// Phase 4.15 follow-up — at-a-glance subsystem summary on the templates
// list. Reads the `subsystem` block returned by GET /templates (added
// in the same follow-up): `{hasBranding, moduleCount, brandingKeys?,
// modules?, appName?}`. Renders as compact badges below the existing
// subtitle row. Returns `SizedBox.shrink()` when there's nothing to
// show, so theme/pages/reports/queries-only templates stay tidy.
class _SubsystemSummaryRow extends StatelessWidget {
  const _SubsystemSummaryRow({required this.summary});
  final Map<String, dynamic>? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) return const SizedBox.shrink();
    final hasBranding = s['hasBranding'] == true;
    final moduleCount = (s['moduleCount'] is num) ? (s['moduleCount'] as num).toInt() : 0;
    if (!hasBranding && moduleCount == 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];

    if (hasBranding) {
      final appName = s['appName']?.toString();
      children.add(_Badge(
        icon: Icons.palette_outlined,
        label: appName != null && appName.isNotEmpty ? appName : 'branded',
        color: cs.primary,
      ));
    }
    if (moduleCount > 0) {
      children.add(_Badge(
        icon: Icons.extension_outlined,
        label: '$moduleCount modules',
        color: cs.tertiary,
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 6, runSpacing: 4, children: children),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
