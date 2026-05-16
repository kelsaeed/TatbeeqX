import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/paginated_search_table.dart';
import '../../../shared/widgets/row_actions.dart';
import '../../auth/application/auth_controller.dart';
import 'user_form_dialog.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _tableKey = GlobalKey<PaginatedSearchTableState<Map<String, dynamic>>>();

  Future<({List<Map<String, dynamic>> items, int total})> _fetch(ApiClient api,
      {required int page, required int pageSize, required String search}) async {
    final res = await api.getJson('/users', query: {'page': page, 'pageSize': pageSize, 'search': search});
    final items = (res['items'] as List).cast<Map<String, dynamic>>();
    return (items: items, total: (res['total'] as int?) ?? items.length);
  }

  Future<void> _openForm(BuildContext context, {Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => UserFormDialog(existing: existing),
    );
    if (saved == true) _tableKey.currentState?.reload();
  }

  // Phase 4.16 follow-up — admin-token password reset.
  // Asks the backend to mint a one-time, short-lived token, then
  // shows it (plus a reset URL) in a dialog so the operator can
  // share it with the user out-of-band. Plaintext is shown ONCE —
  // the backend persists only its sha256.
  Future<void> _generateResetToken(Map<String, dynamic> u) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.generateResetTokenTitle),
        content: Text(t.generateResetTokenConfirm(u['username'].toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(t.generate)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).postJson('/users/${u['id']}/reset-token');
      if (!mounted) return;
      await showDialog(
        context: context,
        // Token is shown ONCE; no dismissing by tapping outside
        // means the operator has to actively close, encouraging them
        // to copy first.
        barrierDismissible: false,
        builder: (_) => _ResetTokenDialog(
          token: res['token'].toString(),
          expiresAt: DateTime.tryParse(res['expiresAt']?.toString() ?? '') ?? DateTime.now(),
          username: u['username'].toString(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.resetTokenFailed(e.toString()))),
      );
    }
  }

  // Phase 4.16 follow-up — admin reset of a user's 2FA. The endpoint
  // is idempotent (returns ok:true with `was2FAEnabled` flag), so the
  // UI doesn't need to know whether the user actually had 2FA on.
  // We surface a different success message either way.
  Future<void> _reset2FA(Map<String, dynamic> u) async {
    final t = AppLocalizations.of(context);
    final username = u['username'].toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.reset2FA),
        content: Text(t.reset2FAConfirm(username)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.reset2FA),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).postJson('/users/${u['id']}/2fa/reset');
      if (!mounted) return;
      final wasEnabled = res['was2FAEnabled'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(wasEnabled ? t.reset2FASuccess(username) : t.reset2FAWasNotEnabled(username)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.saveFailed(e.toString()))),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deleteUser),
        content: Text(t.deleteCannotBeUndone(u['username'].toString())),
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
    final api = ref.read(apiClientProvider);
    try {
      await api.deleteJson('/users/${u['id']}');
      _tableKey.currentState?.reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deleteFailedMsg(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final auth = ref.watch(authControllerProvider);
    final t = AppLocalizations.of(context);
    final canCreate = auth.can('users.create');
    final canEdit = auth.can('users.edit');
    final canDelete = auth.can('users.delete');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.users,
            subtitle: t.usersSubtitle,
            actions: [
              if (canCreate)
                ElevatedButton.icon(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: Text(t.newUser),
                ),
            ],
          ),
          PaginatedSearchTable<Map<String, dynamic>>(
            key: _tableKey,
            searchHint: t.searchUsers,
            fetch: ({required page, required pageSize, required search}) =>
                _fetch(api, page: page, pageSize: pageSize, search: search),
            columns: [
              TableColumn(label: t.username, flex: 2, cell: (r) => Text(r['username']?.toString() ?? '')),
              TableColumn(label: t.fullName, flex: 2, cell: (r) => Text(r['fullName']?.toString() ?? '')),
              TableColumn(label: t.email, flex: 2, cell: (r) => Text(r['email']?.toString() ?? '')),
              TableColumn(
                label: t.rolesField,
                flex: 2,
                cell: (r) {
                  final roles = (r['roles'] as List? ?? const []);
                  return Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: roles.map((rl) => Chip(label: Text(rl['name'].toString()))).toList(),
                  );
                },
              ),
              TableColumn(
                label: t.statusLabel,
                flex: 1,
                cell: (r) => Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: (r['isActive'] == true) ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text((r['isActive'] == true) ? t.active : t.inactive),
                ]),
              ),
              TableColumn(
                label: '',
                flex: 1,
                cell: (r) => RowActionsMenu(
                  actions: [
                    if (canEdit)
                      RowAction(
                        icon: Icons.edit_outlined,
                        label: t.edit,
                        onTap: () => _openForm(context, existing: r),
                      ),
                    if (canEdit)
                      RowAction(
                        icon: Icons.vpn_key_outlined,
                        label: t.generateResetToken,
                        onTap: () => _generateResetToken(r),
                      ),
                    if (canEdit)
                      RowAction(
                        icon: Icons.shield_outlined,
                        label: t.reset2FA,
                        onTap: () => _reset2FA(r),
                      ),
                    if (canDelete)
                      RowAction(
                        icon: Icons.delete_outline,
                        label: t.delete,
                        onTap: () => _delete(r),
                        destructive: true,
                      ),
                  ],
                ),
              ),
            ],
            emptyAction: canCreate
                ? ElevatedButton.icon(
                    onPressed: () => _openForm(context),
                    icon: const Icon(Icons.add),
                    label: Text(t.newUser),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// Phase 4.16 follow-up — display the just-generated reset token. Shown
// once per generation; the backend persists only the sha256.
class _ResetTokenDialog extends StatelessWidget {
  const _ResetTokenDialog({
    required this.token,
    required this.expiresAt,
    required this.username,
  });
  final String token;
  final DateTime expiresAt;
  final String username;

  String get _resetUrl {
    // Best-effort URL construction. On Flutter web `Uri.base` reflects
    // the running page's origin. On desktop / mobile there's no
    // sensible default, so we surface a relative URL the operator can
    // prefix with their actual host.
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}/reset-password?token=$token';
    }
    return '/reset-password?token=$token';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat.yMd().add_Hm();

    Future<void> copy(String value) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.copiedToClipboard)),
      );
    }

    return AlertDialog(
      title: Text(t.resetTokenDialogTitle(username)),
      content: SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.resetTokenWarning)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(t.resetTokenLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    token,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: t.copyToken,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => copy(token),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(t.resetUrlLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _resetUrl,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: t.copyResetUrl,
                  icon: const Icon(Icons.link, size: 18),
                  onPressed: () => copy(_resetUrl),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t.resetTokenExpires(df.format(expiresAt.toLocal())),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close)),
      ],
    );
  }
}
