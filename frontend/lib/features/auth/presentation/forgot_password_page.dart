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
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Forgot password', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Enter your username or email. If the account exists, we\'ll send a one-time reset link.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _idCtrl,
            decoration: const InputDecoration(labelText: 'Username or email'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            autofocus: true,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _smtpUnavailable
                  ? 'Email isn\'t configured on this server. Ask an admin to reset your password manually.'
                  : 'Something went wrong: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Sending…' : 'Send reset link'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => GoRouter.of(context).go('/login'),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text('Check your email', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'If an account exists for that username or email, a reset link has been sent. The link is valid for the next hour and can only be used once.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => GoRouter.of(context).go('/login'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
