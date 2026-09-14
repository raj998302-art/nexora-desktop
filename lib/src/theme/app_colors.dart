import 'package:flutter/material.dart';

/// NEXORA palette. A single source of truth for every color in the app so
/// light/dark themes both render readable text (no hardcoded Colors.white).
class AppColors {
  // ---- Dark palette (default) ----
  static const AppColors dark = AppColors._(
    background: Color(0xFF1E1E1E),
    activityBar: Color(0xFF181818),
    panelBackground: Color(0xFF252526),
    border: Color(0xFF2B2B2B),
    borderLight: Color(0xFF3C3C3C),
    textPrimary: Color(0xFFCCCCCC),
    textSecondary: Color(0xFF858585),
    textOnAccent: Color(0xFFFFFFFF),
    accent: Color(0xFF007ACC),
    accentSoft: Color(0xFF264F78),
    blueLight: Color(0xFF519ABA),
    editorBackground: Color(0xFF1E1E1E),
    editorForeground: Color(0xFFD4D4D4),
    success: Color(0xFF4EC9B0),
    warning: Color(0xFFCE9178),
    error: Color(0xFFF14C4C),
    keyword: Color(0xFF569CD6),
    string: Color(0xFFCE9178),
    comment: Color(0xFF6A9955),
    number: Color(0xFFB5CEA8),
    selection: Color(0xFF264F78),
    diffAddBg: Color(0xFF12261A),
    diffDelBg: Color(0xFF2B1517),
    brightness: Brightness.dark,
  );

  // ---- Light palette ----
  static const AppColors light = AppColors._(
    background: Color(0xFFF3F3F3),
    activityBar: Color(0xFFE8E8E8),
    panelBackground: Color(0xFFFFFFFF),
    border: Color(0xFFDADADA),
    borderLight: Color(0xFFC4C4C4),
    textPrimary: Color(0xFF333333),
    textSecondary: Color(0xFF767676),
    textOnAccent: Color(0xFFFFFFFF),
    accent: Color(0xFF007ACC),
    accentSoft: Color(0xFFCCE4F7),
    blueLight: Color(0xFF1A7FB5),
    editorBackground: Color(0xFFFFFFFF),
    editorForeground: Color(0xFF1E1E1E),
    success: Color(0xFF16825D),
    warning: Color(0xFFA25E19),
    error: Color(0xFFC4393C),
    keyword: Color(0xFF0000C0),
    string: Color(0xFFA31515),
    comment: Color(0xFF008000),
    number: Color(0xFF095B69),
    selection: Color(0xFFADD6FF),
    diffAddBg: Color(0xFFD6F5DD),
    diffDelBg: Color(0xFFF9E0E0),
    brightness: Brightness.light,
  );

  const AppColors._({
    required this.background,
    required this.activityBar,
    required this.panelBackground,
    required this.border,
    required this.borderLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnAccent,
    required this.accent,
    required this.accentSoft,
    required this.blueLight,
    required this.editorBackground,
    required this.editorForeground,
    required this.success,
    required this.warning,
    required this.error,
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.selection,
    required this.diffAddBg,
    required this.diffDelBg,
    required this.brightness,
  });

  final Color background;
  final Color activityBar;
  final Color panelBackground;
  final Color border;
  final Color borderLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnAccent;
  final Color accent;
  final Color accentSoft;
  final Color blueLight;
  final Color editorBackground;
  final Color editorForeground;
  final Color success;
  final Color warning;
  final Color error;
  final Color keyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color selection;
  final Color diffAddBg;
  final Color diffDelBg;
  final Brightness brightness;

  /// Build a Material theme for this palette.
  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      surface: panelBackground,
      primary: accent,
      onPrimary: textOnAccent,
      onSurface: textPrimary,
    );
    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Segoe UI',
      dividerColor: border,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: panelBackground),
        textStyle: TextStyle(color: textPrimary, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelBackground,
        contentTextStyle: TextStyle(color: textPrimary),
        actionTextColor: accent,
      ),
    );
  }
}
