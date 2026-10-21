import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../utils/learning_constants.dart';

class AutoProgressionResult {
  final int addedKanji;
  final int addedVocab;
  final int addedKana;
  final List<int> newlyCompletedKanjiLevels; // jlpt_level values (5=N5, 1=N1)
  final List<int> newlyCompletedVocabLevels;

  const AutoProgressionResult({
    this.addedKanji = 0,
    this.addedVocab = 0,
    this.addedKana = 0,
    this.newlyCompletedKanjiLevels = const [],
    this.newlyCompletedVocabLevels = const [],
  });

  bool get hasCompletions =>
      newlyCompletedKanjiLevels.isNotEmpty || newlyCompletedVocabLevels.isNotEmpty;
}

class AutoProgressionService {
  /// Run auto-progression. Returns result + updated settings (caller must save settings).
  Future<({AutoProgressionResult result, AppSettings updatedSettings})> run({
    required AppSettings settings,
  }) async {
    if (!settings.autoProgressionEnabled) {
      return (result: const AutoProgressionResult(), updatedSettings: settings);
    }

    var updatedSettings = settings;
    int addedKanji = 0;
    int addedVocab = 0;
    int addedKana = 0;
    final day = practiceDayKey();

    // ── Staged daily intake: hiragana → katakana+vocab → kanji+vocab ──────
    // New items enter rotation here as srs_box=1 / srs_due=today, capped per
    // track per day via a SharedPreferences counter. Stage is determined by
    // kana state so we check that first.
    final hiraganaProgress = await kanaRepo.getProgress(type: 'hiragana');
    final allHiraganaLearned = hiraganaProgress.learned >= hiraganaProgress.total;

    if (!allHiraganaLearned) {
      // Stage 1: only introduce hiragana.
      addedKana = await _introduceKanaDaily(type: 'hiragana', day: day);
    } else {
      final katakanaProgress = await kanaRepo.getProgress(type: 'katakana');
      final allKatakanaLearned = katakanaProgress.learned >= katakanaProgress.total;

      if (!allKatakanaLearned) {
        // Stage 2: introduce katakana + vocab; skip kanji.
        addedKana = await _introduceKanaDaily(type: 'katakana', day: day);
        addedVocab = await introduceDaily(
          track: 'vocab',
          quota: settings.autoProgressionVocabQuota,
          day: day,
        );
      } else {
        // Stage 3: all kana learned — introduce kanji + vocab.
        addedKanji = await introduceDaily(
          track: 'kanji',
          quota: settings.autoProgressionKanjiQuota,
          day: day,
        );
        addedVocab = await introduceDaily(
          track: 'vocab',
          quota: settings.autoProgressionVocabQuota,
          day: day,
        );
      }
    }

    // ── Level completion detection ────────────────────────────────────────
    final newlyCompletedKanji = <int>[];
    final newlyCompletedVocab = <int>[];

    final kanjiProgress = await kanjiRepo.getProgressByLevel();
    for (final level in [5, 4, 3, 2, 1]) {
      if (settings.completedKanjiLevels.contains(level)) continue;
      final p = kanjiProgress[level];
      if (p != null && p.total > 0 && p.learned >= p.total) {
        newlyCompletedKanji.add(level);
      }
    }

    final vocabProgress = await vocabRepo.getProgressByLevel();
    for (final level in [5, 4, 3, 2, 1]) {
      if (settings.completedVocabLevels.contains(level)) continue;
      final p = vocabProgress[level];
      if (p != null && p.total > 0 && p.learned >= p.total) {
        newlyCompletedVocab.add(level);
      }
    }

    if (newlyCompletedKanji.isNotEmpty || newlyCompletedVocab.isNotEmpty) {
      updatedSettings = updatedSettings.copyWith(
        completedKanjiLevels: [
          ...updatedSettings.completedKanjiLevels,
          ...newlyCompletedKanji,
        ],
        completedVocabLevels: [
          ...updatedSettings.completedVocabLevels,
          ...newlyCompletedVocab,
        ],
      );
    }

    return (
      result: AutoProgressionResult(
        addedKanji: addedKanji,
        addedVocab: addedVocab,
        addedKana: addedKana,
        newlyCompletedKanjiLevels: newlyCompletedKanji,
        newlyCompletedVocabLevels: newlyCompletedVocab,
      ),
      updatedSettings: updatedSettings,
    );
  }

