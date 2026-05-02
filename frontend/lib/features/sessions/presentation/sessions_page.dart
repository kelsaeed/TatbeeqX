// Phase 4.16 follow-up — Sessions / Active Devices page.
//
// Lists the caller's own active refresh-token rows from
// /api/auth/sessions, with a Revoke button per row. Marks the
// session that issued the caller's current refresh token via
// `current: true` (the frontend extracts the jti from its stored
// refresh JWT and passes it as ?currentJti=).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../auth/application/auth_controller.dart';

class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key});

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int? _revokingId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  // Pull the jti claim out of the stored refresh JWT so the backend
  // can mark the matching row as `current: true` in its response.
  String? _currentJti() {
    final refresh = ref.read(apiClientProvider).storage.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;
    try {
      final parts = refresh.split('.');
      if (parts.length < 2) return null;
      // base64url with padding tolerance.
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final json = jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      return json['jti']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jti = _currentJti();
      final res = await ref.read(apiClientProvider).getJson(
        '/auth/sessions',
        query: jti == null ? null : {'currentJti': jti},
      );
      if (!mounted) return;
      setState(() {
        _items = ((res['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _revoke(Map<String, dynamic> session) async {
    final t = AppLocalizations.of(context);
    final id = session['id'] as int;
    final isCurrent = session['current'] == true;
    final confirmText = isCurrent ? t.revokeCurrentSessionWarn : t.revokeSessionConfirm;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.revokeSessionTitle),
        content: Text(confirmText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.revokeAction),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _revokingId = id);
    try {
      await ref.read(apiClientProvider).deleteJson('/auth/sessions/$id');
      if (!mounted) return;
      setState(() => _revokingId = null);
      // If we just revoked our own session, the next request will 401
      // and the dio interceptor will boot the user. Otherwise just
      // refresh the list.
      if (!isCurrent) {
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.sessionRevoked)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _revokingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.revokeFailed(e.toString()))),
      );
    }
  }

  // Best-effort device label from the User-Agent string. Real UA
  // parsing is a v2 nicety; for now we surface a few well-known
  // tokens and fall back to "Unknown device" for empties.
  String _deviceLabel(String? ua, AppLocalizations t) {
    if (ua == null || ua.trim().isEmpty) return t.unknownDevice;
    final lower = ua.toLowerCase();
    if (lower.contains('windows')) return 'Windows';
    if (lower.contains('mac os') || lower.contains('macintosh')) return 'macOS';
    if (lower.contains('iphone')) return 'iPhone';
    if (lower.contains('ipad')) return 'iPad';
    if (lower.contains('android')) return 'Android';
    if (lower.contains('linux')) return 'Linux';
    return ua.length > 50 ? '${ua.substring(0, 50)}…' : ua;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(40), child: LoadingView());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text(t.loadFailed(_error!))),
      );
    }
    final dateFmt = DateFormat.yMd().add_Hm();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: t.sessionsTitle,
            subtitle: t.sessionsSubtitle,
            actions: [
              IconButton(
                tooltip: t.refresh,
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          // Phase 4.16 follow-up — 2FA management. Lives at the top of
          // this page since it's the canonical "your account security"
          // surface; no separate /security route to maintain.
          const _TwoFactorSection(),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text(t.noActiveSessions)),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final s in _items) ...[
                    ListTile(
                      leading: Icon(
                        s['current'] == true ? Icons.smartphone : Icons.devices_other,
                        color: s['current'] == true ? cs.primary : null,
                      ),
                      title: Row(
                        children: [
                          Text(_deviceLabel(s['userAgent']?.toString(), t)),
                          if (s['current'] == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t.currentSessionBadge,
                                style: TextStyle(fontSize: 11, color: cs.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (s['ip'] != null && s['ip'].toString().isNotEmpty)
                            Text('IP: ${s['ip']}', style: const TextStyle(fontSize: 12)),
                          Text(
                            t.sessionMeta(
                              dateFmt.format(DateTime.parse(s['issuedAt'].toString()).toLocal()),
                              dateFmt.format(DateTime.parse(s['expiresAt'].toString()).toLocal()),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: _revokingId == s['id']
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _revoke(s),
                              icon: const Icon(Icons.logout, size: 16),
                              label: Text(t.revokeAction),
                            ),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Phase 4.16 follow-up — Two-factor authentication management section.
// Reads `auth.user.totpEnabled` and renders an Enable/Disable button
// that opens the appropriate dialog. After a successful action it
// calls `auth.refreshMe()` so the section reflects the new state.
class _TwoFactorSection extends ConsumerWidget {
  const _TwoFactorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();
    final enabled = user.totpEnabled;
    final df = DateFormat.yMd();

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.shield : Icons.shield_outlined,
              color: enabled ? cs.primary : cs.outline,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.twoFactorTitle, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    enabled
                        ? (user.totpEnabledAt != null
                            ? t.twoFactorEnabledOn(df.format(user.totpEnabledAt!.toLocal()))
                            : t.twoFactorEnabled)
                        : t.twoFactorNotEnabled,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (enabled)
              OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const _TwoFactorDisableDialog(),
                ).then((_) => ref.read(authControllerProvider.notifier).refreshMe()),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: Text(t.disable2FA),
              )
            else
              ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const _TwoFactorEnrollmentDialog(),
                ).then((_) => ref.read(authControllerProvider.notifier).refreshMe()),
                icon: const Icon(Icons.shield, size: 16),
                label: Text(t.enable2FA),
              ),
          ],
        ),
      ),
    );
  }
}

