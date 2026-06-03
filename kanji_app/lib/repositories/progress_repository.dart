import '../services/database_service.dart';

class ProgressRepository {
  Future<Map<String, dynamic>?> getProgress(int kanjiId) async {
    final rows = await dbService.query(
      'SELECT * FROM user_progress WHERE kanji_id = ?', [kanjiId]
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markLearned(int kanjiId) async {
    await dbService.execute(
      "UPDATE user_progress SET status='learned', consecutive_correct=0 WHERE kanji_id=?",
      [kanjiId]
    );
  }

  Future<void> markTarget(int kanjiId) async {
    await dbService.execute(
      "UPDATE user_progress SET status='target' WHERE kanji_id=?",
      [kanjiId]
    );
  }

  Future<void> markUnlearned(int kanjiId) async {
    await dbService.execute(
      "UPDATE user_progress SET status='unlearned', consecutive_correct=0 WHERE kanji_id=?",
      [kanjiId]
    );
  }

  /// Bulk-target all unlearned kanji in [ids]. Learned kanji are untouched.
  Future<void> markAllTarget(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await dbService.execute(
      "UPDATE user_progress SET status='target' WHERE kanji_id IN ($placeholders) AND status='unlearned'",
      ids,
    );
  }

  /// Bulk-unlearn all targeted kanji in [ids]. Learned kanji are untouched.
  Future<void> markAllUnlearned(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await dbService.execute(
      "UPDATE user_progress SET status='unlearned', consecutive_correct=0 WHERE kanji_id IN ($placeholders) AND status='target'",
      ids,
    );
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

  Future<void> logSession({
    required String mode,
    required List<int> kanjiIds,
    required int score,
  }) async {
    await dbService.insert('session_log', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'mode': mode,
      'kanji_ids': kanjiIds.join(','),
      'score': score,
    });
  }
}

final progressRepo = ProgressRepository();
