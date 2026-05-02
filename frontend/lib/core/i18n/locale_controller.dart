import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Phase 4.5 — locale state held in TokenStorage so it persists across runs.
///
/// We don't ship translation ARBs yet — this controller exists so the UI
/// flips between LTR and RTL when the user picks Arabic, and so date /
/// number formatting via `intl` switches to the chosen locale. String
/// translation can be added later by introducing `gen_l10n`.

const supportedLocales = <Locale>[
  Locale('en'),
  Locale('ar'),
  Locale('fr'),
];

class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._storage) : super(const Locale('en')) {
    _bootstrap();
  }

  final dynamic _storage; // TokenStorage

  static const _key = 'locale';

  Future<void> _bootstrap() async {
    try {
      final saved = await _storage.readKey(_key);
      if (saved is String && saved.isNotEmpty) {
        state = Locale(saved);
      }
    } catch (_) {
      // first-run / storage miss — keep default
    }
  }

  Future<void> setLocale(Locale next) async {
    state = next;
    try {
      await _storage.writeKey(_key, next.languageCode);
    } catch (_) {
      // best-effort persistence
    }
  }
}

final localeControllerProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController(ref.watch(tokenStorageProvider));
});
