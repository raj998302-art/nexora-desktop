import 'package:flutter/material.dart';

/// NEXORA design system palette — ported 1:1 from the NEXORA Web Prototype
/// (visual source of truth). All hex values are taken directly from the
/// prototype's Tailwind classes and inline colors.
///
/// Usage: `final c = context.watch<UiProvider>().palette;` then reference
/// `c.background`, `c.inputBackground`, etc. NEVER hardcode colors.
class AppColors {
  // ---- Dark palette (default, the product's identity) ----
  static const AppColors dark = AppColors._(
    // Base surfaces
    background: Color(0xFF1E1E1E), // #1e1e1e  app background
    activityBar: Color(0xFF181818), // #181818  top bar / activity bar / left panel
    panelBackground: Color(0xFF252526), // #252526  cards / composer shells
    inputBackground: Color(0xFF2A2D2E), // #2a2d2e  inputs / pills / chips
    hoverBackground: Color(0xFF333333), // #333     hover fill
    hoverBackground2: Color(0xFF3C3C3C), // #3c3c3c  hover fill (strong)
    selectedBackground: Color(0xFF37373D), // #37373d  active list item

    // Borders
    border: Color(0xFF2B2B2B), // #2b2b2b  primary panel borders
    borderLight: Color(0xFF3C3C3C), // #3c3c3c  input borders
    borderFocused: Color(0xFF555555), // #555     focus ring

    // Text
    textPrimary: Color(0xFFCCCCCC), // #cccccc
    textSecondary: Color(0xFF858585), // #858585
    textOnAccent: Color(0xFFFFFFFF), // white on accent surfaces
    textEditor: Color(0xFFD4D4D4), // #d4d4d4  editor code
    editorBackground: Color(0xFF1E1E1E), // #1e1e1e  editor surface
    editorForeground: Color(0xFFD4D4D4), // #d4d4d4  editor code

    // Brand / accent (prototype: blue-500 / blue-600 / status blue)
    accent: Color(0xFF007ACC), // #007acc  status bar / classic blue
    blue500: Color(0xFF3B82F6), // blue-500  indicators, active markers
    blue600: Color(0xFF2563EB), // blue-600  primary buttons
    blue400: Color(0xFF60A5FA), // blue-400  brand sparkles, links
    blueLight: Color(0xFF519ABA), // #519aba  file icons (tsx/ts)
    accentSoft: Color(0xFF264F78), // selection

    // Semantic (Tailwind 400/500 @ 10-30% alpha backgrounds)
    success: Color(0xFF4EC9B0), // teal #4ec9b0 (components)
    green400: Color(0xFF4ADE80), // green-400 (prompts, untracked)
    warning: Color(0xFFDCB67A), // #dcb67a folder icons
    yellow400: Color(0xFFFACC15), // yellow-400 (diff tab, lightbulb)
    error: Color(0xFFF14C4C),
    red400: Color(0xFFF87171), // red-400 (stop, errors)
    red500: Color(0xFFEF4444), // red-500 (stop button bg tint)
    purple400: Color(0xFFC084FC), // purple-400 (thinking mode)

    // File-icon colors (Explorer)
    iconJson: Color(0xFFCBCB41), // #cbcb41
    iconCss: Color(0xFF51B6C8), // #51b6c8
    iconMd: Color(0xFF4EA1DF), // #4ea1df
    iconSvg: Color(0xFFB072A9), // #b072a9
    iconPink: Color(0xFFB072A9),

    // Editor syntax (prototype CodeEditor.tsx inline colors)
    keyword: Color(0xFFC586C0), // #c586c0  import/return
    typeKeyword: Color(0xFF569CD6), // #569cd6  function/types/JSX tags
    string: Color(0xFFCE9178), // #ce9178  strings
    comment: Color(0xFF6A9955), // #6a9955  comments
    number: Color(0xFFB5CEA8), // #b5cea8  numbers
    functionColor: Color(0xFFDCDCAA), // #dcdcaa  function names
    attrColor: Color(0xFF9CDCFE), // #9cdcfe  JSX attributes

    // Diffs
    selection: Color(0xFF264F78),
    diffAddBg: Color(0x334ADE80), // green-500/20
    diffDelBg: Color(0x33EF4444), // red-500/20
    brightness: Brightness.dark,
  );

