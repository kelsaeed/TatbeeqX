// Phase 4.19 — self-serve "Forgot password?" entry point.
//
// Companion to ResetPasswordPage. Sends a single-use reset link via
// email when SMTP is configured. The endpoint is anti-enumeration —
// always returns 200 with the same generic message — so we mirror
// that here: success UI for any non-empty input.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../l10n/gen/app_localizations.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;
  // 503 from the backend means SMTP isn't configured — we surface a
  // distinct message so the user knows to ask their admin.
  bool _smtpUnavailable = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _smtpUnavailable = false;
    });
    try {
      await ref.read(apiClientProvider).postJson('/auth/forgot-password', body: {
        'identifier': _idCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() { _busy = false; _sent = true; });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _busy = false;
        _smtpUnavailable = msg.contains('Email is not configured');
        _error = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _sent ? _buildSuccess(context) : _buildForm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.forgotPasswordTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            t.forgotPasswordPrompt,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _idCtrl,
            decoration: InputDecoration(labelText: t.usernameOrEmail),
            validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
            autofocus: true,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _smtpUnavailable
                  ? t.emailNotConfiguredOnServer
                  : t.somethingWentWrongDetail(_error ?? ''),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? t.sending : t.sendResetLink),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => GoRouter.of(context).go('/login'),
            child: Text(t.backToSignIn),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(t.checkYourEmail, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          t.resetLinkSentMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => GoRouter.of(context).go('/login'),
          child: Text(t.backToSignIn),
        ),
      ],
    );
  }
}
