// Phase 4.12 — locked-down subsystem builds.
//
// Reads the public `/api/subsystem/info` endpoint once at boot. The
// response tells the UI:
//   - `lockdown`: whether to hide super-admin surfaces from sidebar /
//     router. The backend's permission checks are still authoritative;
//     this flag is for clean UX in customer-shipped binaries.
//   - `modules`: which features the active template declared. Today
//     used as informational; v2 will drive code-gen pruning of unused
//     feature folders (see Phase 4.12 plan).
//   - `hiddenModules`: route-segments to hide / redirect away from
//     when in lockdown.
//   - `branding`: overrides for app name / logo / primary color, baked
//     into the customer's binary by the build script.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class SubsystemBranding {
  const SubsystemBranding({this.appName, this.logoUrl, this.primaryColor});

  final String? appName;
  final String? logoUrl;
  final String? primaryColor;

  factory SubsystemBranding.fromJson(Map<String, dynamic> j) => SubsystemBranding(
        appName: j['appName']?.toString(),
        logoUrl: j['logoUrl']?.toString(),
        primaryColor: j['primaryColor']?.toString(),
      );
}

class SubsystemInfo {
  const SubsystemInfo({
    this.lockdown = false,
    this.modules = const [],
    this.hiddenModules = const [],
    this.branding,
  });

  final bool lockdown;
  final List<String> modules;
  final List<String> hiddenModules;
  final SubsystemBranding? branding;

  /// Returns true when the given top-level route segment (e.g. "system",
  /// "database") should be hidden from the sidebar AND blocked by the
  /// router redirect.
  bool isHidden(String moduleCode) =>
      lockdown && hiddenModules.contains(moduleCode);

  /// Returns true when a path under the lockdown should be redirected
  /// away. Matches `/system`, `/system-logs`, `/database`, etc.
  bool isPathBlocked(String path) {
    if (!lockdown) return false;
    for (final m in hiddenModules) {
      if (path == '/$m' || path.startsWith('/$m/')) return true;
    }
    return false;
  }

  factory SubsystemInfo.fromJson(Map<String, dynamic> j) {
    final modules = (j['modules'] as List? ?? const []).map((e) => e.toString()).toList();
    final hidden = (j['hiddenModules'] as List? ?? const []).map((e) => e.toString()).toList();
    final brandingJson = j['branding'];
    return SubsystemInfo(
      lockdown: (j['lockdown'] as bool?) ?? false,
      modules: modules,
      hiddenModules: hidden,
      branding: brandingJson is Map<String, dynamic>
          ? SubsystemBranding.fromJson(brandingJson)
          : null,
    );
  }

  static const empty = SubsystemInfo();
}

/// Loads the subsystem info exactly once at app start. The endpoint is
/// public, so this fires before any auth state — making the result
/// usable for branding the login screen.
final subsystemInfoProvider = FutureProvider<SubsystemInfo>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final res = await api.getJson('/subsystem/info');
    return SubsystemInfo.fromJson(res);
  } catch (_) {
    // If the endpoint isn't reachable yet (server starting), default to
    // unlocked. The redirect logic in app_router treats AsyncValue.loading
    // as "no lockdown", so the user never gets stuck on a black screen.
    return SubsystemInfo.empty;
  }
});
