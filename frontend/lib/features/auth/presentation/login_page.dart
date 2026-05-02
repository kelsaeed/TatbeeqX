import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_settings.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final outcome = await ref
        .read(authControllerProvider.notifier)
        .login(username: _user.text.trim(), password: _pass.text);
    if (!mounted) return;
    // Phase 4.16 follow-up — if the user has 2FA enabled, the backend
    // returned a challenge token instead of a session. Open the
    // challenge dialog; success there logs the user in.
    if (outcome.requires2FA) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _TotpChallengeDialog(challengeToken: outcome.challengeToken!),
      );
      if (!mounted) return;
      if (ok != true) {
        final err = ref.read(authControllerProvider).error
            ?? AppLocalizations.of(context).loginFailed;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    if (!outcome.ok) {
      final err = ref.read(authControllerProvider).error
          ?? AppLocalizations.of(context).loginFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = ref.watch(themeControllerProvider).settings;
    final cs = Theme.of(context).colorScheme;

    final form = _LoginForm(
      formKey: _form,
      user: _user,
      pass: _pass,
      obscure: _obscure,
      toggleObscure: () => setState(() => _obscure = !_obscure),
      onSubmit: _submit,
      loading: auth.loading,
      theme: theme,
    );

    final hasBg = (theme.backgroundImageUrl ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      body: LayoutBuilder(
        builder: (ctx, c) {
          final wide = c.maxWidth >= 900;

          switch (theme.loginStyle) {
            case 'centered':
              return _CenteredLogin(theme: theme, form: form, hasBg: hasBg);
            case 'minimal':
              return SafeArea(child: Center(child: SingleChildScrollView(child: form)));
            case 'split':
            default:
              if (!wide) {
                return _CenteredLogin(theme: theme, form: form, hasBg: hasBg);
              }
              return Row(
                children: [
                  Expanded(child: _LoginHero(theme: theme, hasBg: hasBg)),
                  Expanded(child: Center(child: SingleChildScrollView(child: form))),
                ],
              );
          }
        },
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.user,
    required this.pass,
    required this.obscure,
    required this.toggleObscure,
    required this.onSubmit,
    required this.loading,
    required this.theme,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController user;
  final TextEditingController pass;
  final bool obscure;
  final VoidCallback toggleObscure;
  final VoidCallback onSubmit;
  final bool loading;
  final ThemeSettings theme;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((theme.logoUrl ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(height: 48, child: Image.network(theme.logoUrl!, fit: BoxFit.contain)),
                ),
              Text(theme.appName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(t.signInToContinue, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),
              TextFormField(
                controller: user,
                decoration: InputDecoration(
                  labelText: t.usernameOrEmail,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: pass,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: t.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: toggleObscure,
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? t.required : null,
                onFieldSubmitted: (_) => onSubmit(),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: loading ? null : onSubmit,
                child: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(t.signIn),
              ),
              // Phase 4.19 — self-serve password reset entry point.
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading ? null : () => GoRouter.of(context).go('/forgot-password'),
                  // Page is at /forgot-password (public route, see app_router.dart).
                  child: const Text('Forgot password?'),
                ),
              ),
              Text(
                t.loginTagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.theme, required this.hasBg});
  final ThemeSettings theme;
  final bool hasBg;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final overlayColor = hexWithAlpha(theme.loginOverlayColor, theme.loginOverlayOpacity);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [hexToColor(theme.gradientFrom), hexToColor(theme.gradientTo)],
            ),
            image: hasBg
                ? DecorationImage(
                    image: NetworkImage(theme.backgroundImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        ),
        if (hasBg && theme.loginOverlayOpacity > 0)
          Container(color: overlayColor),
        Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if ((theme.logoUrl ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(height: 28, child: Image.network(theme.logoUrl!, fit: BoxFit.contain)),
                    )
                  else
                    const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    theme.appName,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.manageEveryBusiness,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1),
                  ),
                  Text(
                    t.inOnePlace,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.loginHeroSubtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                  ),
                ],
              ),
              Text(
                '© ${DateTime.now().year} ${theme.appName}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CenteredLogin extends StatelessWidget {
  const _CenteredLogin({required this.theme, required this.form, required this.hasBg});
  final ThemeSettings theme;
  final Widget form;
  final bool hasBg;

  @override
  Widget build(BuildContext context) {
    final overlayColor = hexWithAlpha(theme.loginOverlayColor, theme.loginOverlayOpacity);
    final cardColor = hexWithAlpha(theme.surface, theme.surfaceOpacity);
    final cardRadius = BorderRadius.circular(theme.cardRadius.toDouble());

    Widget card = ClipRRect(
      borderRadius: cardRadius,
      child: theme.enableGlass
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: theme.glassBlur.toDouble(), sigmaY: theme.glassBlur.toDouble()),
              child: Container(
                color: hexWithAlpha(theme.glassTint, theme.glassTintOpacity),
                child: form,
              ),
            )
          : Container(color: cardColor, child: form),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [hexToColor(theme.gradientFrom), hexToColor(theme.gradientTo)],
            ),
            image: hasBg
                ? DecorationImage(
                    image: NetworkImage(theme.backgroundImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        ),
        if (hasBg && theme.loginOverlayOpacity > 0)
          Container(color: overlayColor),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: card,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Phase 4.16 follow-up — modal that completes the 2FA login step.
// Asks for the current authenticator code (6 digits) by default; an
// "Use recovery code" link swaps the field over to free-form input
// for one of the 10 recovery codes saved at enrollment.
class _TotpChallengeDialog extends ConsumerStatefulWidget {
  const _TotpChallengeDialog({required this.challengeToken});
  final String challengeToken;

  @override
  ConsumerState<_TotpChallengeDialog> createState() => _TotpChallengeDialogState();
}

class _TotpChallengeDialogState extends ConsumerState<_TotpChallengeDialog> {
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
    final ok = await ref.read(authControllerProvider.notifier).redeemChallenge(
      challengeToken: widget.challengeToken,
      code: _useRecovery ? null : value,
      recoveryCode: _useRecovery ? value : null,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _err = ref.read(authControllerProvider).error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.twoFactorTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_useRecovery ? t.twoFactorRecoveryHint : t.twoFactorCodeHint,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: _useRecovery ? TextInputType.text : TextInputType.number,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 2),
              decoration: InputDecoration(
                labelText: _useRecovery ? t.recoveryCodeField : t.twoFactorCodeField,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
              enabled: !_busy,
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
        ElevatedButton(onPressed: _busy ? null : _submit, child: Text(_busy ? t.saving : t.signIn)),
      ],
    );
  }
}
