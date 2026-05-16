import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/command_palette.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../../core/providers.dart';
import '../../../core/subsystem/subsystem_info.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_settings.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../../../shared/widgets/icon_lookup.dart';
import '../../auth/application/auth_controller.dart';
import '../../menus/menu_controller.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    // Phase 4.20 — seed the sidebar from the auth payload when the
    // backend bundled it (current path). Falls back to a fresh
    // /menus + /pages/sidebar fetch only on legacy backends or when
    // the seed is missing for some other reason.
    //
    // Both branches mutate MenuController.state, so both must be
    // deferred off initState's synchronous path — Riverpod throws
    // "Tried to modify a provider while the widget tree was building"
    // otherwise (initState runs inside _firstBuild). The mounted guard
    // covers a fast logout→login where this State is disposed before
    // the microtask drains.
    final authState = ref.read(authControllerProvider);
    final menusSeed = authState.menusJson;
    final sidebarPages = authState.sidebarPagesJson;
    Future.microtask(() {
      if (!mounted) return;
      final menus = ref.read(menuControllerProvider.notifier);
      if (menusSeed != null) {
        menus.seedFromAuth(menusSeed, sidebarPages);
      } else {
        menus.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phase 4.20 perf — narrow watches with select() so the shell
    // doesn't rebuild on every transient AuthState / ThemeState
    // change (loading flips, error flickers, the 45 s
    // unreadNotifications poll tick that updates the bell seed in
    // AuthState). The shell only reads `user` and `theme.settings`.
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final menuState = ref.watch(menuControllerProvider);
    final theme = ref.watch(themeControllerProvider.select((s) => s.settings));
    final subsystem = ref.watch(subsystemInfoProvider).valueOrNull
        ?? SubsystemInfo.empty;
    final cs = Theme.of(context).colorScheme;

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    final localeCode = ref.watch(localeControllerProvider).languageCode;

    // Phase 4.12 — in lockdown, strip menu items whose route matches a
    // hidden module. Permission-driven filtering still happens in the
    // backend's /api/menus query; this is a second-pass UX clean for
    // vendor super-admin support sessions.
    final visibleItems = subsystem.lockdown
        ? menuState.items.where((m) {
            final route = m.route ?? '';
            for (final h in subsystem.hiddenModules) {
              if (route == '/$h' || route.startsWith('/$h/')) return false;
            }
            return true;
          }).toList()
        : menuState.items;

    final sidebar = _Sidebar(
      collapsed: _collapsed && !isMobile,
      items: visibleItems,
      currentPath: GoRouterState.of(context).uri.path,
      sidebarColor: hexWithAlpha(theme.sidebar, theme.sidebarOpacity),
      sidebarText: hexToColor(theme.sidebarText),
      appName: theme.appName,
      isSuperAdmin: user?.isSuperAdmin ?? false,
      localeCode: localeCode,
      enableGlass: theme.enableGlass,
      glassBlur: theme.glassBlur.toDouble(),
      glassTint: hexWithAlpha(theme.glassTint, theme.glassTintOpacity),
      onSelect: (route) {
        if (isMobile) Navigator.of(context).maybePop();
        context.go(route);
      },
      onToggle: () => setState(() => _collapsed = !_collapsed),
    );

    final hasBg = (theme.backgroundImageUrl ?? '').isNotEmpty;
    final bgOverlay = hexWithAlpha(theme.backgroundOverlayColor, theme.backgroundOverlayOpacity);
    final blurSigma = theme.backgroundBlur.toDouble();

    final shellBody = Row(
      children: [
        if (!isMobile) sidebar,
        Expanded(
          child: Column(
            children: [
              _TopBar(
                user: user,
                onLogout: ({bool everywhere = false}) async {
                  final router = GoRouter.of(context);
                  await ref.read(authControllerProvider.notifier).logout(everywhere: everywhere);
                  router.go('/login');
                },
                showMenuButton: isMobile,
                onMenu: () => Scaffold.of(context).openDrawer(),
                topbarColor: hexWithAlpha(theme.topbar, theme.topbarOpacity),
              ),
              const Divider(height: 1),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ],
    );

    final scaffold = Scaffold(
      backgroundColor: cs.surface,
      drawer: isMobile ? Drawer(child: sidebar) : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBg)
            Opacity(
              opacity: theme.backgroundOpacity.toDouble().clamp(0.0, 1.0),
              child: Image.network(theme.backgroundImageUrl!, fit: BoxFit.cover),
            ),
          if (hasBg && blurSigma > 0)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: const SizedBox.expand(),
            ),
          if (hasBg && theme.backgroundOverlayOpacity > 0)
            Container(color: bgOverlay),
          shellBody,
        ],
      ),
    );

    // Ctrl/Cmd-K opens the quick switcher from anywhere in the app.
    // CallbackShortcuts catches the chord as it bubbles up the focus
    // tree; the wrapping Focus(autofocus) guarantees there's always a
    // focused node so the shortcut fires even on a page with no
    // focused field.
    void openPalette() {
      showCommandPalette(
        context,
        _paletteCommands(context, menuState.items, localeCode),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            openPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            openPalette,
      },
      child: Focus(autofocus: true, child: scaffold),
    );
  }

  // Flatten the menu tree into jump targets. Parent labels become the
  // dimmed `group` tag so e.g. two "Settings"-ish entries are
  // distinguishable in the palette.
  List<CommandItem> _paletteCommands(
    BuildContext context,
    List items,
    String locale,
  ) {
    final out = <CommandItem>[];
    void walk(List<MenuItemNode> nodes, String? group) {
      for (final n in nodes) {
        if (n.children.isNotEmpty) {
          walk(n.children, n.labelFor(locale));
        } else {
          final r = n.route;
          if (r == null || r.isEmpty) continue;
          out.add(CommandItem(
            label: n.labelFor(locale),
            group: group,
            icon: iconFromName(n.icon),
            onSelect: () => context.go(r),
          ));
        }
      }
    }

    walk(items.cast<MenuItemNode>(), null);
    return out;
  }
}

