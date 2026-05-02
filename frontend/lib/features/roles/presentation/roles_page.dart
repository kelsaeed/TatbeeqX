import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';
import 'role_editor_dialog.dart';

class RolesPage extends ConsumerStatefulWidget {
  const RolesPage({super.key});

  @override
  ConsumerState<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends ConsumerState<RolesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final r = await api.getJson('/roles');
      setState(() {
        _roles = (r['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.loadFailed(e.toString()))));
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => RoleEditorDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> role) async {
    if (role['isSystem'] == true) return;
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.delete),
        content: Text(t.deleteConfirm(role['name'].toString())),
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
      await ref.read(apiClientProvider).deleteJson('/roles/${role['id']}');
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
    final localeCode = ref.watch(localeControllerProvider).languageCode;
    final canCreate = auth.can('roles.create');
    final canEdit = auth.can('roles.edit');
    final canDelete = auth.can('roles.delete');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.roles,
            subtitle: t.rolesSubtitle,
            actions: [
              if (canCreate)
                ElevatedButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: Text(t.newItem),
                ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: LoadingView())
          else
            LayoutBuilder(builder: (ctx, c) {
              final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 700 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
                children: _roles.map((r) => _RoleCard(
                  role: r,
                  localeCode: localeCode,
                  systemChipLabel: t.systemChip,
                  permissionsCountFn: t.permissionsCount,
                  usersCountFn: t.usersCount,
                  canEdit: canEdit,
                  canDelete: canDelete,
                  onEdit: () => _openEditor(existing: r),
                  onDelete: () => _delete(r),
                )).toList(),
              );
            }),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.systemChipLabel,
    required this.permissionsCountFn,
    required this.usersCountFn,
    this.localeCode = 'en',
  });

  final Map<String, dynamic> role;
  final String localeCode;
  final String systemChipLabel;
  final String Function(int) permissionsCountFn;
  final String Function(int) usersCountFn;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _resolvedName() {
    final labels = role['labels'];
    if (labels is Map) {
      final v = labels[localeCode];
      if (v is String && v.isNotEmpty) return v;
    }
    return role['name']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final permsCount = (role['permissionIds'] as List? ?? const []).length;
    final users = role['userCount'] ?? 0;
    final isSystem = role['isSystem'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shield_outlined, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_resolvedName(), style: Theme.of(context).textTheme.titleMedium),
                      Text(role['code'].toString(), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (isSystem)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Chip(label: Text(systemChipLabel)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (role['description'] != null)
              Text(
                role['description'].toString(),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: cs.outline),
                const SizedBox(width: 4),
                Text(permissionsCountFn(permsCount)),
                const SizedBox(width: 16),
                Icon(Icons.people_outline, size: 16, color: cs.outline),
                const SizedBox(width: 4),
                Text(usersCountFn(users is int ? users : (users as num).toInt())),
                const Spacer(),
                if (canEdit)
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
                if (canDelete && !isSystem)
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
