import 'package:flutter/material.dart';

import 'theme_settings.dart';

class AppThemeBuilder {
  static ThemeData build(ThemeSettings t) {
    final brightness = t.isDark ? Brightness.dark : Brightness.light;
    final primary = hexToColor(t.primary);
    final secondary = hexToColor(t.secondary);
    final accent = hexToColor(t.accent);
    final background = hexToColor(t.background);
    final surface = hexWithAlpha(t.surface, t.surfaceOpacity);
    final cardSurface = hexWithAlpha(t.surface, t.cardOpacity);
    final textPrimary = hexToColor(t.textPrimary);
    final textSecondary = hexToColor(t.textSecondary);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      tertiary: accent,
      onTertiary: Colors.white,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: t.isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFF1F5F9),
      outline: t.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );

    final base = TextStyle(
      fontFamily: t.fontFamily,
      color: textPrimary,
      fontSize: t.fontSizeBase.toDouble(),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: t.fontFamily,
      textTheme: TextTheme(
        bodyLarge: base.copyWith(fontSize: (t.fontSizeBase + 2).toDouble()),
        bodyMedium: base,
        bodySmall: base.copyWith(
          fontSize: (t.fontSizeBase - 1).toDouble(),
          color: textSecondary,
        ),
        titleLarge: base.copyWith(
          fontSize: (t.fontSizeBase + 8).toDouble(),
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.copyWith(
          fontSize: (t.fontSizeBase + 4).toDouble(),
          fontWeight: FontWeight.w600,
        ),
        labelLarge: base.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: t.shadows ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cardRadius.toDouble()),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: t.shadows ? 1 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.buttonRadius.toDouble()),
          ),
          textStyle: base.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.buttonRadius.toDouble()),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.buttonRadius.toDouble()),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.buttonRadius.toDouble()),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.buttonRadius.toDouble()),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.buttonRadius.toDouble()),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: hexToColor(t.topbar),
        foregroundColor: hexToColor(t.topbarText),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: base.copyWith(fontWeight: FontWeight.w600),
        dataTextStyle: base,
        dividerThickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outline),
        labelStyle: base.copyWith(fontSize: (t.fontSizeBase - 1).toDouble()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.buttonRadius.toDouble()),
        ),
      ),
    );
  }
}
