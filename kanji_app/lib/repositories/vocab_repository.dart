import 'dart:convert';
import '../services/database_service.dart';

class VocabWord {
  final int id;
  final String word;           // kanji form (e.g. 猫), equals reading if no kanji
  final String reading;        // hiragana (e.g. ねこ)
  final String meanings;       // primary display meaning (e.g. "cat")
  final List<String> acceptableAnswers;
  final int jlptLevel;         // 5=N5 … 1=N1
  final List<String> tags;

  const VocabWord({
    required this.id,
    required this.word,
    required this.reading,
    required this.meanings,
    required this.acceptableAnswers,
    required this.jlptLevel,
    required this.tags,
  });

  factory VocabWord.fromMap(Map<String, dynamic> m) {
    List<String> parseJsonList(String? raw) {
      if (raw == null || raw.isEmpty) return [];
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.cast<String>();
      } catch (_) {}
      return [];
    }

    return VocabWord(
      id: m['id'] as int,
      word: m['word'] as String,
      reading: m['reading'] as String,
      meanings: m['meanings'] as String? ?? '',
      acceptableAnswers: parseJsonList(m['acceptable_answers'] as String?),
      jlptLevel: m['jlpt_level'] as int,
      tags: parseJsonList(m['tags'] as String?),
    );
  }
}

class VocabRepository {
  Future<List<VocabWord>> getAllVocab() async {
    final rows = await dbService.query(
      'SELECT * FROM vocabulary ORDER BY jlpt_level DESC, id ASC',
    );
    return rows.map(VocabWord.fromMap).toList();
  }

  Future<List<VocabWord>> getVocabByLevel(int level) async {
    final rows = await dbService.query(
      'SELECT * FROM vocabulary WHERE jlpt_level = ? ORDER BY id ASC',
      [level],
    );
    return rows.map(VocabWord.fromMap).toList();
  }

  Future<List<VocabWord>> getVocabByTag(String tag) async {
    final rows = await dbService.query(
      '''SELECT v.* FROM vocabulary v
         JOIN vocabulary_tags vt ON v.id = vt.vocab_id
         WHERE vt.tag = ?
         ORDER BY v.jlpt_level DESC, v.id ASC''',
      [tag],
    );
    return rows.map(VocabWord.fromMap).toList();
  }

  Future<List<String>> getAllTags() async {
    final rows = await dbService.query(
      'SELECT DISTINCT tag FROM vocabulary_tags ORDER BY tag',
    );
    return rows.map((r) => r['tag'] as String).toList();
  }

  Future<Set<int>> getTargetIds() async {
    final rows = await dbService.query(
      'SELECT vocab_id FROM vocabulary_targets ORDER BY vocab_id',
    );
    return rows.map((r) => r['vocab_id'] as int).toSet();
  }

  Future<void> toggleTarget(int vocabId, bool currentlyTargeted) async {
    if (currentlyTargeted) {
      await dbService.execute(
        'DELETE FROM vocabulary_targets WHERE vocab_id = ?',
        [vocabId],
      );
    } else {
      await dbService.execute(
        'INSERT OR IGNORE INTO vocabulary_targets (vocab_id, added_at) VALUES (?, ?)',
        [vocabId, DateTime.now().millisecondsSinceEpoch],
      );
    }
  }

