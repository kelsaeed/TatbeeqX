import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/paginated_search_table.dart';

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final t = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.audit,
            subtitle: t.auditSubtitle,
          ),
          PaginatedSearchTable<Map<String, dynamic>>(
            searchable: false,
            fetch: ({required page, required pageSize, required search}) async {
              final res = await api.getJson('/audit', query: {'page': page, 'pageSize': pageSize});
              final items = (res['items'] as List).cast<Map<String, dynamic>>();
              return (items: items, total: (res['total'] as int?) ?? items.length);
            },
            columns: [
              TableColumn(
                label: t.auditWhen,
                flex: 2,
                cell: (r) {
                  final iso = r['createdAt'] as String?;
                  final d = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
                  return Text(d == null ? '' : DateFormat('yyyy-MM-dd HH:mm:ss').format(d));
                },
              ),
              TableColumn(label: t.auditUser, flex: 2, cell: (r) {
                final u = r['user'] as Map<String, dynamic>?;
                return Text(u?['fullName']?.toString() ?? u?['username']?.toString() ?? t.systemUserLabel);
              }),
              TableColumn(label: t.auditAction, flex: 1, cell: (r) => Text(r['action']?.toString() ?? '')),
              TableColumn(label: t.auditEntity, flex: 1, cell: (r) => Text(r['entity']?.toString() ?? '')),
              TableColumn(label: t.auditId, flex: 1, cell: (r) => Text(r['entityId']?.toString() ?? '')),
              TableColumn(label: t.auditIp, flex: 1, cell: (r) => Text(r['ipAddress']?.toString() ?? '')),
            ],
          ),
        ],
      ),
    );
  }
}
