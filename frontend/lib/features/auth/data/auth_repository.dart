import '../../../core/network/api_client.dart';
import '../domain/auth_user.dart';

class AuthSession {
  AuthSession({required this.user, required this.permissions});

  final AuthUser user;
  final Set<String> permissions;
}

// Phase 4.16 follow-up — login can return either a full session or
// a 2FA challenge. The auth controller dispatches accordingly.
sealed class LoginResult {
  const LoginResult();
}

class LoginSession extends LoginResult {
  const LoginSession(this.session);
  final AuthSession session;
}

class LoginChallenge extends LoginResult {
  const LoginChallenge(this.challengeToken);
  final String challengeToken;
}

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<LoginResult> login({required String username, required String password}) async {
    final res = await _api.postJson('/auth/login', body: {
      'username': username,
      'password': password,
    });
    if (res['requires2FA'] == true) {
      return LoginChallenge(res['challengeToken'].toString());
    }
    final access = res['accessToken'] as String;
    final refresh = res['refreshToken'] as String;
    await _api.storage.save(accessToken: access, refreshToken: refresh);
    return LoginSession(_toSession(res));
  }

  // Phase 4.16 follow-up — redeem a 2FA challenge token with either a
  // current TOTP code or a one-time recovery code. Returns the full
  // session on success.
  Future<AuthSession> redeemChallenge({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) async {
    final body = <String, dynamic>{'challengeToken': challengeToken};
    if (code != null && code.isNotEmpty) body['code'] = code;
    if (recoveryCode != null && recoveryCode.isNotEmpty) body['recoveryCode'] = recoveryCode;
    final res = await _api.postJson('/auth/2fa/challenge', body: body);
    final access = res['accessToken'] as String;
    final refresh = res['refreshToken'] as String;
    await _api.storage.save(accessToken: access, refreshToken: refresh);
    return _toSession(res);
  }

  Future<AuthSession> me() async {
    final res = await _api.getJson('/auth/me');
    return _toSession(res);
  }

  Future<void> logout({bool everywhere = false}) async {
    // Phase 4.16 follow-up — call the backend so the audit log gets
    // the logout entry and the refresh token gets revoked server-side
    // (Phase 4.16 added the RefreshToken table). Pass `everywhere:
    // true` to revoke every active refresh token for this user (the
    // "log out from all devices" panic button). If the call fails
    // (network down, already-stale token), still clear local storage
    // so the UI returns to login.
    final refresh = _api.storage.refreshToken;
    try {
      await _api.postJson('/auth/logout', body: {
        if (refresh != null && refresh.isNotEmpty) 'refreshToken': refresh,
        if (everywhere) 'everywhere': true,
      });
    } catch (_) { /* best-effort */ }
    await _api.storage.clear();
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _api.postJson('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  AuthSession _toSession(Map<String, dynamic> res) {
    final user = AuthUser.fromJson(res['user'] as Map<String, dynamic>);
    final perms = (res['permissions'] as List? ?? const []).map((e) => e.toString()).toSet();
    return AuthSession(user: user, permissions: perms);
  }
}
