import 'dart:io';

import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/paginated_search_table.dart';
import '../../auth/application/auth_controller.dart';
import 'custom_record_dialog.dart';

class CustomListPage extends ConsumerStatefulWidget {
  const CustomListPage({super.key, required this.code});
  final String code;

  @override
  ConsumerState<CustomListPage> createState() => _CustomListPageState();
}

class _CustomListPageState extends ConsumerState<CustomListPage> {
  bool _loading = true;
  Map<String, dynamic>? _entity;
  final _tableKey = GlobalKey<PaginatedSearchTableState<Map<String, dynamic>>>();
  // Phase 4.16 follow-up — bulk selection. The set persists across
  // pagination/search reloads, so an operator can select on page 1,
  // navigate to page 2, select more, then bulk-delete the union.
  // Cleared after a successful bulk action or when the entity changes.
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadEntity);
  }

  @override
  void didUpdateWidget(covariant CustomListPage old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) {
      setState(() {
        _loading = true;
        _entity = null;
        _selectedIds.clear();
      });
      _loadEntity();
    }
  }

  Future<void> _bulkDelete() async {
    final t = AppLocalizations.of(context);
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.bulkDeleteTitle),
        content: Text(t.bulkDeleteConfirm(ids.length)),
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
      // Dio supports a `data:` body on DELETE; the project's
      // ApiClient.deleteJson() doesn't expose it, so fall through to
      // the underlying dio. Auth interceptor + 401 auto-refresh still
      // apply.
      final dio = ref.read(apiClientProvider).dio;
      final resp = await dio.delete('/c/${widget.code}/bulk', data: {'ids': ids});
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      _tableKey.currentState?.reload();
      final body = resp.data is Map ? (resp.data as Map).cast<String, dynamic>() : <String, dynamic>{};
      final deleted = (body['deleted'] as int?) ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.bulkDeleteResult(deleted))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.deleteFailedMsg(e.toString()))),
      );
    }
  }

  Future<void> _loadEntity() async {
    try {
      final res = await ref.read(apiClientProvider).getJson('/custom-entities/${widget.code}');
      setState(() {
        _entity = res;
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

  Future<({List<Map<String, dynamic>> items, int total})> _fetch({
    required int page,
    required int pageSize,
    required String search,
  }) async {
    final res = await ref.read(apiClientProvider).getJson(
      '/c/${widget.code}',
      query: {'page': page, 'pageSize': pageSize, 'search': search},
    );
    final items = (res['items'] as List).cast<Map<String, dynamic>>();
    return (items: items, total: (res['total'] as int?) ?? items.length);
  }

  Future<void> _open({Map<String, dynamic>? row}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CustomRecordDialog(entity: _entity!, row: row),
    );
    if (saved == true) _tableKey.currentState?.reload();
  }

  Future<void> _exportCsv() async {
    final t = AppLocalizations.of(context);
    final code = widget.code;
    try {
      // Resolve a writable directory: getDownloadsDirectory() works on
      // Windows/macOS/Linux desktop and modern iOS/Android. Fall back
      // to documents dir if the platform doesn't support downloads.
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final path = '${dir.path}${Platform.pathSeparator}$code-$stamp.csv';

      // Use the existing dio client so the auth interceptor + automatic
      // refresh both apply. Streams the response straight to disk —
      // no in-memory copy of the whole CSV.
      final dio = ref.read(apiClientProvider).dio;
      final res = await dio.download(
        '/c/$code/export.csv',
        path,
        options: Options(
          // Backend returns text/csv; dio's default validateStatus is
          // already < 500 from BaseOptions, so 4xx errors flow through
          // the interceptor and surface as ApiException.
          responseType: ResponseType.bytes,
        ),
      );
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.csvExportedTo(path)),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.exportFailed(e.toString()))),
      );
    }
  }

  Future<void> _importCsv() async {
    final didImport = await showDialog<bool>(
      context: context,
      builder: (_) => _CsvImportDialog(entityCode: widget.code),
    );
    if (didImport == true) _tableKey.currentState?.reload();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteRowTitle),
        content: Text(t.deleteConfirm(
          row.values.firstWhere((v) => v != null && v.toString().isNotEmpty, orElse: () => row['id']).toString(),
        )),
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
      await ref.read(apiClientProvider).deleteJson('/c/${widget.code}/${row['id']}');
      _tableKey.currentState?.reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deleteFailedMsg(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_loading || _entity == null) {
      return const Padding(padding: EdgeInsets.all(40), child: LoadingView());
    }
    final auth = ref.watch(authControllerProvider);
    final prefix = _entity!['permissionPrefix'].toString();
    final cols = (_entity!['config']?['columns'] as List? ?? const []).cast<Map<String, dynamic>>();
    // Phase 4.16 — drop columns the caller can't view. Backend already
    // strips data for these; hiding the empty column too keeps the
    // table tidy.
    final listCols = cols.where((c) {
      if (c['showInList'] == false) return false;
      final viewPerm = c['viewPermission']?.toString();
      if (viewPerm != null && viewPerm.isNotEmpty && !auth.can(viewPerm)) return false;
      return true;
    }).take(6).toList();
    final singular = (_entity!['singular'] as String? ?? 'row').toLowerCase();
    final pluralLabel = (_entity!['label'] as String).toLowerCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: _entity!['label'].toString(),
            subtitle: t.tableLabel(_entity!['tableName'].toString()),
            actions: [
              if (auth.can('$prefix.delete') && _selectedIds.isNotEmpty) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(t.bulkDeleteButton(_selectedIds.length)),
                ),
                const SizedBox(width: 8),
              ],
              if (auth.can('$prefix.export'))
                OutlinedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text(t.exportCsv),
                ),
              if (auth.can('$prefix.create')) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _importCsv,
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: Text(t.importCsv),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _open(),
                  icon: const Icon(Icons.add),
                  label: Text(t.newEntitySingular(singular)),
                ),
              ],
            ],
          ),
          PaginatedSearchTable<Map<String, dynamic>>(
            key: _tableKey,
            searchHint: t.searchEntityHint(pluralLabel),
            fetch: _fetch,
            columns: [
              if (auth.can('$prefix.delete'))
                TableColumn<Map<String, dynamic>>(
                  label: '',
                  flex: 0,
                  cell: (r) {
                    final id = r['id'];
                    if (id is! int) return const SizedBox.shrink();
                    final isSelected = _selectedIds.contains(id);
                    return Checkbox(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
              for (final c in listCols)
                TableColumn<Map<String, dynamic>>(
                  label: c['label']?.toString() ?? c['name'].toString(),
                  flex: 1,
                  numeric: c['type'] == 'integer' || c['type'] == 'number',
                  cell: (r) {
                    final v = r[c['name'].toString()];
                    if (c['type'] == 'bool') {
                      return Text(v == 1 || v == true ? t.yes : t.no);
                    }
                    return Text(v?.toString() ?? '');
                  },
                ),
              TableColumn<Map<String, dynamic>>(
                label: '',
                flex: 1,
                cell: (r) => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (auth.can('$prefix.edit'))
                      IconButton(
                        tooltip: t.edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _open(row: r),
                      ),
                    if (auth.can('$prefix.delete'))
                      IconButton(
                        tooltip: t.delete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _delete(r),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Phase 4.16 follow-up — paste-CSV import dialog. Operator pastes CSV
// (typically just-exported from another install or from Excel), runs
// a Preview (dryRun=true) to see how many rows would land + which
// would error, then commits with Import (dryRun=false).
//
// Server returns `{ok, dryRun, summary: {total, created, skipped,
// errors}, errors: [{line, message}]}`. We render the summary with
// color coding + the first ~100 errors in a scrollable list.
class _CsvImportDialog extends ConsumerStatefulWidget {
  const _CsvImportDialog({required this.entityCode});
  final String entityCode;

  @override
  ConsumerState<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends ConsumerState<_CsvImportDialog> {
  final _csvController = TextEditingController();
  bool _running = false;
  Map<String, dynamic>? _result; // { dryRun, summary, errors }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _run({required bool dryRun}) async {
    if (_csvController.text.trim().isEmpty) return;
    setState(() => _running = true);
    try {
      final res = await ref.read(apiClientProvider).postJson(
        '/c/${widget.entityCode}/import',
        body: {'csv': _csvController.text, 'dryRun': dryRun},
      );
      if (!mounted) return;
      setState(() {
        _result = res;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).importFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final didCommit = _result != null && _result!['dryRun'] == false && (_result!['summary']?['created'] ?? 0) > 0;

    return AlertDialog(
      title: Text(t.importCsv),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.importCsvHelp, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _csvController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'name,qty\nAlpha,5\nBeta,10',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              _ImportSummary(result: _result!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.pop(context, didCommit),
          child: Text(didCommit ? t.close : t.cancel),
        ),
        OutlinedButton.icon(
          onPressed: _running ? null : () => _run(dryRun: true),
          icon: const Icon(Icons.preview_outlined, size: 16),
          label: Text(t.previewAction),
        ),
        ElevatedButton.icon(
          onPressed: _running ? null : () => _run(dryRun: false),
          icon: const Icon(Icons.file_upload, size: 16),
          label: Text(t.importAction),
        ),
      ],
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final summary = (result['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dryRun = result['dryRun'] == true;
    final errors = (result['errors'] as List? ?? const []).cast<Map>().cast<Map<String, dynamic>>();

    final created = summary['created'] ?? 0;
    final skipped = summary['skipped'] ?? 0;
    final errCount = summary['errors'] ?? 0;
    final total = summary['total'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (dryRun)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(t.previewBadge, style: TextStyle(fontSize: 11, color: cs.tertiary)),
                ),
              if (dryRun) const SizedBox(width: 8),
              Text(t.importSummary(total, created, skipped, errCount)),
            ],
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: errors.length,
                itemBuilder: (_, i) {
                  final e = errors[i];
                  return Text(
                    'Line ${e['line']}: ${e['message']}',
                    style: TextStyle(fontSize: 11, color: cs.error),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
