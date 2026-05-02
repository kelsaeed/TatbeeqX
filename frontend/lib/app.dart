import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      // Phase 4.12 — kick the subsystem-info fetch early so it's
      // resolved by the time the router does its first redirect.
      ref.read(subsystemInfoProvider);
      // Phase 4.16 follow-up — theme + auth bootstrap don't depend on
      // each other; run them in parallel to remove a full RTT from
      // cold-boot. setup.refresh() is NOT triggered here — the
      // ref.listen below catches the auth transition (loading →
      // authenticated) and fires setup.refresh once. Calling here too
      // produced a duplicate /api/business/setup hit on every cold
      // boot with a valid token.
      await Future.wait([
        ref.read(themeControllerProvider.notifier).loadActive(),
        ref.read(authControllerProvider.notifier).bootstrap(),
      ]);
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
        ref.read(setupControllerProvider.notifier).refresh();
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
