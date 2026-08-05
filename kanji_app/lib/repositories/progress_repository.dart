import '../services/database_service.dart';
import '../utils/learning_constants.dart';

class ProgressRepository {
  Future<Map<String, dynamic>?> getProgress(int kanjiId) async {
    final rows = await dbService.query(
      'SELECT * FROM user_progress WHERE kanji_id = ?', [kanjiId]
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markLearned(int kanjiId) async {
    await dbService.execute('''
      INSERT INTO user_progress (kanji_id, status, consecutive_correct, practice_correct_count)
      VALUES (?, 'learned', 0, 0)
      ON CONFLICT(kanji_id) DO UPDATE SET status='learned', consecutive_correct=0, practice_correct_count=0
    ''', [kanjiId]);
  }

  Future<void> markTarget(int kanjiId) async {
    await dbService.execute('''
      INSERT INTO user_progress (kanji_id, status)
      VALUES (?, 'target')
      ON CONFLICT(kanji_id) DO UPDATE SET status='target'
    ''', [kanjiId]);
  }

  Future<void> markUnlearned(int kanjiId) async {
    await dbService.execute('''
      INSERT INTO user_progress (kanji_id, status, consecutive_correct)
      VALUES (?, 'unlearned', 0)
      ON CONFLICT(kanji_id) DO UPDATE SET status='unlearned', consecutive_correct=0
    ''', [kanjiId]);
  }

  /// Bulk-target all unlearned kanji in [ids]. Learned kanji are untouched.
  Future<void> markAllTarget(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await dbService.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.rawInsert('''
        INSERT INTO user_progress (kanji_id, status)
        VALUES (?, 'target')
        ON CONFLICT(kanji_id) DO UPDATE SET
          status = CASE WHEN status != 'learned' THEN 'target' ELSE status END
      ''', [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Bulk-unlearn all targeted kanji in [ids]. Learned kanji are untouched.
  Future<void> markAllUnlearned(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await dbService.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.rawInsert('''
        INSERT INTO user_progress (kanji_id, status, consecutive_correct)
        VALUES (?, 'unlearned', 0)
        ON CONFLICT(kanji_id) DO UPDATE SET
          status = CASE WHEN status = 'target' THEN 'unlearned' ELSE status END,
          consecutive_correct = 0
      ''', [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Returns kanji_ids of all target kanji.
  Future<List<int>> getTargetKanjiIds() async {
    final rows = await dbService.query(
      "SELECT kanji_id FROM user_progress WHERE status='target' ORDER BY kanji_id"
    );
    return rows.map((r) => r['kanji_id'] as int).toList();
  }

  /// Returns character strings of all learned kanji (for furigana suppression).
  Future<Set<String>> getLearnedKanjiCharacters() async {
    final rows = await dbService.query('''
      SELECT k.character FROM kanji k
      JOIN user_progress p ON k.id = p.kanji_id
      WHERE p.status = 'learned'
    ''');
    return rows.map((r) => r['character'] as String).toSet();
  }

  Future<int> recordCorrect(int kanjiId) async {
    await dbService.execute('''
      UPDATE user_progress
      SET consecutive_correct = consecutive_correct + 1,
          total_seen = total_seen + 1,
          total_correct = total_correct + 1
      WHERE kanji_id = ?
    ''', [kanjiId]);
    final rows = await dbService.query(
      'SELECT consecutive_correct FROM user_progress WHERE kanji_id=?', [kanjiId]
    );
    return rows.isEmpty ? 0 : rows.first['consecutive_correct'] as int? ?? 0;
  }

  Future<void> recordIncorrect(int kanjiId) async {
    await dbService.execute('''
      UPDATE user_progress
      SET consecutive_correct = 0, total_seen = total_seen + 1
      WHERE kanji_id = ?
    ''', [kanjiId]);
  }

  Future<void> incrementPracticeCount(int kanjiId) async {
    await dbService.execute('''
      INSERT INTO user_progress (kanji_id, practice_correct_count)
      VALUES (?, 1)
      ON CONFLICT(kanji_id) DO UPDATE SET practice_correct_count = practice_correct_count + 1
    ''', [kanjiId]);
  }

  /// Practice-mode learning (spaced, points-based). Applies the daily-scaled
  /// points delta (first correct of day +5, repeats +1, wrong −1 floored 0),
  /// tracks per-day appearance counters, and promotes to 'learned' at
  /// [kPracticePointsToLearn]. See [applyPracticeAnswer].
  Future<PracticeResult> recordPracticeProgress(int kanjiId, {required bool isCorrect}) async {
    final today = practiceDayKey();
    // Ensure a row exists so the read-modify-write below has something to update.
    await dbService.execute('''
      INSERT INTO user_progress (kanji_id, status) VALUES (?, 'target')
      ON CONFLICT(kanji_id) DO NOTHING
    ''', [kanjiId]);
    final rows = await dbService.query(
      'SELECT status, practice_points, practice_day, practice_seen_today, practice_correct_today '
      'FROM user_progress WHERE kanji_id=?', [kanjiId]);
    if (rows.isEmpty) return (promoted: false, learned: false, points: 0, seenToday: 0, delta: 0);
    final status = rows.first['status'] as String?;
    final oldPoints = rows.first['practice_points'] as int? ?? 0;
    final next = applyPracticeAnswer(
      points: oldPoints,
      day: rows.first['practice_day'] as String?,
      seenToday: rows.first['practice_seen_today'] as int? ?? 0,
      correctToday: rows.first['practice_correct_today'] as int? ?? 0,
      today: today,
      isCorrect: isCorrect,
    );
    await dbService.execute('''
      UPDATE user_progress
      SET practice_points = ?, practice_day = ?, practice_seen_today = ?, practice_correct_today = ?
      WHERE kanji_id = ?
    ''', [next.points, today, next.seenToday, next.correctToday, kanjiId]);
    final delta = next.points - oldPoints;
    if (status != 'learned' && next.points >= kPracticePointsToLearn) {
      await markLearned(kanjiId);
      return (promoted: true, learned: true, points: next.points, seenToday: next.seenToday, delta: delta);
    }
    return (promoted: false, learned: status == 'learned', points: next.points, seenToday: next.seenToday, delta: delta);
  }

  // Kanji practice cap-exclusion + learned top-up are handled directly in
  // SentenceRepository.pickKanjiForSession (the single chokepoint for every
  // kanji practice mode), so no per-id helpers are needed here.

  Future<Map<int, int>> getPracticeCountsForIds(List<int> ids) async {
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await dbService.query(
      'SELECT kanji_id, COALESCE(practice_correct_count, 0) AS cnt FROM user_progress WHERE kanji_id IN ($placeholders)',
      ids,
    );
    return {for (final r in rows) r['kanji_id'] as int: r['cnt'] as int};
  }

  Future<int> getTotalAllTimeQuestionCount() async {
    final rows = await dbService.query(
      'SELECT SUM(COALESCE(question_count, 1)) as cnt FROM session_log',
    );
    return rows.first['cnt'] as int? ?? 0;
  }

  Future<int> getTodaySessionCount() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final rows = await dbService.query(
      'SELECT SUM(COALESCE(question_count, 1)) as cnt FROM session_log WHERE timestamp >= ?',
      [midnight],
    );
    return rows.first['cnt'] as int? ?? 0;
  }

  Future<void> logSession({
    required String mode,
    required List<int> kanjiIds,
    required int score,
    int questionCount = 0,
  }) async {
    await dbService.insert('session_log', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'mode': mode,
      'kanji_ids': kanjiIds.join(','),
      'score': score,
      'question_count': questionCount,
    });
  }
}

final progressRepo = ProgressRepository();
