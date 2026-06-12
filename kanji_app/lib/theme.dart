import 'package:flutter/material.dart';
import 'theme_provider.dart';

// ── Design tokens derived from ThemeColors for the redesigned UI ──────────────
class KDesign {
  static Color ink(ThemeColors t) => t.kanjiColor;
  static Color inkSoft(ThemeColors t) => t.muted;
  static Color inkFaint(ThemeColors t) => Color.lerp(t.muted, t.bg, 0.5)!;
  static Color line(ThemeColors t) => t.pillBg;
  static Color tint(ThemeColors t) => t.accent.withValues(alpha: 0.13);
  static Color soft(ThemeColors t) => t.accent.withValues(alpha: 0.22);
  static Color deep(ThemeColors t) {
    final hsl = HSLColor.fromColor(t.accent);
    return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  }
  static Color bgWarm(ThemeColors t) => t.bg;
  static Color surface(ThemeColors t) => t.surface;
  static const Color gold = Color(0xFFE0A23C);
  static const Color goldSoft = Color(0xFFFDF3E3);
  static Color green(ThemeColors t) => t.correct;
  static Color greenSoft(ThemeColors t) => t.correctBg;

  static List<BoxShadow> shadowSm(ThemeColors t) => [
    BoxShadow(
      color: t.accent.withValues(alpha: 0.07),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowAccent(ThemeColors t) => [
    BoxShadow(
      color: t.accent.withValues(alpha: 0.16),
      blurRadius: 13,
      offset: const Offset(0, 5),
    ),
  ];

  static BorderRadius get cardRadius => BorderRadius.circular(16);
  static BorderRadius get heroRadius => BorderRadius.circular(22);
  static BorderRadius get chipRadius => BorderRadius.circular(12);
  static BorderRadius get pillRadius => BorderRadius.circular(99);
}

ThemeColors _currentTheme = simpleLightTheme;
void setCurrentTheme(ThemeColors t) { _currentTheme = t; }

class AppColors {
  static Color get bg          => _currentTheme.bg;
  static Color get surface     => _currentTheme.surface;
  static Color get fg          => _currentTheme.fg;
  static Color get accent      => _currentTheme.accent;
  static Color get accentBright => _currentTheme.accentBright;
  static Color get muted       => _currentTheme.muted;
  static Color get pillBg      => _currentTheme.pillBg;
  static Color get btnBg       => _currentTheme.btnBg;
  static Color get kanjiColor  => _currentTheme.kanjiColor;
  static Color get correct     => _currentTheme.correct;
  static Color get correctBg   => _currentTheme.correctBg;
  static Color get incorrect   => _currentTheme.incorrect;
  static Color get incorrectBg => _currentTheme.incorrectBg;
  static double get containerRadius => _currentTheme.containerRadius;
  static double get buttonRadius => _currentTheme.buttonRadius;
}

String? _currentEnglishFont;
String? _currentJapaneseFont;
void setCurrentFonts(String englishFont, String japaneseFont) {
  _currentEnglishFont = englishFont == 'system' ? null : englishFont;
  _currentJapaneseFont = japaneseFont == 'system' ? null : japaneseFont;
}

class AppFonts {
  static String? get englishFont => _currentEnglishFont;
  static String? get japaneseFont => _currentJapaneseFont;
  static List<String> get japaneseFallback =>
      _currentJapaneseFont != null ? [_currentJapaneseFont!] : const [];
}

ThemeData buildTheme(ThemeColors colors, {bool transparentScaffold = false}) {
  final ef = _currentEnglishFont;
  final jf = _currentJapaneseFont;
  final jFallback = jf != null ? [jf] : const <String>[];
  return ThemeData(
    useMaterial3: false,
    fontFamily: ef,
    scaffoldBackgroundColor: transparentScaffold ? Colors.transparent : colors.bg,
    colorScheme: ColorScheme.dark(
      surface: colors.surface,
      onSurface: colors.fg,
      primary: colors.accent,
      onPrimary: colors.fg,
      secondary: colors.accentBright,
      onSecondary: colors.bg,
      tertiary: colors.accent,
      onTertiary: colors.fg,
      error: colors.incorrect,
      onError: colors.fg,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.fg,
      elevation: 0,
      iconTheme: IconThemeData(color: colors.fg),
      titleTextStyle: TextStyle(color: colors.fg, fontSize: 20, fontWeight: FontWeight.w500,
          fontFamily: ef, fontFamilyFallback: jFallback),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.fg,
      unselectedLabelColor: colors.muted,
      indicatorColor: colors.accent,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: colors.fg, fontSize: 14,
          fontFamily: ef, fontFamilyFallback: jFallback),
      bodySmall: TextStyle(color: colors.muted, fontSize: 11,
          fontFamily: ef, fontFamilyFallback: jFallback),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.btnBg,
        foregroundColor: colors.kanjiColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(colors.buttonRadius)),
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
            fontFamily: ef, fontFamilyFallback: jFallback),
      ),
    ),
  );
}

final appTheme = buildTheme(simpleLightTheme);
