// Web / no-`dart:io` fallback for the API-base-URL runtime override.
//
// The web build has no process environment, so the
// TATBEEQX_API_BASE_URL override (used by the subsystem-manager
// start.bat to redirect a bundled .exe at a non-default port) never
// applies here. Callers fall back to the compile-time --dart-define
// value. Selected via the conditional import in app_config.dart when
// `dart.library.io` is NOT available.
String? readApiBaseUrlOverride() => null;
