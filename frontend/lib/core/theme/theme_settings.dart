import 'dart:ui';

class ThemeSettings {
  const ThemeSettings({
    this.mode = 'light',
    this.primary = '#1F6FEB',
    this.secondary = '#0EA5E9',
    this.accent = '#22C55E',
    this.background = '#F4F6FA',
    this.surface = '#FFFFFF',
    this.sidebar = '#0F172A',
    this.sidebarText = '#E2E8F0',
    this.topbar = '#FFFFFF',
    this.topbarText = '#0F172A',
    this.textPrimary = '#0F172A',
    this.textSecondary = '#475569',
    this.buttonRadius = 10,
    this.cardRadius = 14,
    this.tableRadius = 10,
    this.fontFamily = 'Inter',
    this.fontSizeBase = 14,
    this.shadows = true,
    this.gradients = false,
    this.gradientFrom = '#1F6FEB',
    this.gradientTo = '#0EA5E9',
    this.gradientDirection = 'topLeftToBottomRight',
    this.loginStyle = 'split',
    this.dashboardLayout = 'cards',
    this.appName = 'TatbeeqX',
    this.logoUrl,
    this.faviconUrl,
    this.backgroundImageUrl,
    this.surfaceOpacity = 1.0,
    this.sidebarOpacity = 1.0,
    this.topbarOpacity = 1.0,
    this.cardOpacity = 1.0,
    this.backgroundOpacity = 1.0,
    this.backgroundBlur = 0,
    this.backgroundOverlayColor = '#000000',
    this.backgroundOverlayOpacity = 0.0,
    this.loginOverlayColor = '#000000',
    this.loginOverlayOpacity = 0.35,
    this.enableGlass = false,
    this.glassBlur = 12,
    this.glassTint = '#FFFFFF',
    this.glassTintOpacity = 0.6,
  });

  final String mode;
  final String primary;
  final String secondary;
  final String accent;
  final String background;
  final String surface;
  final String sidebar;
  final String sidebarText;
  final String topbar;
  final String topbarText;
  final String textPrimary;
  final String textSecondary;
  final num buttonRadius;
  final num cardRadius;
  final num tableRadius;
  final String fontFamily;
  final num fontSizeBase;
  final bool shadows;
  final bool gradients;
  final String gradientFrom;
  final String gradientTo;
  final String gradientDirection;
  final String loginStyle;
  final String dashboardLayout;
  final String appName;
  final String? logoUrl;
  final String? faviconUrl;
  final String? backgroundImageUrl;

  // Phase 4 — transparency / overlay / glass
  final num surfaceOpacity;
  final num sidebarOpacity;
  final num topbarOpacity;
  final num cardOpacity;
  final num backgroundOpacity;
  final num backgroundBlur;
  final String backgroundOverlayColor;
  final num backgroundOverlayOpacity;
  final String loginOverlayColor;
  final num loginOverlayOpacity;
  final bool enableGlass;
  final num glassBlur;
  final String glassTint;
  final num glassTintOpacity;

  bool get isDark => mode.toLowerCase() == 'dark';

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    String s(String k, String d) => (json[k] as Object?)?.toString() ?? d;
    String? sn(String k) => json[k]?.toString();
    num n(String k, num d) => (json[k] is num) ? json[k] as num : num.tryParse('${json[k]}') ?? d;
    bool b(String k, bool d) => json[k] is bool ? json[k] as bool : d;

