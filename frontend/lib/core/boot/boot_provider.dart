// Phase 4.20 — pre-auth bundle.
//
// The cold-boot path used to fire /api/subsystem/info AND
// /api/themes/active in parallel before the login screen could paint.
// `bootProvider` collapses both into a single GET /api/boot.
//
// Two consumers depend on the bundled result:
//   - subsystemInfoProvider (derived; see core/subsystem/subsystem_info.dart)
//   - ThemeController.applyBootTheme(...) — called from app.dart's
//     initState so the StateNotifier gets seeded without HTTP.
//
// If /api/boot is unreachable or returns garbage (older backend, network
// blip), we resolve to BootResult.empty and the app's existing fallback
// path picks up the slack — subsystemInfoProvider still has its empty
// default and ThemeController.loadActive() is invoked instead.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../subsystem/subsystem_info.dart';

class BootResult {
  const BootResult({required this.subsystem, this.themeJson, this.failed = false});

  final SubsystemInfo subsystem;
  // Raw theme row JSON ({ id, companyId, name, isDefault, isActive, data }).
  // Null when no theme is configured server-side. Parsed by the consumer
  // (ThemeController) so we don't pull ThemeSettings into core/boot.
  final Map<String, dynamic>? themeJson;
  // True when the fetch itself failed. Lets app.dart fall back to the
  // legacy per-endpoint path (subsystemInfoProvider already handles this
  // implicitly; the theme controller needs an explicit fallback).
  final bool failed;

  static const empty = BootResult(subsystem: SubsystemInfo.empty);
  static const failedDefault = BootResult(subsystem: SubsystemInfo.empty, failed: true);
}

/// Single shared boot fetch. Cached for the app's lifetime — Riverpod
/// resolves the future once and replays it for any subsequent reads.
final bootProvider = FutureProvider<BootResult>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final res = await api.getJson('/boot');
    final subsystemJson = (res['subsystem'] as Map?)?.cast<String, dynamic>() ?? const {};
    final themeJson = (res['theme'] as Map?)?.cast<String, dynamic>();
    return BootResult(
      subsystem: SubsystemInfo.fromJson(subsystemJson),
      themeJson: themeJson,
    );
  } catch (_) {
    return BootResult.failedDefault;
  }
});
