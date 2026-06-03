import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/settings_service.dart';

enum AppTheme {
  simpleDark,
  simpleLight,
  sakura,
  galaxy,
  tetris,
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
  bg:           Color(0xFF13161C),
  surface:      Color(0xFF1E222B),
  fg:           Color(0xFFE7EAF1),
  accent:       Color(0xFF7D97FF),
  accentBright: Color(0xFF9FB2FF),
  muted:        Color(0xFF8B94A4),
  pillBg:       Color(0xFF252830),
  btnBg:        Color(0xFF1E222B),
  kanjiColor:   Color(0xFFE7EAF1),
  correct:      Color(0xFF56CD8C),
  correctBg:    Color(0xFF18281F),
  incorrect:    Color(0xFFF47A8C),
  incorrectBg:  Color(0xFF281A20),
  buttonRadius: 12.0, containerRadius: 12.0,
);

const simpleLightTheme = ThemeColors(
  name: 'Simple Light',
  bg:           Color(0xFFF4F5F8),
  surface:      Color(0xFFFFFFFF),
  fg:           Color(0xFF161A22),
  accent:       Color(0xFF3258E8),
  accentBright: Color(0xFF6E8CFF),
  muted:        Color(0xFF697080),
  pillBg:       Color(0xFFE6E8EE),
  btnBg:        Color(0xFFFFFFFF),
  kanjiColor:   Color(0xFF161A22),
  correct:      Color(0xFF15924E),
  correctBg:    Color(0xFFE9F7EF),
  incorrect:    Color(0xFFD23449),
  incorrectBg:  Color(0xFFFCEBED),
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
  bg:           Color(0xFF05060F),
  surface:      Color(0xFF14151E),
  fg:           Color(0xFFEAF0FF),
  accent:       Color(0xFF3FE3EC),
  accentBright: Color(0xFF9B6CFF),
  muted:        Color(0xFF94A6CF),
  pillBg:       Color(0xFF191A23),
  btnBg:        Color(0xFF14151E),
  kanjiColor:   Color(0xFFEAF0FF),
  correct:      Color(0xFF3FE8A6),
  correctBg:    Color(0xFF0C2322),
  incorrect:    Color(0xFFFF6F92),
  incorrectBg:  Color(0xFF251320),
  buttonRadius: 12.0, containerRadius: 12.0,
);

const tetrisTheme = ThemeColors(
  name: 'Colorful Bricks',
  bg:           Color(0xFF0A0C1C),
  surface:      Color(0xFF191E3C),
  fg:           Color(0xFFEEF0FF),
  accent:       Color(0xFF00E0E0),
  accentBright: Color(0xFFFFE14D),
  muted:        Color(0xFF8290CF),
  pillBg:       Color(0xFF0C1024),
  btnBg:        Color(0xFF191E3C),
  kanjiColor:   Color(0xFFEEF0FF),
  correct:      Color(0xFF4DFF6A),
  correctBg:    Color(0xFF152514),
  incorrect:    Color(0xFFFF5277),
  incorrectBg:  Color(0xFF28111A),
  buttonRadius: 2.0, containerRadius: 2.0,
);


const loveletterTheme = ThemeColors(
  name: 'Love Letter',
  bg:           Color(0xFFF1F5FA),
  surface:      Color(0xFFFFFFFF),
  fg:           Color(0xFF33414F),
  accent:       Color(0xFF6F97C4),
  accentBright: Color(0xFFA9C4DD),
  muted:        Color(0xFF8896A4),
  pillBg:       Color(0xFFE9F0F8),
  btnBg:        Color(0xFFFFFFFF),
  kanjiColor:   Color(0xFF33414F),
  correct:      Color(0xFF5B9E7A),
  correctBg:    Color(0xFFE8F3ED),
  incorrect:    Color(0xFFC47A86),
  incorrectBg:  Color(0xFFF7EBEE),
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
  bg:           Color(0xFF070627),
  surface:      Color(0xFF160A3A),
  fg:           Color(0xFFE9E6FF),
  accent:       Color(0xFF35E0FF),
  accentBright: Color(0xFFFF5ED6),
  muted:        Color(0xFF9A8FCE),
  pillBg:       Color(0xFF1A1045),
  btnBg:        Color(0xFF0F0824),
  kanjiColor:   Color(0xFFE9E6FF),
  correct:      Color(0xFF46E8A0),
  correctBg:    Color(0xFF0A2020),
  incorrect:    Color(0xFFFF5D8A),
  incorrectBg:  Color(0xFF200A18),
  buttonRadius: 14.0, containerRadius: 14.0,
);

const themeColorMap = {
  AppTheme.simpleDark:   simpleDarkTheme,
  AppTheme.simpleLight:  simpleLightTheme,
  AppTheme.sakura:       sakuraTheme,
  AppTheme.galaxy:       galaxyTheme,
  AppTheme.tetris:       tetrisTheme,
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
