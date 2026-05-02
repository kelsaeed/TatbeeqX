// Phase 4.16 follow-up — public password-reset page. Operator hands
// the user a token (via /api/users/:id/reset-token) plus a URL like
// /reset-password?token=<token>; this page picks the token out of
// the query params, lets the user choose a new password, and POSTs
// to /api/auth/redeem-reset-token.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, this.initialToken});
  final String? initialToken;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _tokenCtrl;
  late final TextEditingController _newPwdCtrl;
  late final TextEditingController _confirmCtrl;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: widget.initialToken ?? '');
    _newPwdCtrl = TextEditingController();
    _confirmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).postJson('/auth/redeem-reset-token', body: {
        'token': _tokenCtrl.text.trim(),
        'newPassword': _newPwdCtrl.text,
      });
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.resetPasswordSuccess)),
      );
      // Redirect to login — interceptor will rebuild the session
      // when the user signs in.
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.resetPasswordTitle, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        t.resetPasswordBody,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tokenCtrl,
                        decoration: InputDecoration(labelText: t.resetTokenField),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPwdCtrl,
                        obscureText: true,
                        decoration: InputDecoration(labelText: t.newPasswordField),
                        validator: (v) => (v == null || v.length < 8) ? t.min8Chars : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: true,
                        decoration: InputDecoration(labelText: t.confirmPasswordField),
                        validator: (v) => (v != _newPwdCtrl.text) ? t.passwordsMustMatch : null,
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(
                          t.resetPasswordFailedMsg(_error!),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? t.saving : t.resetPasswordAction),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : () => context.go('/login'),
                        child: Text(t.back),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
