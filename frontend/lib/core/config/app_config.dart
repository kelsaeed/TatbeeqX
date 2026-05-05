class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4040/api',
  );

  static const String appName = 'TatbeeqX';

  static const Duration apiTimeout = Duration(seconds: 30);
}
