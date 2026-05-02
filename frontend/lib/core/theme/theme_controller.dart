import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../providers.dart';
import 'theme_settings.dart';

class ThemeState {
  ThemeState({required this.settings, this.activeThemeId, this.loading = false, this.error});

  final ThemeSettings settings;
  final int? activeThemeId;
  final bool loading;
  final String? error;

  ThemeState copyWith({
    ThemeSettings? settings,
    int? activeThemeId,
    bool? loading,
    String? error,
  }) {
    return ThemeState(
      settings: settings ?? this.settings,
      activeThemeId: activeThemeId ?? this.activeThemeId,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController(this._api) : super(ThemeState(settings: const ThemeSettings()));

  final ApiClient _api;

  Future<void> loadActive({int? companyId}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.getJson(
        '/themes/active',
        query: companyId != null ? {'companyId': companyId} : null,
      );
      final t = res['theme'];
      if (t is Map<String, dynamic>) {
        final data = (t['data'] is Map) ? Map<String, dynamic>.from(t['data'] as Map) : <String, dynamic>{};
        state = ThemeState(
          settings: ThemeSettings.fromJson(data),
          activeThemeId: t['id'] as int?,
        );
      } else {
        state = ThemeState(settings: const ThemeSettings());
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void applyLocal(ThemeSettings next) {
    state = state.copyWith(settings: next);
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>((ref) {
  return ThemeController(ref.watch(apiClientProvider));
});
