import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/boot/boot_provider.dart';
import 'core/i18n/locale_controller.dart';
import 'core/subsystem/subsystem_info.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_data_builder.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/setup/setup_controller.dart';
import 'l10n/gen/app_localizations.dart';
import 'routing/app_router.dart';

class TatbeeqXApp extends ConsumerStatefulWidget {
  const TatbeeqXApp({super.key});

  @override
  ConsumerState<TatbeeqXApp> createState() => _TatbeeqXAppState();
}

class _TatbeeqXAppState extends ConsumerState<TatbeeqXApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // First paint must NOT wait on the network. The router's redirect
      // gate is `auth.bootstrapped`; until that flips, the app is stuck
      // on the initial /dashboard route and the login screen can't
      // appear. bootstrap() is instant when there's no stored token and
      // is the ONLY thing that gate needs — so run it first and on its
      // own. Previously it ran last, behind `await /boot` (≤30s) and,
      // on failure, `await /themes/active` (another ≤30s): an
      // unreachable or wrong-port backend froze the window for up to a
      // minute before login could even render ("Not Responding").
      final bootstrapDone =
          ref.read(authControllerProvider.notifier).bootstrap();

      // Phase 4.20 — single pre-auth bundle. /api/boot returns subsystem
      // info + active theme in one round-trip; subsystemInfoProvider
      // derives from the same bootProvider. This now hydrates in the
      // BACKGROUND (no await on the first-paint path): the UI renders
      // with theme defaults immediately and restyles when /boot lands.
      // Falls back to /themes/active only if the bundle itself errored.
      // setup.refresh() is NOT triggered here — the ref.listen below
      // catches the auth transition and fires it once.
      unawaited(ref.read(bootProvider.future).then((boot) {
        if (!boot.failed) {
          ref.read(themeControllerProvider.notifier).applyBootTheme(boot.themeJson);
        } else {
          unawaited(ref.read(themeControllerProvider.notifier).loadActive());
        }
      }));

      await bootstrapDone;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final router = ref.watch(routerProvider);
    final subsystem = ref.watch(subsystemInfoProvider).valueOrNull
        ?? SubsystemInfo.empty;
    ref.listen(authControllerProvider, (prev, next) {
      if (next.isLoggedIn && (prev == null || !prev.isLoggedIn)) {
        // Phase 4.20 — seed from the auth payload when present so we
        // don't fire /api/business/state on every login. Falls back to
        // refresh() only on legacy backends or when the seed is missing.
        final seed = next.businessJson;
        if (seed != null) {
          ref.read(setupControllerProvider.notifier).seedFromAuth(seed);
        } else {
          ref.read(setupControllerProvider.notifier).refresh();
        }
      }
    });

    final locale = ref.watch(localeControllerProvider);

    // Phase 4.12 — branding overrides from the locked-down subsystem
    // info take precedence over the active theme's app name + logo +
    // primary color. The build script bakes these into the customer's
    // binary via the template.
    final settings = subsystem.branding == null
        ? themeState.settings
        : themeState.settings.copyWith({
            if (subsystem.branding!.appName != null) 'appName': subsystem.branding!.appName,
            if (subsystem.branding!.logoUrl != null) 'logoUrl': subsystem.branding!.logoUrl,
            if (subsystem.branding!.primaryColor != null) 'primary': subsystem.branding!.primaryColor,
          });

    return MaterialApp.router(
      title: settings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppThemeBuilder.build(settings),
      routerConfig: router,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
