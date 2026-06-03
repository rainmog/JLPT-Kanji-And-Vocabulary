import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelBounds {
  final List<int> learnedLevels;
  final List<int> targetAllLevels;
  final int targetSampleLevel;

  const LevelBounds({
    required this.learnedLevels,
    required this.targetAllLevels,
    required this.targetSampleLevel,
  });
}

class OnboardingService {
  static const _allLevels = [5, 4, 3, 2, 1];

  /// Review mode: levels 2+ below → learned; level immediately below → all target; L → sample.
  /// Levels: 5=N5 (easiest), 1=N1 (hardest). "Below" = higher number (easier).
  static LevelBounds levelBoundsForReview(int level) {
    final oneBelow = level + 1;
    final twoAndMoreBelow = _allLevels.where((l) => l > oneBelow).toList();
    final hasOneBelow = _allLevels.contains(oneBelow);
    return LevelBounds(
      learnedLevels: twoAndMoreBelow,
      targetAllLevels: hasOneBelow ? [oneBelow] : [],
      targetSampleLevel: level,
    );
  }

  /// New-stuff mode: all easier levels → learned; L → sample target.
  static LevelBounds levelBoundsForNewStuff(int level) {
    final easierLevels = _allLevels.where((l) => l > level).toList();
    return LevelBounds(
      learnedLevels: easierLevels,
      targetAllLevels: [],
      targetSampleLevel: level,
    );
  }

  /// Applies the given [bounds] to the DB.
  static Future<void> applyBounds(
    LevelBounds bounds, {
    int kanjiSampleCount = 10,
    int vocabSampleCount = 20,
  }) async {
    final db = dbService;

    // Set learned levels
    for (final level in bounds.learnedLevels) {
      await db.execute('''
        UPDATE user_progress SET status='learned'
        WHERE kanji_id IN (SELECT id FROM kanji WHERE jlpt_level=?)
      ''', [level]);
      await db.execute('''
        INSERT OR IGNORE INTO vocabulary_progress (vocab_id, word_to_meaning, meaning_to_word, learned_at)
        SELECT id, 1, 1, strftime('%s','now') FROM vocabulary WHERE jlpt_level=?
      ''', [level]);
    }

    // Set target-all levels
    for (final level in bounds.targetAllLevels) {
      await db.execute('''
        UPDATE user_progress SET status='target'
        WHERE kanji_id IN (SELECT id FROM kanji WHERE jlpt_level=?)
        AND status='unlearned'
      ''', [level]);
      final vocabIds = await db.query(
        'SELECT id FROM vocabulary WHERE jlpt_level=?', [level],
      );
      for (final row in vocabIds) {
        await db.execute('''
          INSERT OR IGNORE INTO vocabulary_targets (vocab_id, added_at)
          VALUES (?, strftime('%s','now'))
        ''', [row['id']]);
      }
    }

    // Set sample targets for the chosen level
    final kanjiIds = await db.query('''
      SELECT id FROM kanji WHERE jlpt_level=? ORDER BY id ASC LIMIT ?
    ''', [bounds.targetSampleLevel, kanjiSampleCount]);

    for (final row in kanjiIds) {
      await db.execute(
        "UPDATE user_progress SET status='target' WHERE kanji_id=? AND status='unlearned'",
        [row['id']],
      );
    }

    final vocabIds = await db.query('''
      SELECT id FROM vocabulary WHERE jlpt_level=? ORDER BY id ASC LIMIT ?
    ''', [bounds.targetSampleLevel, vocabSampleCount]);

    for (final row in vocabIds) {
      await db.execute('''
        INSERT OR IGNORE INTO vocabulary_targets (vocab_id, added_at)
        VALUES (?, strftime('%s','now'))
      ''', [row['id']]);
    }
  }

  /// Sets N5 vocab/kanji targets by count.
  static Future<void> applyN5Targets({
    required int kanjiCount,
    required int vocabCount,
  }) async {
    final db = dbService;

    if (kanjiCount > 0) {
      final kanjiIds = await db.query('''
        SELECT id FROM kanji WHERE jlpt_level=5 ORDER BY id ASC LIMIT ?
      ''', [kanjiCount]);
      for (final row in kanjiIds) {
        await db.execute(
          "UPDATE user_progress SET status='target' WHERE kanji_id=?",
          [row['id']],
        );
      }
    }

    if (vocabCount > 0) {
      final vocabIds = await db.query('''
        SELECT id FROM vocabulary WHERE jlpt_level=5 ORDER BY id ASC LIMIT ?
      ''', [vocabCount]);
      for (final row in vocabIds) {
        await db.execute('''
          INSERT OR IGNORE INTO vocabulary_targets (vocab_id, added_at)
          VALUES (?, strftime('%s','now'))
        ''', [row['id']]);
      }
    }
  }

  /// N4/3/2/1 direct: all easier levels → learned; 10 kanji + 30 vocab from selected → target.
  static Future<void> applyLevelTargets({required int level}) async {
    final easierLevels = _allLevels.where((l) => l > level).toList();
    await applyBounds(
      LevelBounds(
        learnedLevels: easierLevels,
        targetAllLevels: [],
        targetSampleLevel: level,
      ),
      kanjiSampleCount: 10,
      vocabSampleCount: 30,
    );
  }

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboardingComplete') ?? false;
  }
}
