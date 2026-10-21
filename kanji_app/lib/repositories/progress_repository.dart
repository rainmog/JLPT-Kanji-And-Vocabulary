import '../services/database_service.dart';
import '../utils/learning_constants.dart';
import '../utils/srs_scheduler.dart';

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

  /// Stamp [ids] as practiced *now* (once per session, at session start). Drives
  /// least-recently-practiced rotation in [SentenceRepository.pickKanjiForSession]
  /// so the same items don't recur in back-to-back sessions.
  Future<void> markKanjiPracticed(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await dbService.execute(
      'UPDATE user_progress SET last_practiced_at = ? WHERE kanji_id IN ($placeholders)',
      [DateTime.now().millisecondsSinceEpoch, ...ids],
    );
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
  Future<PracticeResult> recordPracticeProgress(int kanjiId,
      {required bool isCorrect, bool countAppearance = true}) async {
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
      countAppearance: countAppearance,
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

  /// Leitner SRS review recording (kanji practice track). Advances/resets the
  /// item's box per [applySrsReview] and persists the new box/due. Only the
  /// first review of a day changes the schedule (same-day repeats are
  /// practice-only). A correct answer in the top box graduates the item to
  /// 'learned'. Returns the post-review [SrsReviewResult].
  Future<SrsReviewResult> recordSrsReview(int kanjiId,
      {required bool isCorrect}) async {
    final today = practiceDayKey();
    await dbService.execute(
      "INSERT INTO user_progress (kanji_id, status) VALUES (?, 'target') "
      "ON CONFLICT(kanji_id) DO NOTHING",
      [kanjiId],
    );
    final rows = await dbService.query(
      'SELECT status, srs_box, srs_last_review FROM user_progress WHERE kanji_id=?',
      [kanjiId],
    );
    if (rows.isEmpty) return (box: 0, learned: false, graduated: false);
    final status = rows.first['status'] as String?;
    final box = rows.first['srs_box'] as int? ?? 0;
    final u = applySrsReview(
      box: box,
      lastReview: rows.first['srs_last_review'] as String?,
      today: today,
      isCorrect: isCorrect,
    );
    if (!u.changed) {
      return (box: box, learned: status == 'learned', graduated: false);
    }
    if (u.learned) {
      await markLearned(kanjiId); // existing method: sets status='learned'
      await dbService.execute(
        'UPDATE user_progress SET srs_box=?, srs_last_review=? WHERE kanji_id=?',
        [kSrsBoxCount, today, kanjiId],
      );
      return (box: kSrsBoxCount, learned: true, graduated: true);
    }
    await dbService.execute(
      'UPDATE user_progress SET srs_box=?, srs_due=?, srs_last_review=? WHERE kanji_id=?',
      [u.box, u.due, today, kanjiId],
    );
    return (box: u.box, learned: false, graduated: false);
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

  /// Kanji ids of the most recent kanji-practice session (any kanji mode).
  /// Used to keep those items out of the very next session (anti back-to-back
  /// repeat). Empty on the first session ever.
  Future<List<int>> lastKanjiSessionIds() async {
    final rows = await dbService.query(
      "SELECT kanji_ids FROM session_log "
      "WHERE mode IN ('sentence','word','wordpractice') AND kanji_ids != '' "
      "ORDER BY timestamp DESC LIMIT 1",
    );
    if (rows.isEmpty) return const [];
    final csv = rows.first['kanji_ids'] as String? ?? '';
    return csv.split(',').where((s) => s.isNotEmpty).map(int.parse).toList();
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
