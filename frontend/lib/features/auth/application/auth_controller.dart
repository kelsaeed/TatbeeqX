import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

class AuthState {
  AuthState({
    this.user,
    this.permissions = const {},
    this.bootstrapped = false,
    this.loading = false,
    this.error,
    this.unreadNotifications,
    this.companies,
    this.menusJson,
    this.sidebarPagesJson,
  });

  final AuthUser? user;
  final Set<String> permissions;
  final bool bootstrapped;
  final bool loading;
  final String? error;
  // Phase 4.20 — seeded by /auth/login, /auth/2fa/challenge, /auth/me.
  // The notifications bell reads this on mount instead of issuing its
  // own boot-time GET /notifications/unread-count. Stays null when
  // the auth payload doesn't include it (older backends, refreshed
  // session via legacy /refresh — bell falls back to its 45s poll).
  final int? unreadNotifications;
  // Phase 4.20 — slim {id, name} company list for the topbar switcher.
  // Same null vs empty-list semantics as unreadNotifications.
  final List<Map<String, dynamic>>? companies;
  // Phase 4.20 — sidebar seeds. menusJson is `{ modules, tree }` from
  // /api/menus; sidebarPagesJson mirrors /api/pages/sidebar's items.
  // MenuController.seedFromAuth consumes both. Null = legacy backend;
  // shell falls back to MenuController.load().
  final Map<String, dynamic>? menusJson;
  final List<Map<String, dynamic>>? sidebarPagesJson;

  bool get isLoggedIn => user != null;

  bool can(String code) {
    if (user?.isSuperAdmin == true) return true;
    return permissions.contains(code);
  }

  AuthState copyWith({
    AuthUser? user,
    Set<String>? permissions,
    bool? bootstrapped,
    bool? loading,
    String? error,
    int? unreadNotifications,
    List<Map<String, dynamic>>? companies,
    Map<String, dynamic>? menusJson,
    List<Map<String, dynamic>>? sidebarPagesJson,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      permissions: permissions ?? this.permissions,
      bootstrapped: bootstrapped ?? this.bootstrapped,
      loading: loading ?? this.loading,
      error: error,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      companies: companies ?? this.companies,
      menusJson: menusJson ?? this.menusJson,
      sidebarPagesJson: sidebarPagesJson ?? this.sidebarPagesJson,
    );
  }
}

// Phase 4.16 follow-up — three-state result of a login attempt:
// success, 2FA challenge issued, or failure (with state.error set).
class LoginOutcome {
  const LoginOutcome._({required this.ok, this.challengeToken});
  factory LoginOutcome.success() => const LoginOutcome._(ok: true);
  factory LoginOutcome.failure() => const LoginOutcome._(ok: false);
  factory LoginOutcome.challenge(String token) => LoginOutcome._(ok: false, challengeToken: token);

  final bool ok;
  final String? challengeToken;
  bool get requires2FA => challengeToken != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._api) : super(AuthState());

  final AuthRepository _repo;
  final ApiClient _api;

  Future<void> bootstrap() async {
    final hasToken = (_api.storage.accessToken ?? '').isNotEmpty;
    if (!hasToken) {
      state = state.copyWith(bootstrapped: true);
      return;
    }
    try {
      final session = await _repo.me();
      state = AuthState(
        user: session.user,
        permissions: session.permissions,
        bootstrapped: true,
        unreadNotifications: session.unreadNotifications,
        companies: session.companies,
        menusJson: session.menusJson,
        sidebarPagesJson: session.sidebarPagesJson,
      );
    } catch (_) {
      await _repo.logout();
      state = AuthState(bootstrapped: true);
    }
  }

  // Phase 4.16 follow-up — login can return a session OR a 2FA
  // challenge. Returns one of:
  //   - LoginOk(true): full session, state updated.
  //   - LoginOk(challengeToken): 2FA challenge — caller should
  //     prompt for a code and call `redeemChallenge`.
  //   - LoginOk(false): failure, state.error set.
  Future<LoginOutcome> login({required String username, required String password}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.login(username: username, password: password);
      if (result is LoginChallenge) {
        // Don't change auth state — the user isn't logged in yet.
        state = state.copyWith(loading: false);
        return LoginOutcome.challenge(result.challengeToken);
      }
      final session = (result as LoginSession).session;
      state = AuthState(
        user: session.user,
        permissions: session.permissions,
        bootstrapped: true,
        unreadNotifications: session.unreadNotifications,
        companies: session.companies,
        menusJson: session.menusJson,
        sidebarPagesJson: session.sidebarPagesJson,
      );
      return LoginOutcome.success();
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return LoginOutcome.failure();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return LoginOutcome.failure();
    }
  }

  Future<bool> redeemChallenge({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final session = await _repo.redeemChallenge(
        challengeToken: challengeToken,
        code: code,
        recoveryCode: recoveryCode,
      );
      state = AuthState(
        user: session.user,
        permissions: session.permissions,
        bootstrapped: true,
        unreadNotifications: session.unreadNotifications,
        companies: session.companies,
        menusJson: session.menusJson,
        sidebarPagesJson: session.sidebarPagesJson,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  // Phase 4.16 follow-up — refresh `state.user` from `/auth/me`
  // without clobbering the `bootstrapped` flag. Used after toggling
  // 2FA so the Security UI reflects the new totpEnabled value.
  Future<void> refreshMe() async {
    try {
      final session = await _repo.me();
      state = AuthState(
        user: session.user,
        permissions: session.permissions,
        bootstrapped: true,
        unreadNotifications: session.unreadNotifications,
        companies: session.companies,
        menusJson: session.menusJson,
        sidebarPagesJson: session.sidebarPagesJson,
      );
    } catch (_) { /* leave state intact on transient failure */ }
  }

  Future<void> logout({bool everywhere = false}) async {
    await _repo.logout(everywhere: everywhere);
    state = AuthState(bootstrapped: true);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref.watch(apiClientProvider));
});
