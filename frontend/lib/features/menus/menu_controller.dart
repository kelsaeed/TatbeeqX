import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';

class MenuItemNode {
  MenuItemNode({
    required this.id,
    required this.code,
    required this.label,
    required this.children,
    this.labels = const {},
    this.icon,
    this.route,
  });

  final int id;
  final String code;
  final String label;
  final Map<String, String> labels;
  final String? icon;
  final String? route;
  final List<MenuItemNode> children;

  /// Resolves the best label for the active locale, falling back to the
  /// English `label` column when a translation is missing.
  String labelFor(String localeCode) {
    final v = labels[localeCode];
    if (v != null && v.isNotEmpty) return v;
    return label;
  }

  factory MenuItemNode.fromJson(Map<String, dynamic> j) {
    final raw = (j['labels'] as Map?) ?? const {};
    final labels = <String, String>{};
    raw.forEach((k, v) {
      if (v is String && v.isNotEmpty) labels[k.toString()] = v;
    });
    return MenuItemNode(
      id: j['id'] as int,
      code: j['code'] as String,
      label: j['label'] as String,
      labels: labels,
      icon: j['icon'] as String?,
      route: j['route'] as String?,
      children: ((j['children'] as List?) ?? const [])
          .map((c) => MenuItemNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MenuState {
  MenuState({this.items = const [], this.loading = false, this.error});
  final List<MenuItemNode> items;
  final bool loading;
  final String? error;
}

class MenuController extends StateNotifier<MenuState> {
  MenuController(this._api) : super(MenuState());
  final ApiClient _api;

  Future<void> load() async {
    state = MenuState(loading: true);
    try {
      final res = await _api.getJson('/menus');
      final tree = _parseMenuTree(res['tree']);

      // Phase 4.1 — merge user-defined pages from /pages/sidebar
      // Items render via PageRenderer at /p/:code; we ignore the page's
      // free-form route for sidebar purposes to avoid go_router collisions.
      try {
        final pagesRes = await _api.getJson('/pages/sidebar');
        tree.addAll(_parseSidebarPages(pagesRes['items']));
      } catch (_) {
        // pages module might not be visible to this user — silently skip
      }

      state = MenuState(items: tree);
    } catch (e) {
      state = MenuState(error: e.toString());
    }
  }

  // Phase 4.20 — apply menu + sidebar-pages payload that came in via
  // /auth/me / /auth/login. Same merge logic as load() but no HTTP.
  // Caller hands us the raw JSON the auth response already parsed.
  void seedFromAuth(Map<String, dynamic> menusJson, List<Map<String, dynamic>>? sidebarPagesJson) {
    final tree = _parseMenuTree(menusJson['tree']);
    if (sidebarPagesJson != null) {
      tree.addAll(_parseSidebarPages(sidebarPagesJson));
    }
    state = MenuState(items: tree);
  }

  static List<MenuItemNode> _parseMenuTree(dynamic raw) =>
      (raw as List? ?? const [])
          .map((e) => MenuItemNode.fromJson(e as Map<String, dynamic>))
          .toList();

  static List<MenuItemNode> _parseSidebarPages(dynamic raw) =>
      (raw as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((p) => (p['code'] as String?)?.isNotEmpty ?? false)
          .map((p) => MenuItemNode(
                id: -1 * (p['id'] as int),
                code: 'page.${p['code']}',
                label: (p['title'] as String?) ?? (p['code'] as String? ?? 'Page'),
                icon: p['icon'] as String?,
                route: '/p/${p['code']}',
                children: const [],
              ))
          .toList();
}

final menuControllerProvider = StateNotifierProvider<MenuController, MenuState>((ref) {
  return MenuController(ref.watch(apiClientProvider));
});
