import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/settings_service.dart';

enum AppTheme {
  simpleDark,
  simpleLight,
  sakura,
  galaxy,
  loveLetter,
  lily,
  totoro,
  midnightCity,
}

class ThemeColors {
  final String name;
  final Color bg;
  final Color surface;
  final Color fg;
  final Color accent;
  final Color accentBright;
  final Color muted;
  final Color pillBg;
  final Color btnBg;
  final Color kanjiColor;
  final Color correct;
  final Color correctBg;
  final Color incorrect;
  final Color incorrectBg;
  final double buttonRadius;
  final double containerRadius;

  const ThemeColors({
    required this.name,
    required this.bg,
    required this.surface,
    required this.fg,
    required this.accent,
    required this.accentBright,
    required this.muted,
    required this.pillBg,
    required this.btnBg,
    required this.kanjiColor,
    required this.correct,
    required this.correctBg,
    required this.incorrect,
    required this.incorrectBg,
    this.buttonRadius = 10.0,
    this.containerRadius = 8.0,
  });
}

const simpleDarkTheme = ThemeColors(
  name: 'Simple Black',
  bg:           Color(0xFF131313),
  surface:      Color(0xFF1F1F1F),
  fg:           Color(0xFFEDEAE4),
  accent:       Color(0xFFD8D2C4),
  accentBright: Color(0xFFECE8DE),
  muted:        Color(0xFFAFAAA3),
  pillBg:       Color(0xFF272522),
  btnBg:        Color(0xFF1F1F1F),
  kanjiColor:   Color(0xFFEDEAE4),
  correct:      Color(0xFF56CD8C),
  correctBg:    Color(0xFF18281F),
  incorrect:    Color(0xFFF47A8C),
  incorrectBg:  Color(0xFF281A20),
  buttonRadius: 12.0, containerRadius: 12.0,
);

const simpleLightTheme = ThemeColors(
  name: 'Simple Light',
  bg:           Color(0xFFF2EFE9),
  surface:      Color(0xFFFEFCF8),
  fg:           Color(0xFF1C1A17),
  accent:       Color(0xFF4A4540),
  accentBright: Color(0xFF6B635A),
  muted:        Color(0xFF8A8278),
  pillBg:       Color(0xFFE5E0D8),
  btnBg:        Color(0xFFFEFCF8),
  kanjiColor:   Color(0xFF1C1A17),
  correct:      Color(0xFF1A7A45),
  correctBg:    Color(0xFFEDF5F0),
  incorrect:    Color(0xFFC2303E),
  incorrectBg:  Color(0xFFFAECED),
  buttonRadius: 12.0, containerRadius: 12.0,
);

const sakuraTheme = ThemeColors(
  name: 'Spring Sakura',
  bg:           Color(0xFFFAF4F0),
  surface:      Color(0xFFFFFFFF),
  fg:           Color(0xFF3D1A26),
  accent:       Color(0xFFD4677E),
  accentBright: Color(0xFFE8899A),
  muted:        Color(0xFF9E7585),
  pillBg:       Color(0xFFF5DDE4),
  btnBg:        Color(0xFFFFFFFF),
  kanjiColor:   Color(0xFF3D1A26),
  correct:      Color(0xFF2F7A50),
  correctBg:    Color(0xFFEDF7F2),
  incorrect:    Color(0xFFC93350),
  incorrectBg:  Color(0xFFFCE8ED),
  buttonRadius: 12.0, containerRadius: 10.0,
);


const galaxyTheme = ThemeColors(
  name: 'Starman',
  bg:           Color(0xFF1A2538),  // deeper than Deep Space Blue
  surface:      Color(0xFF2C3D55),  // Deep Space Blue
  fg:           Color(0xFFD0D8E8),  // pale cool-white
  accent:       Color(0xFF84828F),  // Rosy Granite
  accentBright: Color(0xFF7898B0),  // Blue Slate lightened
  muted:        Color(0xFFB0AEC0),  // Dim Grey brightened
  pillBg:       Color(0xFF3E4C5E),  // Charcoal Blue
  btnBg:        Color(0xFF2C3D55),  // Deep Space Blue
  kanjiColor:   Color(0xFFD0D8E8),
  correct:      Color(0xFF58A888),
  correctBg:    Color(0xFF0E2020),
  incorrect:    Color(0xFFC07880),
  incorrectBg:  Color(0xFF201018),
  buttonRadius: 12.0, containerRadius: 12.0,
);


const loveletterTheme = ThemeColors(
  name: 'Love Letter',
  bg:           Color(0xFFD8E3EF),
  surface:      Color(0xFFF2F6FA),
  fg:           Color(0xFF1A2B38),
  accent:       Color(0xFF4A7AAF),
  accentBright: Color(0xFF8CB4D0),
  muted:        Color(0xFF6878A0),
  pillBg:       Color(0xFFCDD9E8),
  btnBg:        Color(0xFFF2F6FA),
  kanjiColor:   Color(0xFF1A2B38),
  correct:      Color(0xFF3A8264),
  correctBg:    Color(0xFFDCEEE6),
  incorrect:    Color(0xFFC47A86),
  incorrectBg:  Color(0xFFF2E4E8),
  buttonRadius: 12.0, containerRadius: 12.0,
);