  // ---- Light palette (kept for theme toggle; prototype is dark-first) ----
  static const AppColors light = AppColors._(
    background: Color(0xFFF3F3F3),
    activityBar: Color(0xFFE8E8E8),
    panelBackground: Color(0xFFFFFFFF),
    inputBackground: Color(0xFFF6F6F6),
    hoverBackground: Color(0xFFEAEAEA),
    hoverBackground2: Color(0xFFE0E0E0),
    selectedBackground: Color(0xFFE4E6E8),
    border: Color(0xFFDADADA),
    borderLight: Color(0xFFC4C4C4),
    borderFocused: Color(0xFFAAAAAA),
    textPrimary: Color(0xFF333333),
    textSecondary: Color(0xFF767676),
    textOnAccent: Color(0xFFFFFFFF),
    textEditor: Color(0xFF1E1E1E),
    editorBackground: Color(0xFFFFFFFF),
    editorForeground: Color(0xFF1E1E1E),
    accent: Color(0xFF007ACC),
    blue500: Color(0xFF2563EB),
    blue600: Color(0xFF2563EB),
    blue400: Color(0xFF3B82F6),
    blueLight: Color(0xFF1A7FB5),
    accentSoft: Color(0xFFCCE4F7),
    success: Color(0xFF16825D),
    green400: Color(0xFF16A34A),
    warning: Color(0xFFA25E19),
    yellow400: Color(0xFFCA8A04),
    error: Color(0xFFC4393C),
    red400: Color(0xFFDC2626),
    red500: Color(0xFFDC2626),
    purple400: Color(0xFF9333EA),
    iconJson: Color(0xFF8A8A22),
    iconCss: Color(0xFF1B8CA0),
    iconMd: Color(0xFF2D7DD2),
    iconSvg: Color(0xFF8E5A87),
    iconPink: Color(0xFF8E5A87),
    keyword: Color(0xFFAF30A0),
    typeKeyword: Color(0xFF0550AE),
    string: Color(0xFFA31515),
    comment: Color(0xFF008000),
    number: Color(0xFF095B69),
    functionColor: Color(0xFF795E00),
    attrColor: Color(0xFF0451A5),
    selection: Color(0xFFADD6FF),
    diffAddBg: Color(0x3316A34A),
    diffDelBg: Color(0x33DC2626),
    brightness: Brightness.light,
  );

  const AppColors._({
    required this.background,
    required this.activityBar,
    required this.panelBackground,
    required this.inputBackground,
    required this.hoverBackground,
    required this.hoverBackground2,
    required this.selectedBackground,
    required this.border,
    required this.borderLight,
    required this.borderFocused,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnAccent,
    required this.textEditor,
    required this.editorBackground,
    required this.editorForeground,
    required this.accent,
    required this.blue500,
    required this.blue600,
    required this.blue400,
    required this.blueLight,
    required this.accentSoft,
    required this.success,
    required this.green400,
    required this.warning,
    required this.yellow400,
    required this.error,
    required this.red400,
    required this.red500,
    required this.purple400,
    required this.iconJson,
    required this.iconCss,
    required this.iconMd,
    required this.iconSvg,
    required this.iconPink,
    required this.keyword,
    required this.typeKeyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.functionColor,
    required this.attrColor,
    required this.selection,
    required this.diffAddBg,
    required this.diffDelBg,
    required this.brightness,
  });

  final Color background;
  final Color activityBar;
  final Color panelBackground;
  final Color inputBackground;
  final Color hoverBackground;
  final Color hoverBackground2;
  final Color selectedBackground;
  final Color border;
  final Color borderLight;
  final Color borderFocused;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnAccent;
  final Color textEditor;
  final Color editorBackground;
  final Color editorForeground;
  final Color accent;
  final Color blue500;
  final Color blue600;
  final Color blue400;
  final Color blueLight;
  final Color accentSoft;
  final Color success;
  final Color green400;
  final Color warning;
  final Color yellow400;
  final Color error;
  final Color red400;
  final Color red500;
  final Color purple400;
  final Color iconJson;
  final Color iconCss;
  final Color iconMd;
  final Color iconSvg;
  final Color iconPink;
  final Color keyword;
  final Color typeKeyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color functionColor;
  final Color attrColor;
  final Color selection;
  final Color diffAddBg;
  final Color diffDelBg;
  final Brightness brightness;

  /// Build the Material theme for this palette. Font family matches the
  /// prototype: Inter everywhere, Fira Code for mono.
  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue600,
      brightness: brightness,
    ).copyWith(
      surface: panelBackground,
      primary: blue600,
      onPrimary: textOnAccent,
      onSurface: textPrimary,
    );
    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      dividerColor: border,
      textTheme: const TextTheme(
        bodySmall: TextStyle(fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontFamily: 'Inter'),
        bodyLarge: TextStyle(fontFamily: 'Inter'),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: panelBackground,
          border: Border.all(color: borderLight),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
            color: Color(0xFFCCCCCC), fontSize: 11, fontFamily: 'Inter'),
        waitDuration: Duration(milliseconds: 300),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelBackground,
        contentTextStyle: const TextStyle(
            color: Color(0xFFCCCCCC), fontSize: 13, fontFamily: 'Inter'),
        actionTextColor: Color(0xFF60A5FA),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF3C3C3C)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF252526),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: Color(0xFF3C3C3C)),
        ),
        titleTextStyle: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter'),
        contentTextStyle: TextStyle(
            color: Color(0xFFCCCCCC), fontSize: 13, fontFamily: 'Inter'),
      ),
    );
  }
}
