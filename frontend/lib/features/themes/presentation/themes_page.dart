import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';

class ThemesPage extends ConsumerStatefulWidget {
  const ThemesPage({super.key});

  @override
  ConsumerState<ThemesPage> createState() => _ThemesPageState();
}

class _ThemesPageState extends ConsumerState<ThemesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getJson('/themes');
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

  Future<void> _create() async {
    final api = ref.read(apiClientProvider);
    final t = AppLocalizations.of(context);
    final name = await _askName(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      final res = await api.postJson('/themes', body: {
        'name': name.trim(),
        'data': const {},
        'isActive': false,
      });
      if (!mounted) return;
      context.go('/themes/edit/${res['id']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.createFailed(e.toString()))));
    }
  }

  Future<String?> _askName(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.newItem),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: t.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: Text(t.create)),
        ],
      ),
    );
  }

  Future<void> _activate(Map<String, dynamic> theme) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).postJson('/themes/${theme['id']}/activate');
      await ref.read(themeControllerProvider.notifier).loadActive();
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.activate}: $e')));
    }
  }

  Future<void> _duplicate(Map<String, dynamic> theme) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).postJson('/themes/${theme['id']}/duplicate');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.duplicate}: $e')));
    }
  }

  Future<void> _reset(Map<String, dynamic> theme) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).postJson('/themes/${theme['id']}/reset');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.resetLabel}: $e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> theme) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.delete),
        content: Text(t.deleteConfirm(theme['name'].toString())),
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
      await ref.read(apiClientProvider).deleteJson('/themes/${theme['id']}');
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
        child: Center(child: Text(t.themeBuilderRestricted)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.appearance,
            subtitle: t.themeBuilderTitle,
            actions: [
              ElevatedButton.icon(
                onPressed: _create,
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
                childAspectRatio: 1.3,
                children: _items.map((theme) => _ThemeCard(
                  data: theme,
                  labels: t,
                  onEdit: () => context.go('/themes/edit/${theme['id']}'),
                  onActivate: () => _activate(theme),
                  onDuplicate: () => _duplicate(theme),
                  onReset: () => _reset(theme),
                  onDelete: () => _delete(theme),
                )).toList(),
              );
            }),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.data,
    required this.labels,
    required this.onEdit,
    required this.onActivate,
    required this.onDuplicate,
    required this.onReset,
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final AppLocalizations labels;
  final VoidCallback onEdit;
  final VoidCallback onActivate;
  final VoidCallback onDuplicate;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  Color _hex(String? h) {
    if (h == null) return const Color(0xFF1F6FEB);
    var v = h.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return Color(int.tryParse(v, radix: 16) ?? 0xFF1F6FEB);
  }

  @override
  Widget build(BuildContext context) {
    final d = (data['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isActive = data['isActive'] == true;
    final isDefault = data['isDefault'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(data['name'].toString(), style: Theme.of(context).textTheme.titleMedium)),
                if (isActive) Chip(label: Text(labels.active)),
                if (isDefault) Padding(padding: const EdgeInsets.only(left: 6), child: Chip(label: Text(labels.defaultLabel))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Swatch(label: 'Primary', color: _hex(d['primary'] as String?)),
                _Swatch(label: 'Secondary', color: _hex(d['secondary'] as String?)),
                _Swatch(label: 'Accent', color: _hex(d['accent'] as String?)),
                _Swatch(label: 'Sidebar', color: _hex(d['sidebar'] as String?)),
                _Swatch(label: 'Bg', color: _hex(d['background'] as String?)),
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(onPressed: onEdit, icon: const Icon(Icons.tune, size: 16), label: Text(labels.edit)),
                if (!isActive)
                  OutlinedButton.icon(onPressed: onActivate, icon: const Icon(Icons.bolt, size: 16), label: Text(labels.activate)),
                OutlinedButton.icon(onPressed: onDuplicate, icon: const Icon(Icons.copy, size: 16), label: Text(labels.duplicate)),
                OutlinedButton.icon(onPressed: onReset, icon: const Icon(Icons.restore, size: 16), label: Text(labels.resetLabel)),
                if (!isDefault)
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