  /// Promote up to the remaining daily quota of unseen items (srs_box=0, not
  /// learned) into rotation (srs_box=1, srs_due=day) in frequency order
  /// (jlpt_level DESC, id ASC). Daily cap tracked via SharedPreferences key
  /// 'srs_new_<track>_<day>'. Returns the number actually introduced.
  /// track ∈ {'kanji','vocab'}.
  Future<int> introduceDaily({
    required String track,
    required int quota,
    required String day,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'srs_new_${track}_$day';
    final used = prefs.getInt(key) ?? 0;
    final remaining = quota - used;
    if (remaining <= 0) return 0;

    final db = await dbService.database;
    int introduced = 0;

    if (track == 'kanji') {
      final rows = await db.rawQuery('''
        SELECT k.id FROM kanji k
        LEFT JOIN user_progress p ON k.id = p.kanji_id
        WHERE COALESCE(p.srs_box, 0) = 0
          AND COALESCE(p.status, 'unlearned') != 'learned'
        ORDER BY k.jlpt_level DESC, k.id ASC
        LIMIT ?
      ''', [remaining]);
      if (rows.isEmpty) return 0;
      final batch = db.batch();
      for (final r in rows) {
        batch.rawInsert('''
          INSERT INTO user_progress (kanji_id, status, srs_box, srs_due, srs_last_review)
          VALUES (?, 'target', 1, ?, NULL)
          ON CONFLICT(kanji_id) DO UPDATE SET
            status = 'target', srs_box = 1, srs_due = ?, srs_last_review = NULL
        ''', [r['id'], day, day]);
      }
      await batch.commit(noResult: true);
      introduced = rows.length;
    } else if (track == 'vocab') {
      final rows = await db.rawQuery('''
        SELECT v.id FROM vocabulary v
        LEFT JOIN vocabulary_progress p ON v.id = p.vocab_id
        WHERE COALESCE(p.srs_box, 0) = 0
          AND p.learned_at IS NULL
        ORDER BY v.jlpt_level DESC, v.id ASC
        LIMIT ?
      ''', [remaining]);
      if (rows.isEmpty) return 0;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final r in rows) {
        batch.rawInsert('''
          INSERT INTO vocabulary_progress (vocab_id, srs_box, srs_due, srs_last_review)
          VALUES (?, 1, ?, NULL)
          ON CONFLICT(vocab_id) DO UPDATE SET
            srs_box = 1, srs_due = ?, srs_last_review = NULL
        ''', [r['id'], day, day]);
        batch.rawInsert(
          'INSERT OR IGNORE INTO vocabulary_targets (vocab_id, added_at) VALUES (?, ?)',
          [r['id'], now],
        );
      }
      await batch.commit(noResult: true);
      introduced = rows.length;
    } else {
      return 0;
    }

    await prefs.setInt(key, used + introduced);
    return introduced;
  }

  /// Staged kana intake: promote up to (15 - usedToday) unseen kana of [type]
  /// into rotation (status='target', srs_box=1, srs_due=day). Daily cap tracked
  /// via SharedPreferences key 'srs_new_kana_<day>' (shared across kana types,
  /// which are stage-exclusive). Returns the number introduced.
  Future<int> _introduceKanaDaily({
    required String type,
    required String day,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'srs_new_kana_$day';
    final used = prefs.getInt(key) ?? 0;
    final remaining = 15 - used;
    if (remaining <= 0) return 0;

    final nextKana = await kanaRepo.getNextUntargetedKana(remaining, type: type);
    if (nextKana.isEmpty) return 0;

    final db = await dbService.database;
    final batch = db.batch();
    for (final ch in nextKana) {
      batch.rawInsert('''
        INSERT INTO kana_progress (kana_id, status, srs_box, srs_due, srs_last_review)
        VALUES (?, 'target', 1, ?, NULL)
        ON CONFLICT(kana_id) DO UPDATE SET
          status = 'target', srs_box = 1, srs_due = ?, srs_last_review = NULL
      ''', [ch.id, day, day]);
    }
    await batch.commit(noResult: true);
    await prefs.setInt(key, used + nextKana.length);
    return nextKana.length;
  }
}

final autoProgressionService = AutoProgressionService();
