import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyMode = 'pref_mode';
  static const _keyLevels = 'pref_levels';
  static const _keyTags = 'pref_tags';
  static const _keyCount = 'pref_count';
  static const _keyMinDiff = 'pref_min_diff';
  static const _keyMaxDiff = 'pref_max_diff';
  static const _keyMultipleChoice = 'pref_multiple_choice';

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'mode': prefs.getString(_keyMode) ?? 'sentence',
      'levels': (prefs.getStringList(_keyLevels) ?? ['1', '2', '3', '4'])
          .map(int.parse)
          .toSet(),
      'tags': (prefs.getStringList(_keyTags) ?? []).toSet(),
      'count': prefs.getInt(_keyCount) ?? 20,
      'minDifficulty': prefs.getInt(_keyMinDiff) ?? 1,
      'maxDifficulty': prefs.getInt(_keyMaxDiff) ?? 4,
      'multipleChoice': prefs.getBool(_keyMultipleChoice) ?? true,
    };
  }

  static Future<void> save({
    required String mode,
    required Set<int> levels,
    required Set<String> tags,
    required int count,
    required int minDifficulty,
    required int maxDifficulty,
    required bool multipleChoice,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode);
    await prefs.setStringList(_keyLevels, levels.map((l) => l.toString()).toList());
    await prefs.setStringList(_keyTags, tags.toList());
    await prefs.setInt(_keyCount, count);
    await prefs.setInt(_keyMinDiff, minDifficulty);
    await prefs.setInt(_keyMaxDiff, maxDifficulty);
    await prefs.setBool(_keyMultipleChoice, multipleChoice);
  }
}
