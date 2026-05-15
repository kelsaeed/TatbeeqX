// Conditional import: on web (`dart.library.io` absent) this resolves
// to env_reader_stub.dart (returns null — no process env on web); on
// desktop/mobile it resolves to env_reader_io.dart which reads
// Platform.environment. Keeps `dart:io` out of the web build, which
// can't compile it (regression fixed after Phase 4.20 (Phase 1)).
import 'env_reader_stub.dart' if (dart.library.io) 'env_reader_io.dart';

class AppConfig {
  AppConfig._();

  static const String _compiledApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4040/api',
  );

  // Runtime override lets `start.bat` redirect the bundled .exe at a
  // different port without rebuilding — needed when the build-subsystem
  // tool ships a `--port-pool` bundle and the primary port turns out to
  // be busy on the customer host. Falls back to the compile-time value
  // baked in via --dart-define=API_BASE_URL=... On web the override is
  // always null (no process environment), so this is just the
  // compile-time value there.
  static final String apiBaseUrl =
      readApiBaseUrlOverride() ?? _compiledApiBaseUrl;

  static const String appName = 'TatbeeqX';

  // Connecting is fast on a healthy LAN/localhost backend (single-digit
  // ms). A long connect timeout only ever hurts: when the backend is
  // down, on the wrong port, or starved (e.g. AV-throttled), every
  // request — including the boot/auth calls behind first paint — would
  // otherwise hang the UI for the full window. 5s is generous for a
  // reachable server and quick to surface "backend not running".
  static const Duration apiConnectTimeout = Duration(seconds: 5);

  // Receive can legitimately be slow: /audit and /system-logs return
  // MB-scale payloads. Keep this generous.
  static const Duration apiReceiveTimeout = Duration(seconds: 30);
}
