import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../menus/menu_controller.dart';
import 'custom_entity_form.dart';

class CustomEntitiesPage extends ConsumerStatefulWidget {
  const CustomEntitiesPage({super.key});

  @override
  ConsumerState<CustomEntitiesPage> createState() => _CustomEntitiesPageState();
}

class _CustomEntitiesPageState extends ConsumerState<CustomEntitiesPage> {
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
      final res = await ref.read(apiClientProvider).getJson('/custom-entities');
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

  Future<void> _open({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomEntityForm(existing: existing),
    );
    if (saved == true) {
      _load();
      ref.read(menuControllerProvider.notifier).load();
    }
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final t = AppLocalizations.of(context);
    final dropTable = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteEntityTitle(e['label'].toString())),
        content: Text(t.deleteEntityBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(t.cancel)),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'keep'), child: Text(t.unregisterOnly)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, 'drop'),
            child: Text(t.dropTable),
          ),
        ],
      ),
    );
    if (dropTable == null || dropTable.isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .deleteJson('/custom-entities/${e['code']}?dropTable=${dropTable == 'drop'}');
      _load();
      ref.read(menuControllerProvider.notifier).load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deleteFailedMsg(err.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    if (!auth.user!.isSuperAdmin) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text(t.customEntitiesAdminRestricted)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.customEntities,
            subtitle: t.customEntitiesSubtitle,
            actions: [
              ElevatedButton.icon(
                onPressed: () => _open(),
                icon: const Icon(Icons.add),
                label: Text(t.newEntity),
              ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: LoadingView())
          else if (_items.isEmpty)
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(t.noCustomEntitiesYet)))
          else
            Card(
              child: Column(
                children: [
                  for (final e in _items) ...[
                    ListTile(
                      leading: const Icon(Icons.dataset_outlined),
                      title: Text('${e['label']} (${e['code']})'),
                      subtitle: Text(
                        '${t.tableLabel(e['tableName'].toString())} • ${t.categoryField}: ${e['category']} • '
                        '${t.columnsCount((e['config']?['columns'] as List? ?? []).length)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (e['isSystem'] == true) Chip(label: Text(t.systemChip)),
                          IconButton(onPressed: () => _open(existing: e), icon: const Icon(Icons.edit_outlined, size: 18)),
                          if (e['isSystem'] != true)
                            IconButton(onPressed: () => _delete(e), icon: const Icon(Icons.delete_outline, size: 18)),
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
}