// Enrollment is one big modal (no multi-step wizard) so the user can
// see + copy QR, secret, and recovery codes all in one shot, then
// confirm with a code at the bottom. barrierDismissible: false in
// the caller — closing without confirming leaves a half-enrolled
// state which the next /enroll call will overwrite anyway.
class _TwoFactorEnrollmentDialog extends ConsumerStatefulWidget {
  const _TwoFactorEnrollmentDialog();
  @override
  ConsumerState<_TwoFactorEnrollmentDialog> createState() => _TwoFactorEnrollmentDialogState();
}

class _TwoFactorEnrollmentDialogState extends ConsumerState<_TwoFactorEnrollmentDialog> {
  bool _loading = true;
  bool _verifying = false;
  String? _error;
  String? _secret;
  String? _qrDataUrl;
  List<String> _recoveryCodes = [];
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_enroll);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    try {
      final res = await ref.read(apiClientProvider).postJson('/auth/2fa/enroll');
      if (!mounted) return;
      setState(() {
        _secret = res['secret'].toString();
        _qrDataUrl = res['qrDataUrl'].toString();
        _recoveryCodes = ((res['recoveryCodes'] as List?) ?? []).map((e) => e.toString()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).postJson('/auth/2fa/verify-enrollment', body: {'code': code});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).twoFactorEnableSuccess)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = AppLocalizations.of(context).twoFactorEnableFailed;
      });
    }
  }

  Future<void> _copy(String s) async {
    await Clipboard.setData(ClipboardData(text: s));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)),
    );
  }

  Uint8List _decodeQr(String dataUrl) {
    final base = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    return base64.decode(base);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(t.enable2FA),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.enable2FAStep1, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    if (_qrDataUrl != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.white,
                          child: Image.memory(_decodeQr(_qrDataUrl!), width: 200, height: 200),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(t.secretLabel, style: Theme.of(context).textTheme.labelLarge),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _secret ?? '',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        IconButton(
                          tooltip: t.copySecret,
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: _secret == null ? null : () => _copy(_secret!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber, color: cs.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(child: Text(t.recoveryCodesTitle, style: Theme.of(context).textTheme.titleSmall)),
                              IconButton(
                                tooltip: t.copyRecoveryCodes,
                                icon: const Icon(Icons.copy_all, size: 18),
                                onPressed: _recoveryCodes.isEmpty
                                    ? null
                                    : () => _copy(_recoveryCodes.join('\n')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(t.recoveryCodesBody, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          SelectableText(
                            _recoveryCodes.join('\n'),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(t.enable2FAStep2, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 2),
                      decoration: InputDecoration(
                        labelText: t.twoFactorCodeField,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _verify(),
                      enabled: !_verifying,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _verifying ? null : () => Navigator.pop(context, false), child: Text(t.cancel)),
        ElevatedButton(
          onPressed: _loading || _verifying ? null : _verify,
          child: Text(_verifying ? t.saving : t.enable2FA),
        ),
      ],
    );
  }
}

class _TwoFactorDisableDialog extends ConsumerStatefulWidget {
  const _TwoFactorDisableDialog();
  @override
  ConsumerState<_TwoFactorDisableDialog> createState() => _TwoFactorDisableDialogState();
}

class _TwoFactorDisableDialogState extends ConsumerState<_TwoFactorDisableDialog> {
  final _ctrl = TextEditingController();
  bool _useRecovery = false;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _ctrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref.read(apiClientProvider).postJson('/auth/2fa/disable', body: {
        if (_useRecovery) 'recoveryCode': value else 'code': value,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).twoFactorDisableSuccess)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = AppLocalizations.of(context).twoFactorDisableFailed(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.disable2FATitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.disable2FABody, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              keyboardType: _useRecovery ? TextInputType.text : TextInputType.number,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 2),
              decoration: InputDecoration(
                labelText: _useRecovery ? t.recoveryCodeField : t.twoFactorCodeField,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _busy ? null : () => setState(() {
                  _useRecovery = !_useRecovery;
                  _ctrl.clear();
                  _err = null;
                }),
                child: Text(_useRecovery ? t.useTotpInstead : t.useRecoveryInstead),
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 4),
              Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(t.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? t.saving : t.disable2FA),
        ),
      ],
    );
  }
}
