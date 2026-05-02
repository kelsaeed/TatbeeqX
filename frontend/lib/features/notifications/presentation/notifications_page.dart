// Phase 4.18 — full notifications page. Companion to the topbar bell;
// mirrors the popover but with pagination and bulk actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/page_header.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _onlyUnread = false;
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
      final res = await api.getJson('/notifications', query: {
        'page': 1,
        'pageSize': 100,
        if (_onlyUnread) 'unread': 'true',
      });
      if (!mounted) return;
      setState(() {
        _items = (res['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  Future<void> _markRead(int id) async {
    await ref.read(apiClientProvider).postJson('/notifications/$id/read');
    await _load();
  }

  Future<void> _readAll() async {
    await ref.read(apiClientProvider).postJson('/notifications/read-all');
    await _load();
  }

  Future<void> _dismiss(int id) async {
    await ref.read(apiClientProvider).deleteJson('/notifications/$id');
    await _load();
  }

  Future<void> _clearRead() async {
    await ref.read(apiClientProvider).deleteJson('/notifications');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Notifications',
            subtitle: 'Workflows and the system can ping you here.',
            actions: [
              Row(children: [
                Switch(
                  value: _onlyUnread,
                  onChanged: (v) {
                    setState(() => _onlyUnread = v);
                    _load();
                  },
                ),
                const Text('Unread only'),
              ]),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              const SizedBox(width: 8),
              if (_items.any((n) => n['readAt'] == null))
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark all read'),
                  onPressed: _readAll,
                ),
              const SizedBox(width: 8),
              if (_items.any((n) => n['readAt'] != null))
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('Clear read'),
                  onPressed: _clearRead,
                ),
            ],
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nothing here.'),
            ),
          ..._items.map(_renderRow),
        ],
      ),
    );
  }

  Widget _renderRow(Map<String, dynamic> n) {
    final unread = n['readAt'] == null;
    final iso = n['createdAt'] as String?;
    final ts = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
    final link = n['link']?.toString();
    return Card(
      child: ListTile(
        leading: Icon(
          _kindIcon(n['kind']?.toString() ?? 'system'),
          color: unread ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
        title: Text(
          n['title']?.toString() ?? '',
          style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((n['body'] as String?)?.isNotEmpty == true) Text(n['body'].toString()),
            if (ts != null)
              Text(
                DateFormat('yyyy-MM-dd HH:mm:ss').format(ts),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (unread)
              IconButton(
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                tooltip: 'Mark read',
                onPressed: () => _markRead(n['id'] as int),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Dismiss',
              onPressed: () => _dismiss(n['id'] as int),
            ),
          ],
        ),
        onTap: () async {
          final router = GoRouter.of(context);
          if (unread) await _markRead(n['id'] as int);
          if (link != null && link.isNotEmpty) router.go(link);
        },
      ),
    );
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'workflow': return Icons.bolt;
      case 'approval': return Icons.shield_outlined;
      case 'system': return Icons.info_outline;
      default: return Icons.notifications_none;
    }
  }
}
