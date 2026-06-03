import 'package:flutter/material.dart';
import 'theme_provider.dart';

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
