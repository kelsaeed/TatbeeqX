// Desktop / mobile implementation of the API-base-URL runtime
// override. The subsystem-manager start.bat sets
// TATBEEQX_API_BASE_URL before launching the bundled .exe so it can
// point at a non-default port (port-pool fallback) without a rebuild.
// Selected via the conditional import in app_config.dart when
// `dart.library.io` is available.
import 'dart:io' show Platform;

String? readApiBaseUrlOverride() {
  final v = Platform.environment['TATBEEQX_API_BASE_URL'];
  if (v != null && v.trim().isNotEmpty) return v.trim();
  return null;
}