    return ThemeSettings(
      mode: s('mode', 'light'),
      primary: s('primary', '#1F6FEB'),
      secondary: s('secondary', '#0EA5E9'),
      accent: s('accent', '#22C55E'),
      background: s('background', '#F4F6FA'),
      surface: s('surface', '#FFFFFF'),
      sidebar: s('sidebar', '#0F172A'),
      sidebarText: s('sidebarText', '#E2E8F0'),
      topbar: s('topbar', '#FFFFFF'),
      topbarText: s('topbarText', '#0F172A'),
      textPrimary: s('textPrimary', '#0F172A'),
      textSecondary: s('textSecondary', '#475569'),
      buttonRadius: n('buttonRadius', 10),
      cardRadius: n('cardRadius', 14),
      tableRadius: n('tableRadius', 10),
      fontFamily: s('fontFamily', 'Inter'),
      fontSizeBase: n('fontSizeBase', 14),
      shadows: b('shadows', true),
      gradients: b('gradients', false),
      gradientFrom: s('gradientFrom', '#1F6FEB'),
      gradientTo: s('gradientTo', '#0EA5E9'),
      gradientDirection: s('gradientDirection', 'topLeftToBottomRight'),
      loginStyle: s('loginStyle', 'split'),
      dashboardLayout: s('dashboardLayout', 'cards'),
      appName: s('appName', 'TatbeeqX'),
      logoUrl: sn('logoUrl'),
      faviconUrl: sn('faviconUrl'),
      backgroundImageUrl: sn('backgroundImageUrl'),
      surfaceOpacity: n('surfaceOpacity', 1.0),
      sidebarOpacity: n('sidebarOpacity', 1.0),
      topbarOpacity: n('topbarOpacity', 1.0),
      cardOpacity: n('cardOpacity', 1.0),
      backgroundOpacity: n('backgroundOpacity', 1.0),
      backgroundBlur: n('backgroundBlur', 0),
      backgroundOverlayColor: s('backgroundOverlayColor', '#000000'),
      backgroundOverlayOpacity: n('backgroundOverlayOpacity', 0.0),
      loginOverlayColor: s('loginOverlayColor', '#000000'),
      loginOverlayOpacity: n('loginOverlayOpacity', 0.35),
      enableGlass: b('enableGlass', false),
      glassBlur: n('glassBlur', 12),
      glassTint: s('glassTint', '#FFFFFF'),
      glassTintOpacity: n('glassTintOpacity', 0.6),
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'primary': primary,
        'secondary': secondary,
        'accent': accent,
        'background': background,
        'surface': surface,
        'sidebar': sidebar,
        'sidebarText': sidebarText,
        'topbar': topbar,
        'topbarText': topbarText,
        'textPrimary': textPrimary,
        'textSecondary': textSecondary,
        'buttonRadius': buttonRadius,
        'cardRadius': cardRadius,
        'tableRadius': tableRadius,
        'fontFamily': fontFamily,
        'fontSizeBase': fontSizeBase,
        'shadows': shadows,
        'gradients': gradients,
        'gradientFrom': gradientFrom,
        'gradientTo': gradientTo,
        'gradientDirection': gradientDirection,
        'loginStyle': loginStyle,
        'dashboardLayout': dashboardLayout,
        'appName': appName,
        'logoUrl': logoUrl,
        'faviconUrl': faviconUrl,
        'backgroundImageUrl': backgroundImageUrl,
        'surfaceOpacity': surfaceOpacity,
        'sidebarOpacity': sidebarOpacity,
        'topbarOpacity': topbarOpacity,
        'cardOpacity': cardOpacity,
        'backgroundOpacity': backgroundOpacity,
        'backgroundBlur': backgroundBlur,
        'backgroundOverlayColor': backgroundOverlayColor,
        'backgroundOverlayOpacity': backgroundOverlayOpacity,
        'loginOverlayColor': loginOverlayColor,
        'loginOverlayOpacity': loginOverlayOpacity,
        'enableGlass': enableGlass,
        'glassBlur': glassBlur,
        'glassTint': glassTint,
        'glassTintOpacity': glassTintOpacity,
      };

  ThemeSettings copyWith(Map<String, dynamic> patch) {
    final merged = {...toJson(), ...patch};
    return ThemeSettings.fromJson(merged);
  }
}

Color hexToColor(String hex) {
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16) ?? 0xFF1F6FEB;
  return Color(v);
}

String colorToHex(Color c) {
  String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  final r = (c.r * 255.0).round().clamp(0, 255);
  final g = (c.g * 255.0).round().clamp(0, 255);
  final b = (c.b * 255.0).round().clamp(0, 255);
  return '#${two(r)}${two(g)}${two(b)}';
}

Color hexWithAlpha(String hex, num alpha) {
  return hexToColor(hex).withValues(alpha: alpha.toDouble().clamp(0.0, 1.0));
}
