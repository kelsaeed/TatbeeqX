import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';

class WebhooksPage extends ConsumerStatefulWidget {
  const WebhooksPage({super.key});

  @override
  ConsumerState<WebhooksPage> createState() => _WebhooksPageState();
}

class _WebhooksPageState extends ConsumerState<WebhooksPage> {
  List<Map<String, dynamic>> _items = [];
  List<String> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getJson('/webhooks');
      final ev = await api.getJson('/webhooks/events');
      if (!mounted) return;
      setState(() {
        _items = (res['items'] as List).cast<Map<String, dynamic>>();
        _events = (ev['items'] as List).cast<String>();
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
            title: t.webhooks,
            subtitle: t.webhooksSubtitle,
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(t.newWebhook),
                onPressed: _newSubscription,
              ),
            ],
          ),
          if (_items.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(t.noSubscriptionsYet)),
          ..._items.map((s) => _renderRow(s, t)),
        ],
      ),
    );
  }

  Widget _renderRow(Map<String, dynamic> s, AppLocalizations t) {
    final events = (s['events'] as List? ?? const []).join(', ');
    return Card(
      child: ListTile(
        leading: Icon(s['enabled'] == true ? Icons.bolt : Icons.bolt_outlined,
            color: s['enabled'] == true ? Colors.green : Colors.grey),
        title: Text('${s['name']}  •  ${s['code']}'),
        subtitle: Text('${s['url']}\n${t.eventsLabel}: $events'),
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
              icon: const Icon(Icons.science_outlined, size: 18),
              tooltip: t.sendTestEvent,
              onPressed: () => _testFire(s['id'] as int),
            ),
            IconButton(
              icon: const Icon(Icons.history, size: 18),
              tooltip: t.recentDeliveries,
              onPressed: () => _showDeliveries(s['id'] as int, s['name']?.toString() ?? '-'),
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

  Future<void> _toggle(int id, bool enabled) async {
    final api = ref.read(apiClientProvider);
    await api.putJson('/webhooks/$id', body: {'enabled': enabled});
    await _load();
  }

  Future<void> _testFire(int id) async {
    final api = ref.read(apiClientProvider);
    await api.postJson('/webhooks/$id/test');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).testEventDispatched)),
    );
  }

  Future<void> _delete(int id) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteSubscriptionTitle),
        content: Text(t.deleteSubscriptionBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete)),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(apiClientProvider);
    await api.deleteJson('/webhooks/$id');
    await _load();
  }

  Future<void> _showDeliveries(int id, String name) async {
    final api = ref.read(apiClientProvider);
    final res = await api.getJson('/webhooks/$id/deliveries', query: {'page': 1, 'pageSize': 50});
    if (!mounted) return;
    final items = (res['items'] as List).cast<Map<String, dynamic>>();
    final t = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.recentDeliveriesFor(name)),
        content: SizedBox(
          width: 720,
          child: items.isEmpty
              ? Text(t.noDeliveriesYet)
              : ListView(
                  shrinkWrap: true,
                  children: items.map((d) {
                    final iso = d['createdAt'] as String?;
                    final t = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
                    final ok = (d['status'] as int? ?? 0) >= 200 && (d['status'] as int? ?? 0) < 300;
                    return ListTile(
                      leading: Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red, size: 18),
                      title: Text('${d['event']}  •  HTTP ${d['status'] ?? '—'}  •  attempt ${d['attempt']}'),
                      subtitle: Text(
                        '${t == null ? '' : DateFormat('yyyy-MM-dd HH:mm:ss').format(t)}\n'
                        '${d['error'] ?? d['responseBody'] ?? ''}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      dense: true,
                    );
                  }).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close))],
      ),
    );
  }

  Future<void> _newSubscription() async {
    final t = AppLocalizations.of(context);
    final code = TextEditingController();
    final name = TextEditingController();
    final url = TextEditingController(text: 'https://');
    final secret = TextEditingController();
    final selected = <String>{'*'};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(t.newWebhookSubscription),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: code, decoration: InputDecoration(labelText: t.codeLowerSnake)),
                TextField(controller: name, decoration: InputDecoration(labelText: t.name)),
                TextField(controller: url, decoration: InputDecoration(labelText: t.urlHttps)),
                TextField(controller: secret, decoration: InputDecoration(labelText: t.secretOptionalAuto)),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: Text(t.eventsLabel)),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _events.map((e) {
                    return FilterChip(
                      label: Text(e),
                      selected: selected.contains(e),
                      onSelected: (v) => setSt(() => v ? selected.add(e) : selected.remove(e)),
                    );
                  }).toList(),
                ),
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
    if (!mounted) return;
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.pickAtLeastOneEvent)));
      return;
    }
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.postJson('/webhooks', body: {
        'code': code.text.trim(),
        'name': name.text.trim(),
        'url': url.text.trim(),
        if (secret.text.trim().isNotEmpty) 'secret': secret.text.trim(),
        'events': selected.toList(),
      });
      if (!mounted) return;
      final s = res['secret']?.toString();
      if (s != null && s != '***') {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(t.webhookSecretTitle),
            content: SelectableText(
              t.webhookSecretSaveWarn(s),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.ok))],
          ),
        );
      }
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }
}
