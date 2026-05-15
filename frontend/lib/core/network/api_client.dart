import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

export 'api_exception.dart';

class ApiClient {
  ApiClient(this._storage)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.apiConnectTimeout,
            receiveTimeout: AppConfig.apiReceiveTimeout,
            sendTimeout: AppConfig.apiReceiveTimeout,
            headers: {'Content-Type': 'application/json'},
            validateStatus: (s) => s != null && s < 500,
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final status = response.statusCode ?? 0;
          // Phase 4.16 follow-up — automatic token refresh on 401.
          // Catches expired access tokens transparently: try /auth/refresh
          // with the stored refresh token, persist the new pair, and
          // retry the original request once. If refresh fails or the
          // request is itself an auth route, clear tokens and let the
          // caller see the error so the router can boot to /login.
          if (status == 401 && _shouldTryRefresh(response.requestOptions)) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final retry = await dio.fetch(response.requestOptions);
                handler.resolve(retry);
                return;
              } catch (_) { /* fall through to error path */ }
            } else {
              await _storage.clear();
            }
          }
          if (status >= 400) {
            final data = response.data;
            final message = data is Map && data['error'] is Map
                ? (data['error']['message'] ?? 'Request failed').toString()
                : 'Request failed (HTTP $status)';
            final details = data is Map && data['error'] is Map ? data['error']['details'] : null;
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: ApiException(statusCode: status, message: message, details: details),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.next(response);
        },
      ),
    );
  }

  // Skip auto-refresh for auth routes themselves — refreshing a refresh
  // request would loop, and login 401s mean "wrong password", not
  // "stale token".
  bool _shouldTryRefresh(RequestOptions opts) {
    final p = opts.path;
    if (p.endsWith('/auth/refresh') || p.endsWith('/auth/login')) return false;
    final refresh = _storage.refreshToken;
    return refresh != null && refresh.isNotEmpty;
  }

  // Single-flight refresh — concurrent 401s share one /auth/refresh call.
  Future<bool>? _refreshInflight;

  Future<bool> _tryRefresh() {
    return _refreshInflight ??= _doRefresh().whenComplete(() {
      _refreshInflight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refresh = _storage.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      // Bypass the interceptor on this call — fresh Dio instance, no
      // Authorization header, so a 401 here doesn't recurse.
      // Bare Dio has NO timeouts by default (infinite). Without these a
      // 401 on a dead/wrong-port backend would hang the refresh — and
      // every request that triggered it — forever.
      final raw = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiConnectTimeout,
        receiveTimeout: AppConfig.apiReceiveTimeout,
        validateStatus: (s) => s != null && s < 500,
      ));
      final res = await raw.post('/auth/refresh', data: {'refreshToken': refresh});
      if (res.statusCode != 200) return false;
      final data = res.data;
      if (data is! Map) return false;
      final newAccess = data['accessToken']?.toString();
      final newRefresh = data['refreshToken']?.toString();
      if (newAccess == null || newAccess.isEmpty) return false;
      await _storage.save(accessToken: newAccess, refreshToken: newRefresh ?? refresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  final Dio dio;
  final TokenStorage _storage;

  TokenStorage get storage => _storage;

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    final r = await _safe(() => dio.get(path, queryParameters: query));
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    final r = await _safe(() => dio.post(path, data: body));
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> putJson(String path, {Object? body}) async {
    final r = await _safe(() => dio.put(path, data: body));
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final r = await _safe(() => dio.delete(path));
    return _asMap(r.data);
  }

  Future<Response<dynamic>> _safe(Future<Response<dynamic>> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      final isConn = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown;
      throw ApiException(
        statusCode: e.response?.statusCode ?? 0,
        message: isConn
            ? 'Cannot reach the server at ${AppConfig.apiBaseUrl}. Is the backend running?'
            : (e.message ?? 'Network error'),
      );
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return {'data': data};
  }
}
