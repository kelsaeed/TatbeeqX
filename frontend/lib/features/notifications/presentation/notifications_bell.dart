// Phase 4.18 — topbar bell + recent-notifications popover.
//
// Polls /notifications/unread-count every 45s. The popover fetches the
// full list on open; tapping a notification marks it read, optionally
// navigates to its `link`, and refreshes the badge. A "View all" link
// at the bottom opens the dedicated /notifications page.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';

class NotificationsBell extends ConsumerStatefulWidget {
  const NotificationsBell({super.key});

  @override
  ConsumerState<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends ConsumerState<NotificationsBell> {
  int _unread = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getJson('/notifications/unread-count');
      if (!mounted) return;
      setState(() => _unread = (res['count'] as int?) ?? 0);
    } catch (_) { /* swallow — stale badge is fine */ }
  }

  Future<void> _openPopover() async {
    final api = ref.read(apiClientProvider);
    List<Map<String, dynamic>> items = [];
    try {
      final res = await api.getJson('/notifications', query: {'page': 1, 'pageSize': 20});
      items = (res['items'] as List).cast<Map<String, dynamic>>();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
      return;
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NotificationsPopover(
        initial: items,
        onRead: (id) async {
          await api.postJson('/notifications/$id/read');
          await _refresh();
        },
        onReadAll: () async {
          await api.postJson('/notifications/read-all');
          await _refresh();
        },
        onDismiss: (id) async {
          await api.deleteJson('/notifications/$id');
          await _refresh();
        },
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications${_unread > 0 ? " ($_unread unread)" : ""}',
      onPressed: _openPopover,
      icon: Badge(
        isLabelVisible: _unread > 0,
        // Cap the rendered count so a 999-unread user doesn't blow out
        // the badge width.
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NotificationsPopover extends StatefulWidget {
  final List<Map<String, dynamic>> initial;
  final Future<void> Function(int id) onRead;
  final Future<void> Function() onReadAll;
  final Future<void> Function(int id) onDismiss;

  const _NotificationsPopover({
    required this.initial,
    required this.onRead,
    required this.onReadAll,
    required this.onDismiss,
  });

  @override
  State<_NotificationsPopover> createState() => _NotificationsPopoverState();
}

class _NotificationsPopoverState extends State<_NotificationsPopover> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('Notifications'),
          const Spacer(),
          if (_items.any((n) => n['readAt'] == null))
            TextButton(
              onPressed: () async {
                await widget.onReadAll();
                if (!mounted) return;
                setState(() {
                  for (final n in _items) {
                    n['readAt'] ??= DateTime.now().toIso8601String();
                  }
                });
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 480,
        child: _items.isEmpty
            ? const Center(child: Text('No notifications.'))
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = _items[i];
                  final unread = n['readAt'] == null;
                  final iso = n['createdAt'] as String?;
                  final ts = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
                  return ListTile(
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
                        if ((n['body'] as String?)?.isNotEmpty == true)
                          Text(n['body'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (ts != null)
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(ts),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Dismiss',
                      onPressed: () async {
                        await widget.onDismiss(n['id'] as int);
                        if (!mounted) return;
                        setState(() => _items.removeAt(i));
                      },
                    ),
                    onTap: () async {
                      // Capture before the await so the lint analyzer
                      // can verify no BuildContext use crosses an
                      // async gap.
                      final nav = Navigator.of(context);
                      final router = GoRouter.of(context);
                      if (unread) {
                        await widget.onRead(n['id'] as int);
                        if (!mounted) return;
                        setState(() => n['readAt'] = DateTime.now().toIso8601String());
                      }
                      final link = n['link']?.toString();
                      if (link != null && link.isNotEmpty) {
                        nav.pop();
                        router.go(link);
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            GoRouter.of(context).go('/notifications');
          },
          child: const Text('View all'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
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