  Future<void> selectAllTargets(List<int> ids) async {
    final db = await dbService.database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in ids) {
      batch.rawInsert(
        'INSERT OR IGNORE INTO vocabulary_targets (vocab_id, added_at) VALUES (?, ?)',
        [id, now],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deselectAllTargets(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await dbService.execute(
      'DELETE FROM vocabulary_targets WHERE vocab_id IN ($placeholders)',
      ids,
    );
  }

  Future<List<VocabWord>> getTargetVocab() async {
    final rows = await dbService.query(
      '''SELECT v.* FROM vocabulary v
         JOIN vocabulary_targets vt ON v.id = vt.vocab_id
         ORDER BY v.jlpt_level DESC, v.id ASC''',
    );
    return rows.map(VocabWord.fromMap).toList();
  }

  /// Returns [count] random words from [jlptLevel], excluding [excludeIds].
  Future<List<VocabWord>> getDistractors({
    required int jlptLevel,
    required int count,
    required List<int> excludeIds,
  }) async {
    String excludeClause = '';
    List<dynamic> args = [jlptLevel, count];
    if (excludeIds.isNotEmpty) {
      final placeholders = List.filled(excludeIds.length, '?').join(',');
      excludeClause = 'AND id NOT IN ($placeholders)';
      args = [jlptLevel, ...excludeIds, count];
    }
    final rows = await dbService.query(
      'SELECT * FROM vocabulary WHERE jlpt_level = ? $excludeClause ORDER BY RANDOM() LIMIT ?',
      args,
    );
    return rows.map(VocabWord.fromMap).toList();
  }

  Future<void> markLearned(int vocabId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await dbService.execute(
      '''INSERT INTO vocabulary_progress (vocab_id, word_to_meaning, meaning_to_word, learned_at)
         VALUES (?, 1, 1, ?)
         ON CONFLICT(vocab_id) DO UPDATE SET word_to_meaning=1, meaning_to_word=1, learned_at=?''',
      [vocabId, now, now],
    );
  }

  Future<int> getTargetCount() async {
    final rows = await dbService.query(
      'SELECT COUNT(*) as cnt FROM vocabulary_targets',
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  /// Returns up to [count] vocab words not yet targeted and not yet learned,
  /// ordered N5→N1 by jlpt_level DESC, then by id ASC (frequency order).
  Future<List<VocabWord>> getNextUntargetedVocab(int count) async {
    if (count <= 0) return [];
    final rows = await dbService.query('''
      SELECT v.* FROM vocabulary v
      WHERE v.id NOT IN (SELECT vocab_id FROM vocabulary_targets)
      AND v.id NOT IN (
        SELECT vocab_id FROM vocabulary_progress WHERE learned_at IS NOT NULL
      )
      ORDER BY v.jlpt_level DESC, v.id ASC
      LIMIT ?
    ''', [count]);
    return rows.map(VocabWord.fromMap).toList();
  }

  Future<Set<int>> getLearnedIds() async {
    final rows = await dbService.query(
      'SELECT vocab_id FROM vocabulary_progress WHERE word_to_meaning = 1',
    );
    return rows.map((r) => r['vocab_id'] as int).toSet();
  }

  Future<Map<int, ({int learned, int total})>> getProgressByLevel() async {
    final totals = await dbService.query(
      'SELECT jlpt_level, COUNT(*) as cnt FROM vocabulary GROUP BY jlpt_level',
    );
    final learned = await dbService.query(
      '''SELECT v.jlpt_level, COUNT(*) as cnt FROM vocabulary v
         JOIN vocabulary_progress vp ON v.id = vp.vocab_id
         WHERE vp.word_to_meaning = 1
         GROUP BY v.jlpt_level''',
    );
    final learnedMap = <int, int>{};
    for (final r in learned) {
      learnedMap[r['jlpt_level'] as int] = r['cnt'] as int;
    }
    final result = <int, ({int learned, int total})>{};
    for (final r in totals) {
      final level = r['jlpt_level'] as int;
      result[level] = (learned: learnedMap[level] ?? 0, total: r['cnt'] as int);
    }
    return result;
  }

  Future<List<VocabWord>> getVocabByLevels(List<int> levels, {int? limit}) async {
    if (levels.isEmpty) return [];
    final placeholders = List.filled(levels.length, '?').join(',');
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final rows = await dbService.query(
      'SELECT * FROM vocabulary WHERE jlpt_level IN ($placeholders) ORDER BY jlpt_level DESC, id ASC $limitClause',
      levels,
    );
    return rows.map(VocabWord.fromMap).toList();
  }

  Future<List<VocabWord>> getVocabByTagsAndLevels({
    required List<String> tags,
    required List<int> levels,
    int? limit,
  }) async {
    if (tags.isEmpty) return getVocabByLevels(levels, limit: limit);
    final tagPlaceholders = List.filled(tags.length, '?').join(',');
    final levelPlaceholders = List.filled(levels.length, '?').join(',');
    final levelClause = levels.isNotEmpty ? 'AND v.jlpt_level IN ($levelPlaceholders)' : '';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final args = [...tags, if (levels.isNotEmpty) ...levels];
    final rows = await dbService.query(
      '''SELECT DISTINCT v.* FROM vocabulary v
         JOIN vocabulary_tags vt ON v.id = vt.vocab_id
         WHERE vt.tag IN ($tagPlaceholders) $levelClause
         ORDER BY v.jlpt_level DESC, v.id ASC $limitClause''',
      args,
    );
    return rows.map(VocabWord.fromMap).toList();
  }

  Future<Map<String, ({int learned, int total})>> getProgressByTag() async {
    final totals = await dbService.query('''
      SELECT vt.tag, COUNT(*) as total
      FROM vocabulary_tags vt
      GROUP BY vt.tag
      ORDER BY vt.tag
    ''');
    final learnedRows = await dbService.query('''
      SELECT vt.tag, COUNT(*) as cnt
      FROM vocabulary_tags vt
      JOIN vocabulary_progress vp ON vt.vocab_id = vp.vocab_id
      WHERE vp.word_to_meaning = 1
      GROUP BY vt.tag
    ''');
    final learnedMap = <String, int>{};
    for (final r in learnedRows) {
      learnedMap[r['tag'] as String] = r['cnt'] as int;
    }
    final result = <String, ({int learned, int total})>{};
    for (final r in totals) {
      final tag = r['tag'] as String;
      result[tag] = (learned: learnedMap[tag] ?? 0, total: r['total'] as int);
    }
    return result;
  }

  /// Returns vocab words whose `word` field contains any of the given kanji characters.
  Future<List<VocabWord>> getVocabContainingKanji(Set<String> chars) async {
    if (chars.isEmpty) return [];
    final conditions = chars.map((_) => 'word LIKE ?').join(' OR ');
    final args = chars.map((c) => '%$c%').toList();
    final rows = await dbService.query(
      'SELECT * FROM vocabulary WHERE $conditions ORDER BY jlpt_level DESC, id ASC',
      args,
    );
    return rows.map(VocabWord.fromMap).toList();
  }
}

final vocabRepo = VocabRepository();
