import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_route.dart';

const englishFonts = {'Inter': 'Inter', 'System Default': 'system'};
const japaneseFonts = {'Noto Serif CJK JP': 'NotoSerifCJKjp', 'System Default': 'system'};

class AppSettings {
  final int difficultyMin;
  final int difficultyMax;
  final int sessionSize;
  final int autoNextDelaySeconds;
  final String ambientSfx;
  final double ambientVolume;
  final double sfxVolume;
  final bool sfxEnabled;
  final bool ambientEnabled;
  final bool animationsEnabled;
  final String englishFont;
  final String japaneseFont;
  final String homeKanjiProgress; // 'total' | 'N5'..'N1' | tag name
  final String homeVocabProgress;  // 'total' | 'N5'..'N1'
  final bool hideKanaPractice;

  const AppSettings({
    this.difficultyMin = 1,
    this.difficultyMax = 9,
    this.sessionSize = 20,
    this.autoNextDelaySeconds = 3,
    this.ambientSfx = 'none',
    this.ambientVolume = 0.5,
    this.sfxVolume = 0.5,
    this.sfxEnabled = true,
    this.ambientEnabled = true,
    this.animationsEnabled = true,
    this.englishFont = 'Inter',
    this.japaneseFont = 'NotoSerifCJKjp',
    this.homeKanjiProgress = 'total',
    this.homeVocabProgress = 'total',
    this.hideKanaPractice = false,
  });

  AppSettings copyWith({
    int? difficultyMin,
    int? difficultyMax,
    int? sessionSize,
    int? autoNextDelaySeconds,
    String? ambientSfx,
    double? ambientVolume,
    double? sfxVolume,
    bool? sfxEnabled,
    bool? ambientEnabled,
    bool? animationsEnabled,
    String? englishFont,
    String? japaneseFont,
    String? homeKanjiProgress,
    String? homeVocabProgress,
    bool? hideKanaPractice,
  }) => AppSettings(
    difficultyMin: difficultyMin ?? this.difficultyMin,
    difficultyMax: difficultyMax ?? this.difficultyMax,
    sessionSize: sessionSize ?? this.sessionSize,
    autoNextDelaySeconds: autoNextDelaySeconds ?? this.autoNextDelaySeconds,
    ambientSfx: ambientSfx ?? this.ambientSfx,
    ambientVolume: ambientVolume ?? this.ambientVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
    sfxEnabled: sfxEnabled ?? this.sfxEnabled,
    ambientEnabled: ambientEnabled ?? this.ambientEnabled,
    animationsEnabled: animationsEnabled ?? this.animationsEnabled,
    englishFont: englishFont ?? this.englishFont,
    japaneseFont: japaneseFont ?? this.japaneseFont,
    homeKanjiProgress: homeKanjiProgress ?? this.homeKanjiProgress,
    homeVocabProgress: homeVocabProgress ?? this.homeVocabProgress,
    hideKanaPractice: hideKanaPractice ?? this.hideKanaPractice,
  );

  Map<String, dynamic> toJson() => {
    'difficultyMin': difficultyMin,
    'difficultyMax': difficultyMax,
    'sessionSize': sessionSize,
    'autoNextDelaySeconds': autoNextDelaySeconds,
    'ambientSfx': ambientSfx,
    'ambientVolume': ambientVolume,
    'sfxVolume': sfxVolume,
    'sfxEnabled': sfxEnabled,
    'ambientEnabled': ambientEnabled,
    'animationsEnabled': animationsEnabled,
    'englishFont': englishFont,
    'japaneseFont': japaneseFont,
    'homeKanjiProgress': homeKanjiProgress,
    'homeVocabProgress': homeVocabProgress,
    'hideKanaPractice': hideKanaPractice,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    difficultyMin: j['difficultyMin'] as int? ?? 1,
    difficultyMax: j['difficultyMax'] as int? ?? 9,
    sessionSize: j['sessionSize'] as int? ?? 20,
    autoNextDelaySeconds: j['autoNextDelaySeconds'] as int? ?? 3,
    ambientSfx: j['ambientSfx'] as String? ?? 'none',
    ambientVolume: (j['ambientVolume'] as num?)?.toDouble() ?? 0.5,
    sfxVolume: (j['sfxVolume'] as num?)?.toDouble() ?? 0.5,
    sfxEnabled: j['sfxEnabled'] as bool? ?? true,
    ambientEnabled: j['ambientEnabled'] as bool? ?? true,
    animationsEnabled: j['animationsEnabled'] as bool? ?? true,
    englishFont: j['englishFont'] as String? ?? 'Inter',
    japaneseFont: j['japaneseFont'] as String? ?? 'NotoSerifCJKjp',
    homeKanjiProgress: j['homeKanjiProgress'] as String? ?? 'total',
    homeVocabProgress: j['homeVocabProgress'] as String? ?? 'total',
    hideKanaPractice: j['hideKanaPractice'] as bool? ?? false,
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File(join(dir.path, 'settings.json'));
  }

  Future<void> _load() async {
    final f = await _file;
    if (await f.exists()) {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      state = AppSettings.fromJson(j);
      AppRoute.animationsEnabled = state.animationsEnabled;
    }
  }

  Future<void> update(AppSettings s) async {
    state = s;
    AppRoute.animationsEnabled = s.animationsEnabled;
    final f = await _file;
    await f.writeAsString(jsonEncode(s.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// Appearance Settings Service
class AppearanceSettingsService {
  static const String _fontSizeKey = 'fontSize';
  static const String _contrastKey = 'contrast';
  static const String _spacingKey = 'spacing';

  final SharedPreferences prefs;

  AppearanceSettingsService(this.prefs);

  // Font size: 0.8, 1.0, 1.2, 1.5
  double getFontSize() => prefs.getDouble(_fontSizeKey) ?? 1.0;
  Future<void> setFontSize(double size) => prefs.setDouble(_fontSizeKey, size);

  // Contrast: 'normal', 'high', 'ultra'
  String getContrast() => prefs.getString(_contrastKey) ?? 'normal';
  Future<void> setContrast(String contrast) => prefs.setString(_contrastKey, contrast);

  // Spacing: 'compact', 'normal', 'spacious'
  String getSpacing() => prefs.getString(_spacingKey) ?? 'normal';
  Future<void> setSpacing(String spacing) => prefs.setString(_spacingKey, spacing);
}

final sharedPreferencesProvider = FutureProvider((ref) async {
  return await SharedPreferences.getInstance();
});

// Appearance settings notifier for real-time updates
class AppearanceSettingsNotifier extends Notifier<AppearanceSettingsService?> {
  @override
  AppearanceSettingsService? build() {
    _init();
    return null;
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppearanceSettingsService(prefs);
  }
}

final appearanceSettingsNotifierProvider =
    NotifierProvider<AppearanceSettingsNotifier, AppearanceSettingsService?>(
  AppearanceSettingsNotifier.new,
);

// Synchronous provider for appearance settings (returns null until loaded)
final appearanceSettingsProvider = Provider((ref) {
  return ref.watch(appearanceSettingsNotifierProvider);
});
