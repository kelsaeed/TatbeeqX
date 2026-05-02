class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.details});

  final int statusCode;
  final String message;
  final Object? details;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
