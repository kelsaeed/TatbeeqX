import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/paginated_search_table.dart';

class LoginEventsPage extends ConsumerStatefulWidget {
  const LoginEventsPage({super.key});

  @override
  ConsumerState<LoginEventsPage> createState() => _LoginEventsPageState();
}

class _LoginEventsPageState extends ConsumerState<LoginEventsPage> {
  String? _event;
  String? _success;

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
            title: t.loginActivity,
            subtitle: t.loginActivitySubtitle,
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _event,
                  decoration: InputDecoration(labelText: t.eventField),
                  items: [
                    DropdownMenuItem(value: null, child: Text(t.allEvents)),
                    DropdownMenuItem(value: 'login', child: Text(t.loginEvent)),
                    DropdownMenuItem(value: 'logout', child: Text(t.logoutEvent)),
                    DropdownMenuItem(value: 'refresh', child: Text(t.refreshEvent)),
                  ],
                  onChanged: (v) => setState(() => _event = v),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _success,
                  decoration: InputDecoration(labelText: t.successField),
                  items: [
                    DropdownMenuItem(value: null, child: Text(t.all)),
                    DropdownMenuItem(value: 'true', child: Text(t.successfulOption)),
                    DropdownMenuItem(value: 'false', child: Text(t.failedOption)),
                  ],
                  onChanged: (v) => setState(() => _success = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PaginatedSearchTable<Map<String, dynamic>>(
            key: ValueKey('${_event ?? '*'}-${_success ?? '*'}'),
            searchable: true,
            searchHint: t.searchLoginEvents,
            fetch: ({required page, required pageSize, required search}) async {
              final query = <String, dynamic>{'page': page, 'pageSize': pageSize};
              if (_event != null) query['event'] = _event;
              if (_success != null) query['success'] = _success;
              if (search.isNotEmpty) query['q'] = search;
              final res = await api.getJson('/login-events', query: query);
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
              TableColumn(label: t.username, flex: 2, cell: (r) => Text(r['username']?.toString() ?? '')),
              TableColumn(label: t.eventField, flex: 1, cell: (r) => Text(r['event']?.toString() ?? '')),
              TableColumn(
                label: t.resultColumn,
                flex: 1,
                cell: (r) {
                  final ok = r['success'] == true;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (ok ? Colors.green : Colors.red).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ok ? t.okShort : t.failShort,
                      style: TextStyle(color: ok ? Colors.green : Colors.red, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  );
                },
              ),
              TableColumn(label: t.auditIp, flex: 2, cell: (r) => Text(r['ipAddress']?.toString() ?? '')),
              TableColumn(label: t.reasonColumn, flex: 2, cell: (r) => Text(r['reason']?.toString() ?? '')),
            ],
          ),
        ],
      ),
    );
  }
}