// Renders the menu *tree*. The old version walked one level deep and
// `SizedBox.shrink()`'d any route-less node, so a server-sent group
// (a parent with children but no route of its own) — and everything
// under it — silently vanished from the sidebar. Now: leaves are nav
// tiles, parents are collapsible section headers, nesting recurses.
// A flat list (no children anywhere) renders exactly as before, so a
// flat /api/menus payload is unaffected. Groups are expanded by
// default (nothing hidden); the user can collapse the ones they don't
// use, and a group containing the active route force-expands so the
// current page is always visible.
class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.collapsed,
    required this.items,
    required this.currentPath,
    required this.sidebarColor,
    required this.sidebarText,
    required this.appName,
    required this.isSuperAdmin,
    required this.onSelect,
    required this.onToggle,
    this.localeCode = 'en',
    this.enableGlass = false,
    this.glassBlur = 12,
    this.glassTint = const Color(0x99FFFFFF),
  });

  final bool collapsed;
  final List items;
  final String currentPath;
  final Color sidebarColor;
  final Color sidebarText;
  final String appName;
  final bool isSuperAdmin;
  final String localeCode;
  final bool enableGlass;
  final double glassBlur;
  final Color glassTint;
  final void Function(String route) onSelect;
  final VoidCallback onToggle;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  // Group codes the user has explicitly collapsed. Absence ⇒ expanded,
  // so a fresh session shows everything (no discoverability hit) and
  // the State persists across shell rebuilds (navigation) since the
  // widget keeps its slot in the tree.
  final Set<String> _collapsed = {};

  List<MenuItemNode> get _nodes => widget.items.cast<MenuItemNode>();

  bool _isGroup(MenuItemNode n) => n.children.isNotEmpty;

  bool _subtreeActive(MenuItemNode n) {
    final r = n.route;
    if (r != null && r.isNotEmpty && widget.currentPath.startsWith(r)) {
      return true;
    }
    for (final c in n.children) {
      if (_subtreeActive(c)) return true;
    }
    return false;
  }

  void _collectLeaves(List<MenuItemNode> nodes, List<MenuItemNode> out) {
    for (final n in nodes) {
      if (_isGroup(n)) {
        _collectLeaves(n.children, out);
      } else if ((n.route ?? '').isNotEmpty) {
        out.add(n);
      }
    }
  }

  List<Widget> _buildNodes(List<MenuItemNode> nodes, int depth) {
    final out = <Widget>[];
    for (final n in nodes) {
      if (_isGroup(n)) {
        final active = _subtreeActive(n);
        final expanded = active || !_collapsed.contains(n.code);
        out.add(_GroupTile(
          icon: iconFromName(n.icon),
          label: n.labelFor(widget.localeCode),
          depth: depth,
          expanded: expanded,
          active: active,
          text: widget.sidebarText,
          // Force-expanded by an active child can't be collapsed away
          // (it'd re-open instantly) — toggling is a no-op there, which
          // is the right behavior: don't hide the current page.
          onToggle: () => setState(() {
            if (_collapsed.contains(n.code)) {
              _collapsed.remove(n.code);
            } else {
              _collapsed.add(n.code);
            }
          }),
        ));
        if (expanded) out.addAll(_buildNodes(n.children, depth + 1));
      } else {
        final route = n.route;
        if (route == null || route.isEmpty) continue;
        out.add(_NavTile(
          icon: iconFromName(n.icon),
          label: n.labelFor(widget.localeCode),
          depth: depth,
          collapsed: false,
          selected: widget.currentPath.startsWith(route),
          text: widget.sidebarText,
          onTap: () => widget.onSelect(route),
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    final sidebarText = widget.sidebarText;
    final width = collapsed ? 72.0 : 248.0;

    final List<Widget> navChildren;
    if (collapsed) {
      // Icon rail: section headers make no sense at 72px, so flatten
      // to leaf icons (the prior behavior at this width).
      final leaves = <MenuItemNode>[];
      _collectLeaves(_nodes, leaves);
      navChildren = [
        for (final n in leaves)
          _NavTile(
            icon: iconFromName(n.icon),
            label: n.labelFor(widget.localeCode),
            depth: 0,
            collapsed: true,
            selected: widget.currentPath.startsWith(n.route ?? ' '),
            text: sidebarText,
            onTap: () => widget.onSelect(n.route!),
          ),
      ];
    } else {
      navChildren = _buildNodes(_nodes, 0);
    }

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: collapsed
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 18)
              : const EdgeInsets.fromLTRB(16, 18, 12, 18),
          child: collapsed
              ? Center(
                  child: IconButton(
                    onPressed: widget.onToggle,
                    icon: Icon(Icons.chevron_right, color: sidebarText, size: 20),
                    splashRadius: 18,
                    tooltip: 'Expand',
                  ),
                )
              : Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: sidebarText, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.appName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: sidebarText, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onToggle,
                      icon: Icon(Icons.chevron_left, color: sidebarText, size: 20),
                      splashRadius: 18,
                      tooltip: 'Collapse',
                    ),
                  ],
                ),
        ),
        Divider(color: sidebarText.withValues(alpha: 0.12), height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: navChildren,
          ),
        ),
        Divider(color: sidebarText.withValues(alpha: 0.12), height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Text(
            collapsed ? 'v0.1' : 'TatbeeqX • v0.1',
            style: TextStyle(color: sidebarText.withValues(alpha: 0.6), fontSize: 11),
          ),
        ),
      ],
    );

    // Lay the panel out at its TARGET width and let the
    // AnimatedContainer clip it while the width animates. Otherwise the
    // expanded header Row's fixed children (icon 22 + gap 10 + collapse
    // button 40 = 72) get re-fit to the intermediate ~44px width on
    // every expand and overflow by 28px. OverflowBox pins the content
    // to the leading edge (directional, so RTL reveals from the right)
    // so the transition is a clean slide instead of a reflow.
    final body = OverflowBox(
      minWidth: width,
      maxWidth: width,
      alignment: AlignmentDirectional.centerStart,
      child: inner,
    );

    if (widget.enableGlass) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.glassBlur, sigmaY: widget.glassBlur),
            child: Container(color: widget.glassTint, child: body),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: widget.sidebarColor,
      child: ClipRect(child: body),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.text,
    required this.onTap,
    this.depth = 0,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final Color text;
  final VoidCallback onTap;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? text.withValues(alpha: 0.10) : Colors.transparent;
    final fg = selected ? text : text.withValues(alpha: 0.78);
    // Nested items get a left inset so the hierarchy reads at a glance.
    final indent = collapsed ? 0.0 : depth * 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(8 + indent, 2, 8, 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 18),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, fontSize: 13.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Collapsible section header for a menu parent. Distinct from a leaf:
// it never navigates, it expands/collapses its children. The chevron
// + slightly heavier label signal "this opens", and an active subtree
// tints it so you can see where the current page lives.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.icon,
    required this.label,
    required this.depth,
    required this.expanded,
    required this.active,
    required this.text,
    required this.onToggle,
  });

  final IconData icon;
  final String label;
  final int depth;
  final bool expanded;
  final bool active;
  final Color text;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final fg = active ? text : text.withValues(alpha: 0.70);
    final indent = depth * 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(8 + indent, 2, 8, 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggle,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? text.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.chevron_right,
                    color: text.withValues(alpha: 0.5), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Phase 4.20 perf — was ConsumerWidget but never reads ref. Demoted
// to StatelessWidget so it doesn't subscribe to anything.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.user,
    required this.onLogout,
    required this.showMenuButton,
    required this.onMenu,
    this.topbarColor,
  });

  final dynamic user;
  // Phase 4.16 follow-up — accepts {everywhere} so the "log out from
  // all devices" menu item can flow through to the backend's
  // /auth/logout `everywhere: true` mode.
  final void Function({bool everywhere}) onLogout;
  final bool showMenuButton;
  final VoidCallback onMenu;
  final Color? topbarColor;

  Future<void> _confirmAndLogoutEverywhere(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.logoutEverywhereTitle),
        content: Text(t.logoutEverywhereBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.logoutEverywhereConfirm),
          ),
        ],
      ),
    );
    if (ok == true) onLogout(everywhere: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final fullName = user?.fullName as String? ?? '';
    final role = user?.isSuperAdmin == true ? t.superAdmin : t.user;

    return Container(
      height: 60,
      color: topbarColor ?? Theme.of(context).appBarTheme.backgroundColor ?? cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(onPressed: onMenu, icon: const Icon(Icons.menu)),
          _CompanySwitcher(initialCompany: user?.company),
          const SizedBox(width: 12),
          const _LocaleSwitcher(),
          const Spacer(),
          // Phase 4.18 — in-app notifications. Polls /unread-count every
          // 45s, popover renders /notifications.
          const NotificationsBell(),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: t.account,
            onSelected: (v) {
              if (v == 'sessions') context.go('/sessions');
              if (v == 'logout') onLogout();
              if (v == 'logout-everywhere') _confirmAndLogoutEverywhere(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'sessions',
                child: Row(
                  children: [
                    const Icon(Icons.devices_other, size: 16),
                    const SizedBox(width: 8),
                    Text(t.sessionsTitle),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text(t.signOut)),
              PopupMenuItem(
                value: 'logout-everywhere',
                child: Text(t.logoutEverywhereMenu),
              ),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primary,
                  child: Text(
                    (fullName.isNotEmpty ? fullName[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!showMenuButton) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(fullName, style: Theme.of(context).textTheme.bodyMedium),
                      Text(role, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanySwitcher extends ConsumerStatefulWidget {
  const _CompanySwitcher({this.initialCompany});
  final dynamic initialCompany;

  @override
  ConsumerState<_CompanySwitcher> createState() => _CompanySwitcherState();
}

class _CompanySwitcherState extends ConsumerState<_CompanySwitcher> {
  List<Map<String, dynamic>> _companies = [];
  Map<String, dynamic>? _current;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCompany;
    if (c != null) {
      _current = {'id': c.id, 'name': c.name};
    }
    // Phase 4.20 — seed from auth state when the auth payload included
    // the slim {id, name} company list. Falls back to a /companies GET
    // only when the seed is missing (older backend, refresh-only path).
    final seeded = ref.read(authControllerProvider).companies;
    if (seeded != null) {
      _companies = seeded;
      _loaded = true;
    } else {
      Future.microtask(_loadCompanies);
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getJson('/companies');
      if (!mounted) return;
      setState(() {
        _companies = (res['items'] as List? ?? const []).cast<Map<String, dynamic>>();
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _select(Map<String, dynamic>? company) async {
    setState(() => _current = company);
    final id = company?['id'] as int?;
    await ref.read(themeControllerProvider.notifier).loadActive(companyId: id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final label = _current?['name']?.toString() ?? t.noCompany;

    if (!_loaded || _companies.isEmpty) {
      // Falls back to a static label until the company list loads (or if the
      // user can't see /companies, in which case the switcher just shows the
      // user's own company without a chooser).
      return Row(
        children: [
          Icon(Icons.business_outlined, size: 16, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
    }

    return PopupMenuButton<Map<String, dynamic>?>(
      tooltip: t.switchCompany,
      onSelected: _select,
      itemBuilder: (_) => [
        PopupMenuItem<Map<String, dynamic>?>(
          value: null,
          child: Text(t.globalTheme),
        ),
        const PopupMenuDivider(),
        ..._companies.map((c) => PopupMenuItem<Map<String, dynamic>?>(
              value: c,
              child: Row(
                children: [
                  if (_current?['id'] == c['id'])
                    const Icon(Icons.check, size: 16),
                  if (_current?['id'] == c['id']) const SizedBox(width: 6),
                  Text(c['name']?.toString() ?? '-'),
                ],
              ),
            )),
      ],
      child: Row(
        children: [
          Icon(Icons.business_outlined, size: 16, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: cs.onSurface.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}

class _LocaleSwitcher extends ConsumerWidget {
  const _LocaleSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(localeControllerProvider);
    return PopupMenuButton<Locale>(
      tooltip: AppLocalizations.of(context).language,
      onSelected: (next) => ref.read(localeControllerProvider.notifier).setLocale(next),
      itemBuilder: (_) => supportedLocales.map((loc) {
        return PopupMenuItem<Locale>(
          value: loc,
          child: Row(
            children: [
              if (locale.languageCode == loc.languageCode)
                const Icon(Icons.check, size: 16),
              if (locale.languageCode == loc.languageCode) const SizedBox(width: 6),
              Text(_languageLabel(loc.languageCode)),
            ],
          ),
        );
      }).toList(),
      child: Row(
        children: [
          Icon(Icons.translate, size: 16, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(locale.languageCode.toUpperCase(), style: Theme.of(context).textTheme.bodyMedium),
          Icon(Icons.keyboard_arrow_down, size: 16, color: cs.onSurface.withValues(alpha: 0.7)),
        ],
      ),
    );
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'ar': return 'العربية';
      case 'fr': return 'Français';
      default: return code;
    }
  }
}
