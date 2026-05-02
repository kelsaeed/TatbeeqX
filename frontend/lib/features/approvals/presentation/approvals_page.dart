import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/paginated_search_table.dart';

class ApprovalsPage extends ConsumerStatefulWidget {
  const ApprovalsPage({super.key});

  @override
  ConsumerState<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends ConsumerState<ApprovalsPage> {
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final t = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.approvals,
            subtitle: t.approvalsSubtitle,
            actions: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add),
                label: Text(t.newRequest),
                onPressed: _newRequest,
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: InputDecoration(labelText: t.statusLabel),
                  items: [
                    DropdownMenuItem(value: 'pending', child: Text(t.statusPending)),
                    DropdownMenuItem(value: 'approved', child: Text(t.statusApproved)),
                    DropdownMenuItem(value: 'rejected', child: Text(t.statusRejected)),
                    DropdownMenuItem(value: 'cancelled', child: Text(t.statusCancelled)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'pending'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PaginatedSearchTable<Map<String, dynamic>>(
            key: ValueKey(_status),
            searchable: false,
            fetch: ({required page, required pageSize, required search}) async {
              final res = await api.getJson('/approvals', query: {
                'page': page,
                'pageSize': pageSize,
                'status': _status,
              });
              final items = (res['items'] as List).cast<Map<String, dynamic>>();
              return (items: items, total: (res['total'] as int?) ?? items.length);
            },
            columns: [
              TableColumn(label: t.auditWhen, flex: 2, cell: (r) {
                final iso = r['createdAt'] as String?;
                final d = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
                return Text(d == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(d));
              }),
              TableColumn(label: t.auditEntity, flex: 1, cell: (r) => Text(r['entity']?.toString() ?? '')),
              TableColumn(label: t.approvalsTitleColumn, flex: 3, cell: (r) => Text(r['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)),
              TableColumn(label: t.approvalsRequestedBy, flex: 2, cell: (r) {
                final u = r['requestedBy'] as Map<String, dynamic>?;
                return Text(u?['fullName']?.toString() ?? u?['username']?.toString() ?? '');
              }),
              TableColumn(label: t.statusLabel, flex: 1, cell: (r) => _statusChip(r['status']?.toString() ?? '')),
              TableColumn(label: '', flex: 2, cell: (r) {
                if (r['status'] != 'pending') return const SizedBox.shrink();
                return Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(t.approveLabel),
                      onPressed: () => _decide(r['id'] as int, 'approve'),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(t.rejectLabel),
                      onPressed: () => _decide(r['id'] as int, 'reject'),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color c;
    switch (status) {
      case 'approved': c = Colors.green; break;
      case 'rejected': c = Colors.red; break;
      case 'cancelled': c = Colors.grey; break;
      default: c = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Future<void> _decide(int id, String action) async {
    final t = AppLocalizations.of(context);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approve' ? t.approveTitle : t.rejectTitle),
        content: TextField(
          controller: note,
          decoration: InputDecoration(labelText: t.noteOptional),
          minLines: 1,
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action == 'approve' ? t.approveLabel : t.rejectLabel)),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(apiClientProvider);
    try {
      await api.postJson('/approvals/$id/$action', body: {'note': note.text});
      if (!mounted) return;
      setState(() {});
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Future<void> _newRequest() async {
    final t = AppLocalizations.of(context);
    final entity = TextEditingController();
    final title = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.requestApproval),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: entity, decoration: InputDecoration(labelText: t.entityProductsHint)),
              TextField(controller: title, decoration: InputDecoration(labelText: t.titleField)),
              TextField(controller: desc, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: t.descriptionLabel)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.submitLabel)),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(apiClientProvider);
    try {
      await api.postJson('/approvals', body: {
        'entity': entity.text.trim(),
        'title': title.text.trim(),
        'description': desc.text.trim(),
      });
      if (!mounted) return;
      setState(() {});
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }
}
