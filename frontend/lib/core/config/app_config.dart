import 'dart:io' show Platform;

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
  // baked in via --dart-define=API_BASE_URL=...
  static final String apiBaseUrl = _resolveApiBaseUrl();

  static String _resolveApiBaseUrl() {
    final override = Platform.environment['TATBEEQX_API_BASE_URL'];
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return _compiledApiBaseUrl;
  }

  static const String appName = 'TatbeeqX';

  static const Duration apiTimeout = Duration(seconds: 30);
}
