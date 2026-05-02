import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';
import 'company_form_dialog.dart';

class CompaniesPage extends ConsumerStatefulWidget {
  const CompaniesPage({super.key});

  @override
  ConsumerState<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends ConsumerState<CompaniesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getJson('/companies');
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
      builder: (_) => CompanyFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteCompany),
        content: Text(t.deleteCascadeWarn(r['name'].toString())),
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
      await ref.read(apiClientProvider).deleteJson('/companies/${r['id']}');
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.companies,
            subtitle: t.companiesSubtitle,
            actions: [
              if (auth.can('companies.create'))
                ElevatedButton.icon(
                  onPressed: () => _open(),
                  icon: const Icon(Icons.add),
                  label: Text(t.newCompany),
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
                childAspectRatio: 1.7,
                children: _items.map((c) => _CompanyCard(
                  data: c,
                  canEdit: auth.can('companies.edit'),
                  canDelete: auth.can('companies.delete'),
                  codeColonFn: t.codeColon,
                  branchesCountFn: t.branchesCount,
                  usersCountFn: t.usersCount,
                  onEdit: () => _open(existing: c),
                  onDelete: () => _delete(c),
                )).toList(),
              );
            }),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.data,
    required this.canEdit,
    required this.canDelete,
    required this.codeColonFn,
    required this.branchesCountFn,
    required this.usersCountFn,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> data;
  final bool canEdit;
  final bool canDelete;
  final String Function(String) codeColonFn;
  final String Function(int) branchesCountFn;
  final String Function(int) usersCountFn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = data['_count'] as Map<String, dynamic>? ?? const {};
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
                  child: Icon(Icons.business_outlined, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'].toString(), style: Theme.of(context).textTheme.titleMedium),
                      Text(codeColonFn(data['code'].toString()), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: data['isActive'] == true ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data['address'] != null)
              Row(children: [
                Icon(Icons.location_on_outlined, size: 14, color: cs.outline),
                const SizedBox(width: 4),
                Expanded(child: Text(data['address'].toString(), style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
              ]),
            if (data['email'] != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.mail_outline, size: 14, color: cs.outline),
                const SizedBox(width: 4),
                Expanded(child: Text(data['email'].toString(), style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const Spacer(),
            Row(
              children: [
                Icon(Icons.store_outlined, size: 16, color: cs.outline),
                const SizedBox(width: 4),
                Text(branchesCountFn((counts['branches'] as num?)?.toInt() ?? 0)),
                const SizedBox(width: 16),
                Icon(Icons.people_outline, size: 16, color: cs.outline),
                const SizedBox(width: 4),
                Text(usersCountFn((counts['users'] as num?)?.toInt() ?? 0)),
                const Spacer(),
                if (canEdit)
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
                if (canDelete)
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
