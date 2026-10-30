import 'package:flutter/material.dart';

/// رموز الألوان المعتمدة لتطبيق "وثيق PDF" والمتحققة حسابياً وفق معيار WCAG AA.
class WathiqPalette {
  const WathiqPalette({
    required this.isDark,
    required this.canvasBackground,
    required this.surfaceContainer,
    required this.surfaceElevated,
    required this.structuralBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.error,
  });

  final bool isDark;
  final Color canvasBackground;
  final Color surfaceContainer;
  final Color surfaceElevated;
  final Color structuralBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color error;

  /// الوضع الليلي (Vault Obsidian) - التباين: النص الأساسي 17.52:1، النص الثانوي 6.86:1، الحدود 3.70:1.
  static const WathiqPalette dark = WathiqPalette(
    isDark: true,
    canvasBackground: Color(0xFF0D0F12),
    surfaceContainer: Color(0xFF161920),
    surfaceElevated: Color(0xFF1E222B),
    structuralBorder: Color(0xFF64748B),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    accent: Color(0xFF34D399),
    onAccent: Color(0xFF062E22),
    error: Color(0xFFF87171),
  );

  /// الوضع النهاري (Crisp Paper) - التباين: النص الأساسي 17.06:1، النص الثانوي 7.58:1، الحدود 4.55:1.
  static const WathiqPalette light = WathiqPalette(
    isDark: false,
    canvasBackground: Color(0xFFF8FAFC),
    surfaceContainer: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    structuralBorder: Color(0xFF64748B),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    accent: Color(0xFF047857),
    onAccent: Color(0xFFFFFFFF),
    error: Color(0xFFB91C1C),
  );

  static WathiqPalette of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }
}

/// بناء سمات التطبيق (Light & Dark Themes) مع دعم كامل للوصول عبر لوحة المفاتيح وأهداف لمس >= 48px.
class WathiqTheme {
  const WathiqTheme._();

  static ThemeData buildDarkTheme() => _build(WathiqPalette.dark);
  static ThemeData buildLightTheme() => _build(WathiqPalette.light);

  static ThemeData _build(WathiqPalette palette) {
    final colorScheme = ColorScheme(
      brightness: palette.isDark ? Brightness.dark : Brightness.light,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      error: palette.error,
      onError: palette.isDark ? const Color(0xFF0D0F12) : Colors.white,
      surface: palette.surfaceContainer,
      onSurface: palette.textPrimary,
      outline: palette.structuralBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvasBackground,
      dividerColor: palette.structuralBorder,
      focusColor: palette.accent.withOpacity(0.28),
      cardTheme: CardTheme(
        color: palette.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: palette.structuralBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvasBackground,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          elevation: 0,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: palette.structuralBorder, width: 1),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.canvasBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: palette.structuralBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: palette.error, width: 1.5),
        ),
      ),
    );
  }
}