const lilyTheme = ThemeColors(
  name: 'Chou-chou Green',
  bg:           Color(0xFFEEF4EA),
  surface:      Color(0xFFFFFFFF),
  fg:           Color(0xFF37433A),
  accent:       Color(0xFF5F9E7D),
  accentBright: Color(0xFFA6CDB4),
  muted:        Color(0xFF85948A),
  pillBg:       Color(0xFFE7F1EA),
  btnBg:        Color(0xFFFFFFFF),
  kanjiColor:   Color(0xFF37433A),
  correct:      Color(0xFF4F9E74),
  correctBg:    Color(0xFFE6F2EA),
  incorrect:    Color(0xFFC47F7F),
  incorrectBg:  Color(0xFFF6ECEC),
  buttonRadius: 12.0, containerRadius: 12.0,
);

const totoroTheme = ThemeColors(
  name: 'Big Rabbit Green',
  bg:           Color(0xFFEEF1DE),
  surface:      Color(0xFFFFFDF4),
  fg:           Color(0xFF33402B),
  accent:       Color(0xFF6B9A52),
  accentBright: Color(0xFFA7C66F),
  muted:        Color(0xFF7E896B),
  pillBg:       Color(0xFFE8EFD7),
  btnBg:        Color(0xFFFFFDF4),
  kanjiColor:   Color(0xFF33402B),
  correct:      Color(0xFF4A8A44),
  correctBg:    Color(0xFFE7F1D8),
  incorrect:    Color(0xFFC75C4E),
  incorrectBg:  Color(0xFFF8E9E2),
  buttonRadius: 16.0, containerRadius: 16.0,
);


const midnightCityTheme = ThemeColors(
  name: 'Midnight City',
  bg:           Color(0xFF000000),  // Black
  surface:      Color(0xFF2F4550),  // Charcoal Blue
  fg:           Color(0xFFF4F4F9),  // Ghost White
  accent:       Color(0xFFB8DBD9),  // Light Blue
  accentBright: Color(0xFFD8EEEC),  // Light Blue lightened
  muted:        Color(0xFF8AACBC),  // Blue Slate brightened
  pillBg:       Color(0xFF1A2C38),  // between Black and Charcoal Blue
  btnBg:        Color(0xFF2F4550),  // Charcoal Blue
  kanjiColor:   Color(0xFFF4F4F9),  // Ghost White
  correct:      Color(0xFF5AACA8),
  correctBg:    Color(0xFF081C1A),
  incorrect:    Color(0xFFC08888),
  incorrectBg:  Color(0xFF201010),
  buttonRadius: 14.0, containerRadius: 14.0,
);

const themeColorMap = {
  AppTheme.simpleDark:   simpleDarkTheme,
  AppTheme.simpleLight:  simpleLightTheme,
  AppTheme.sakura:       sakuraTheme,
  AppTheme.galaxy:       galaxyTheme,
  AppTheme.loveLetter:   loveletterTheme,
  AppTheme.lily:         lilyTheme,
  AppTheme.totoro:       totoroTheme,
  AppTheme.midnightCity: midnightCityTheme,
};

final themeNotifier = NotifierProvider<ThemeNotifier, AppTheme>(
  ThemeNotifier.new,
);

final themeColorsProvider = Provider<ThemeColors>((ref) {
  final theme = ref.watch(themeNotifier);
  final appearanceSettings = ref.watch(appearanceSettingsProvider);
  final contrast = appearanceSettings?.getContrast() ?? 'normal';

  var colors = themeColorMap[theme]!;

  if (contrast == 'high' || contrast == 'ultra') {
    colors = ThemeColors(
      name: colors.name,
      bg:           _adjustBrightness(colors.bg, contrast == 'ultra' ? -0.1 : -0.05),
      surface:      _adjustBrightness(colors.surface, contrast == 'ultra' ? -0.1 : -0.05),
      fg:           _adjustBrightness(colors.fg, contrast == 'ultra' ? 0.15 : 0.1),
      accent:       colors.accent,
      accentBright: colors.accentBright,
      muted:        _adjustBrightness(colors.muted, contrast == 'ultra' ? 0.1 : 0.05),
      pillBg:       colors.pillBg,
      btnBg:        colors.btnBg,
      kanjiColor:   colors.kanjiColor,
      correct:      colors.correct,
      correctBg:    colors.correctBg,
      incorrect:    colors.incorrect,
      incorrectBg:  colors.incorrectBg,
    );
  }

  return colors;
});

Color _adjustBrightness(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  final adjusted = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
  return adjusted.toColor();
}

class ThemeNotifier extends Notifier<AppTheme> {
  @override
  AppTheme build() {
    _loadTheme();
    return AppTheme.sakura;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('theme') ?? 'sakura';
    state = AppTheme.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => AppTheme.simpleLight,
    );
  }

  Future<void> setTheme(AppTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme.name);
  }
}
