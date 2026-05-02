import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/paginated_search_table.dart';

class SystemLogsPage extends ConsumerStatefulWidget {
  const SystemLogsPage({super.key});

  @override
  ConsumerState<SystemLogsPage> createState() => _SystemLogsPageState();
}

class _SystemLogsPageState extends ConsumerState<SystemLogsPage> {
  String? _level;
  String? _source;

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
            title: t.systemLogs,
            subtitle: t.systemLogsSubtitle,
            actions: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.cleaning_services_outlined),
                label: Text(t.clearOlderThan30),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(t.clearOldLogsTitle),
                      content: Text(t.clearOldLogsBody),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete)),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await api.postJson('/system-logs/clear', body: {'olderThanDays': 30});
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _level,
                  decoration: InputDecoration(labelText: t.levelField),
                  items: [
                    DropdownMenuItem(value: null, child: Text(t.allLevels)),
                    DropdownMenuItem(value: 'debug', child: Text(t.levelDebug)),
                    DropdownMenuItem(value: 'info', child: Text(t.levelInfo)),
                    DropdownMenuItem(value: 'warn', child: Text(t.levelWarn)),
                    DropdownMenuItem(value: 'error', child: Text(t.levelError)),
                  ],
                  onChanged: (v) => setState(() => _level = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(labelText: t.sourceField),
                  onSubmitted: (v) => setState(() => _source = v.isEmpty ? null : v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PaginatedSearchTable<Map<String, dynamic>>(
            key: ValueKey('${_level ?? '*'}-${_source ?? '*'}'),
            searchable: true,
            searchHint: t.searchMessageContext,
            fetch: ({required page, required pageSize, required search}) async {
              final query = <String, dynamic>{'page': page, 'pageSize': pageSize};
              if (_level != null) query['level'] = _level;
              if (_source != null) query['source'] = _source;
              if (search.isNotEmpty) query['q'] = search;
              final res = await api.getJson('/system-logs', query: query);
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
              TableColumn(label: t.levelField, flex: 1, cell: (r) {
                final lv = r['level']?.toString() ?? '';
                Color c;
                switch (lv) {
                  case 'error': c = Colors.red; break;
                  case 'warn':  c = Colors.orange; break;
                  case 'info':  c = Colors.blue; break;
                  default:      c = Colors.grey;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(lv.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 11)),
                );
              }),
              TableColumn(label: t.sourceField, flex: 2, cell: (r) => Text(r['source']?.toString() ?? '')),
              TableColumn(label: t.messageField, flex: 5, cell: (r) => Text(r['message']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ],
      ),
    );
  }
}
