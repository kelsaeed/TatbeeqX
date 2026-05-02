import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';

class BusinessState {
  BusinessState({required this.configured, this.businessType, this.customEntityCount = 0});

  final bool configured;
  final String? businessType;
  final int customEntityCount;

  factory BusinessState.fromJson(Map<String, dynamic> j) => BusinessState(
        configured: (j['configured'] as bool?) ?? false,
        businessType: j['businessType'] as String?,
        customEntityCount: (j['customEntityCount'] as int?) ?? 0,
      );
}

class SetupController extends StateNotifier<AsyncValue<BusinessState>> {
  SetupController(this._api) : super(const AsyncValue.loading());
  final ApiClient _api;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.getJson('/business/state');
      state = AsyncValue.data(BusinessState.fromJson(res));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Map<String, dynamic>>> listPresets() async {
    final res = await _api.getJson('/business/presets');
    return (res['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> apply(String code) async {
    await _api.postJson('/business/apply', body: {'code': code});
    await refresh();
  }
}

final setupControllerProvider =
    StateNotifierProvider<SetupController, AsyncValue<BusinessState>>((ref) {
  return SetupController(ref.watch(apiClientProvider));
});
