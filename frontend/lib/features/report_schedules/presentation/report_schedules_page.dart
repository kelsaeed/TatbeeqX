import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';

class ReportSchedulesPage extends ConsumerStatefulWidget {
  const ReportSchedulesPage({super.key});

  @override
  ConsumerState<ReportSchedulesPage> createState() => _ReportSchedulesPageState();
}

class _ReportSchedulesPageState extends ConsumerState<ReportSchedulesPage> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    setState(() { _loading = true; _error = null; });
    try {
      final res = await api.getJson('/report-schedules');
      final reports = await api.getJson('/reports');
      if (!mounted) return;
      setState(() {
        _items = (res['items'] as List).cast<Map<String, dynamic>>();
        _reports = (reports['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('${t.error}: $_error'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.reportSchedules,
            subtitle: t.reportSchedulesSubtitle,
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(t.newSchedule),
                onPressed: _newSchedule,
              ),
            ],
          ),
          if (_items.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(t.noSchedulesYet)),
          ..._items.map((s) => _renderRow(s, t)),
        ],
      ),
    );
  }

  Widget _renderRow(Map<String, dynamic> s, AppLocalizations t) {
    final report = (s['report'] as Map?) ?? {};
    final next = s['nextRunAt'] as String?;
    final last = s['lastRunAt'] as String?;
    return Card(
      child: ListTile(
        leading: Icon(s['enabled'] == true ? Icons.schedule : Icons.pause_circle_outline),
        title: Text('${s['name']}  •  ${report['name'] ?? '-'}'),
        subtitle: Text(
          '${s['frequency']}'
          '${(s['cron'] as String?)?.isNotEmpty == true ? ' (${s['cron']})' : ''}'
          '${(s['timeOfDay'] as String?)?.isNotEmpty == true ? ' @ ${s['timeOfDay']}' : ''}'
          '\nNext: ${_fmt(next)}   •   Last: ${_fmt(last)}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: Icon(s['enabled'] == true ? Icons.pause : Icons.play_arrow, size: 18),
              tooltip: s['enabled'] == true ? t.disableLabel : t.enableLabel,
              onPressed: () => _toggle(s['id'] as int, !(s['enabled'] == true)),
            ),
            IconButton(
              icon: const Icon(Icons.bolt, size: 18),
              tooltip: t.runNow,
              onPressed: () => _runNow(s['id'] as int),
            ),
            IconButton(
              icon: const Icon(Icons.history, size: 18),
              tooltip: t.recentRuns,
              onPressed: () => _showRuns(s['id'] as int, s['name']?.toString() ?? '-'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: t.delete,
              onPressed: () => _delete(s['id'] as int),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    return DateFormat('yyyy-MM-dd HH:mm').format(d);
  }

  Future<void> _toggle(int id, bool enabled) async {
    final api = ref.read(apiClientProvider);
    await api.putJson('/report-schedules/$id', body: {'enabled': enabled});
    await _load();
  }

  Future<void> _runNow(int id) async {
    final api = ref.read(apiClientProvider);
    final t = AppLocalizations.of(context);
    try {
      final res = await api.postJson('/report-schedules/$id/run-now');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['success'] == true ? t.runSucceeded : t.runFailedMsg(res['error']?.toString() ?? '')),
      ));
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Future<void> _delete(int id) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteScheduleTitle),
        content: Text(t.deleteScheduleBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete)),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(apiClientProvider);
    await api.deleteJson('/report-schedules/$id');
    await _load();
  }

  Future<void> _showRuns(int id, String name) async {
    final api = ref.read(apiClientProvider);
    final res = await api.getJson('/report-schedules/$id/runs');
    if (!mounted) return;
    final runs = (res['items'] as List).cast<Map<String, dynamic>>();
    final t = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.recentRunsFor(name)),
        content: SizedBox(
          width: 600,
          child: runs.isEmpty
              ? Text(t.noRunsYet)
              : ListView(
                  shrinkWrap: true,
                  children: runs.map((r) {
                    final iso = r['runAt'] as String?;
                    final d = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
                    final ok = r['success'] == true;
                    return ListTile(
                      leading: Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red, size: 18),
                      title: Text(d == null ? '-' : DateFormat('yyyy-MM-dd HH:mm:ss').format(d)),
                      subtitle: ok ? null : Text(r['error']?.toString() ?? ''),
                      dense: true,
                    );
                  }).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close))],
      ),
    );
  }

  Future<void> _newSchedule() async {
    final t = AppLocalizations.of(context);
    if (_reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.noReportsDefinedYet)));
      return;
    }
    int? reportId = _reports.first['id'] as int?;
    final name = TextEditingController();
    String frequency = 'daily';
    final cron = TextEditingController();
    final timeOfDay = TextEditingController(text: '09:00');
    final dayOfWeek = TextEditingController(text: '1');
    final dayOfMonth = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(t.newSchedule),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: reportId,
                  decoration: const InputDecoration(labelText: 'Report'),
                  items: _reports
                      .map((r) => DropdownMenuItem<int?>(value: r['id'] as int?, child: Text(r['name']?.toString() ?? '')))
                      .toList(),
                  onChanged: (v) => setSt(() => reportId = v),
                ),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Schedule name')),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'every_minute', child: Text('Every minute')),
                    DropdownMenuItem(value: 'every_5_minutes', child: Text('Every 5 minutes')),
                    DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'cron', child: Text('Cron expression')),
                  ],
                  onChanged: (v) => setSt(() => frequency = v ?? 'daily'),
                ),
                if (frequency == 'cron')
                  TextField(controller: cron, decoration: const InputDecoration(labelText: 'Cron (5 fields, e.g. 0 9 * * 1-5)')),
                if (frequency == 'daily' || frequency == 'weekly' || frequency == 'monthly')
                  TextField(controller: timeOfDay, decoration: const InputDecoration(labelText: 'Time of day HH:MM')),
                if (frequency == 'weekly')
                  TextField(controller: dayOfWeek, decoration: const InputDecoration(labelText: 'Day of week (0=Sun..6=Sat)')),
                if (frequency == 'monthly')
                  TextField(controller: dayOfMonth, decoration: const InputDecoration(labelText: 'Day of month (1-28)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.create)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final api = ref.read(apiClientProvider);
    try {
      await api.postJson('/report-schedules', body: {
        'reportId': reportId,
        'name': name.text.trim(),
        'frequency': frequency,
        if (frequency == 'cron') 'cron': cron.text.trim(),
        if (frequency == 'daily' || frequency == 'weekly' || frequency == 'monthly') 'timeOfDay': timeOfDay.text.trim(),
        if (frequency == 'weekly') 'dayOfWeek': int.tryParse(dayOfWeek.text.trim()) ?? 1,
        if (frequency == 'monthly') 'dayOfMonth': int.tryParse(dayOfMonth.text.trim()) ?? 1,
      });
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }
}
