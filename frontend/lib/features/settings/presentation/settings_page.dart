import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loading = true;
  bool _saving = false;
  List<_Setting> _settings = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getJson('/settings');
      setState(() {
        _settings = (res['items'] as List).map((e) {
          final m = e as Map<String, dynamic>;
          return _Setting(
            id: m['id'] as int?,
            key: m['key'].toString(),
            value: m['value']?.toString() ?? '',
            type: m['type']?.toString() ?? 'string',
            isPublic: (m['isPublic'] as bool?) ?? false,
          );
        }).toList();
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

  Future<void> _save() async {
    setState(() => _saving = true);
    final t = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).putJson('/settings', body: {
        'companyId': null,
        'items': _settings.map((s) => s.toJson()).toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settingsSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.saveFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addRow() {
    setState(() => _settings.add(_Setting(key: '', value: '', type: 'string', isPublic: false)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    final canEdit = auth.can('settings.manage_settings');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.settings,
            subtitle: t.settingsSubtitle,
            actions: [
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: Text(t.addRow),
                ),
              const SizedBox(width: 8),
              if (canEdit)
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? t.saving : t.save),
                ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: LoadingView())
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (var i = 0; i < _settings.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              initialValue: _settings[i].key,
                              decoration: InputDecoration(labelText: t.keyField),
                              enabled: canEdit,
                              onChanged: (v) => _settings[i].key = v,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              initialValue: _settings[i].value,
                              decoration: InputDecoration(labelText: t.valueField),
                              enabled: canEdit,
                              onChanged: (v) => _settings[i].value = v,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _settings[i].type,
                              decoration: InputDecoration(labelText: t.typeField),
                              items: const [
                                DropdownMenuItem(value: 'string', child: Text('string')),
                                DropdownMenuItem(value: 'number', child: Text('number')),
                                DropdownMenuItem(value: 'bool', child: Text('bool')),
                                DropdownMenuItem(value: 'json', child: Text('json')),
                              ],
                              onChanged: canEdit ? (v) => setState(() => _settings[i].type = v ?? 'string') : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              Text(t.publicLabel),
                              Switch(
                                value: _settings[i].isPublic,
                                onChanged: canEdit ? (v) => setState(() => _settings[i].isPublic = v) : null,
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: t.remove,
                            onPressed: canEdit ? () => setState(() => _settings.removeAt(i)) : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const Divider(),
                    ],
                    if (_settings.isEmpty) Padding(padding: const EdgeInsets.all(28), child: Text(t.noSettingsYet)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Setting {
  _Setting({this.id, required this.key, required this.value, required this.type, required this.isPublic});
  final int? id;
  String key;
  String value;
  String type;
  bool isPublic;

  Map<String, dynamic> toJson() => {'key': key, 'value': value, 'type': type, 'isPublic': isPublic};
}
