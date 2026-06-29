import '../services/database_service.dart';

class Kanji {
  final int id;
  final String character;
  final int jlptLevel;
  final String onReading;
  final String kunReading;
  final String meaning;
  final int strokeCount;
  final List<String> tags;

  const Kanji({required this.id, required this.character, required this.jlptLevel,
    required this.onReading, required this.kunReading, required this.meaning, required this.strokeCount,
    this.tags = const []});

  factory Kanji.fromMap(Map<String, dynamic> m) => Kanji(
    id: m['id'] as int,
    character: m['character'] as String,
    jlptLevel: m['jlpt_level'] as int,
    onReading: m['on_reading'] as String? ?? '',
    kunReading: m['kun_reading'] as String? ?? '',
    meaning: m['meaning'] as String? ?? '',
    strokeCount: m['stroke_count'] as int? ?? 0,
    tags: const [],
  );

  /// Create a copy with optionally replaced tags
  Kanji copyWithTags(List<String> newTags) => Kanji(
    id: id,
    character: character,
    jlptLevel: jlptLevel,
    onReading: onReading,
    kunReading: kunReading,
    meaning: meaning,
    strokeCount: strokeCount,
    tags: newTags,
  );
}

class KanjiRepository {
  Future<List<Kanji>> getNextUnlearned(int limit) async {
    final rows = await dbService.query('''
      SELECT k.* FROM kanji k
      JOIN user_progress p ON k.id = p.kanji_id
      WHERE p.status = 'unlearned'
      ORDER BY k.jlpt_level DESC, k.id ASC
      LIMIT ?
    ''', [limit]);
    return rows.map(Kanji.fromMap).toList();
  }

  Future<List<Kanji>> _getFilteredKanjiByStatus({
    required String status,
    required List<int> jlptLevels,
    List<String> tags = const [],
    required int limit,
    String orderBy = 'k.jlpt_level DESC, k.id ASC',
  }) async {
    final levelPlaceholders = List.filled(jlptLevels.length, '?').join(',');
    final args = <dynamic>[...jlptLevels];
    String tagJoin = '';
    if (tags.isNotEmpty) {
      tagJoin = 'JOIN kanji_tags kt ON k.id = kt.kanji_id AND kt.tag IN (${List.filled(tags.length, '?').join(',')})';
      args.addAll(tags);
    }
    args.add(limit);
    final rows = await dbService.query('''
      SELECT DISTINCT k.* FROM kanji k
      JOIN user_progress p ON k.id = p.kanji_id
      $tagJoin
      WHERE p.status = '$status' AND k.jlpt_level IN ($levelPlaceholders)
      ORDER BY $orderBy
      LIMIT ?
    ''', args);
    return rows.map(Kanji.fromMap).toList();
  }

  Future<List<Kanji>> getFilteredUnlearned({
    required List<int> jlptLevels,
    List<String> tags = const [],
    required int limit,
  }) async {
    return _getFilteredKanjiByStatus(
      status: 'unlearned',
      jlptLevels: jlptLevels,
      tags: tags,
      limit: limit,
    );
  }

  Future<List<Kanji>> getFilteredLearned({
    required List<int> jlptLevels,
    List<String> tags = const [],
    required int limit,
  }) async {
    return _getFilteredKanjiByStatus(
      status: 'learned',
      jlptLevels: jlptLevels,
      tags: tags,
      limit: limit,
      orderBy: 'RANDOM()',
    );
  }

  Future<List<String>> getAllTags() async {
    final rows = await dbService.query('SELECT DISTINCT tag FROM kanji_tags ORDER BY tag');
    return rows.map((r) => r['tag'] as String).toList();
  }

  /// Get tags for a specific kanji
  Future<List<String>> getTagsForKanji(int kanjiId) async {
    final rows = await dbService.query(
      'SELECT tag FROM kanji_tags WHERE kanji_id = ? ORDER BY tag',
      [kanjiId],
    );
    return rows.map((r) => r['tag'] as String).toList();
  }

  /// Get kanji IDs that have a specific tag
  Future<List<int>> getKanjiByTag(String tag) async {
    final rows = await dbService.query(
      'SELECT DISTINCT kanji_id FROM kanji_tags WHERE tag = ? ORDER BY kanji_id',
      [tag],
    );
    return rows.map((r) => r['kanji_id'] as int).toList();
  }

  /// Get kanji by multiple tags (any tag match), with tags loaded
  Future<List<Kanji>> getKanjiByTags(List<String> tags) async {
    if (tags.isEmpty) return [];

    final placeholders = List.filled(tags.length, '?').join(',');
    final rows = await dbService.query(
      'SELECT DISTINCT k.* FROM kanji k JOIN kanji_tags t ON k.id = t.kanji_id WHERE t.tag IN ($placeholders) ORDER BY k.id',
      tags,
    );

    if (rows.isEmpty) return [];

    // Batch-load all tags for the kanji in a single query
    final kanjiIds = rows.map((r) => r['id'] as int).toList();
    final idPlaceholders = List.filled(kanjiIds.length, '?').join(',');
    final tagsRows = await dbService.query(
      'SELECT kanji_id, tag FROM kanji_tags WHERE kanji_id IN ($idPlaceholders)',
      kanjiIds,
    );

    // Build map of kanji_id -> list of tags
    final tagsByKanjiId = <int, List<String>>{};
    for (final row in tagsRows) {
      final id = row['kanji_id'] as int;
      final tag = row['tag'] as String;
      tagsByKanjiId.putIfAbsent(id, () => []).add(tag);
    }

    final kanji = <Kanji>[];
    for (final row in rows) {
      final k = Kanji.fromMap(row);
      final kTags = tagsByKanjiId[k.id] ?? [];
      kanji.add(k.copyWithTags(kTags));
    }
    return kanji;
  }

  Future<Map<String, ({int learned, int total})>> getProgressByTag() async {
    final rows = await dbService.query('''
      SELECT kt.tag,
        COUNT(*) as total,
        SUM(CASE WHEN p.status='learned' THEN 1 ELSE 0 END) as learned
      FROM kanji_tags kt
      LEFT JOIN user_progress p ON kt.kanji_id = p.kanji_id
      GROUP BY kt.tag
      ORDER BY kt.tag
    ''');
    return {
      for (final r in rows)
        r['tag'] as String: (
          learned: (r['learned'] as int? ?? 0),
          total: r['total'] as int? ?? 0,
        )
    };
  }

  Future<List<Kanji>> getKanjiForTag(String tag) async {
    final rows = await dbService.query('''
      SELECT k.* FROM kanji k
      JOIN kanji_tags kt ON k.id = kt.kanji_id
      WHERE kt.tag = ?
      ORDER BY k.jlpt_level DESC, k.id ASC
    ''', [tag]);
    return rows.map(Kanji.fromMap).toList();
  }

  Future<Map<int, ({int learned, int total})>> getProgressByLevel() async {
    final rows = await dbService.query('''
      SELECT k.jlpt_level,
        SUM(CASE WHEN p.status='learned' THEN 1 ELSE 0 END) as learned,
        COUNT(*) as total
      FROM kanji k LEFT JOIN user_progress p ON k.id = p.kanji_id
      GROUP BY k.jlpt_level
    ''');
    return {
      for (final r in rows)
        r['jlpt_level'] as int: (
          learned: (r['learned'] as int? ?? 0),
          total: r['total'] as int? ?? 0,
        )
    };
  }

  Future<({int level, int learned, int total})?> getActiveLevel() async {
    final progress = await getProgressByLevel();
    for (final level in [5, 4, 3, 2, 1]) {
      final p = progress[level];
      if (p != null && p.learned < p.total) {
        return (level: level, learned: p.learned, total: p.total);
      }
    }
    return null;
  }

  Future<Kanji?> getById(int id) async {
    final rows = await dbService.query('SELECT * FROM kanji WHERE id = ?', [id]);
    return rows.isEmpty ? null : Kanji.fromMap(rows.first);
  }

  Future<Kanji?> getRandomLearned() async {
    final rows = await dbService.query('''
      SELECT k.* FROM kanji k JOIN user_progress p ON k.id = p.kanji_id
      WHERE p.status = 'learned' ORDER BY RANDOM() LIMIT 1
    ''');
    if (rows.isNotEmpty) return Kanji.fromMap(rows.first);
    final fallback = await dbService.query(
      'SELECT * FROM kanji WHERE jlpt_level = 5 ORDER BY id ASC LIMIT 1'
    );
    return fallback.isEmpty ? null : Kanji.fromMap(fallback.first);
  }

  Future<Kanji?> getRandomAny() async {
    final rows = await dbService.query(
      'SELECT * FROM kanji ORDER BY RANDOM() LIMIT 1'
    );
    return rows.isEmpty ? null : Kanji.fromMap(rows.first);
  }

  /// Returns a random target kanji, or null if none are set.
  Future<Kanji?> getRandomTarget() async {
    final rows = await dbService.query('''
      SELECT k.* FROM kanji k JOIN user_progress p ON k.id = p.kanji_id
      WHERE p.status = 'target' ORDER BY RANDOM() LIMIT 1
    ''');
    return rows.isEmpty ? null : Kanji.fromMap(rows.first);
  }

  /// Returns all kanji with their current status, grouped by jlpt_level.
  /// Map key = jlpt_level (int), value = list of (Kanji, status string) records.
  Future<Map<int, List<(Kanji, String)>>> getAllKanjiWithStatus() async {
    final rows = await dbService.query('''
      SELECT k.*, COALESCE(p.status, 'unlearned') AS status FROM kanji k
      LEFT JOIN user_progress p ON k.id = p.kanji_id
      ORDER BY k.jlpt_level DESC, k.id ASC
    ''');
    final result = <int, List<(Kanji, String)>>{};
    for (final row in rows) {
      final kanji = Kanji.fromMap(row);
      final status = row['status'] as String? ?? 'unlearned';
      result.putIfAbsent(kanji.jlptLevel, () => []).add((kanji, status));
    }
    return result;
  }

  /// Returns kanji with status for a specific tag, ordered by level desc.
  Future<List<(Kanji, String)>> getKanjiWithStatusForTag(String tag) async {
    final rows = await dbService.query('''
      SELECT k.*, COALESCE(p.status, 'unlearned') AS status FROM kanji k
      LEFT JOIN user_progress p ON k.id = p.kanji_id
      JOIN kanji_tags kt ON k.id = kt.kanji_id
      WHERE kt.tag = ?
      ORDER BY k.jlpt_level DESC, k.id ASC
    ''', [tag]);
    return rows.map((row) {
      final kanji = Kanji.fromMap(row);
      final status = row['status'] as String? ?? 'unlearned';
      return (kanji, status);
    }).toList();
  }

  /// Returns full Kanji objects for all target kanji.
  Future<List<Kanji>> getTargetKanjiList() async {
    final rows = await dbService.query('''
      SELECT k.* FROM kanji k JOIN user_progress p ON k.id = p.kanji_id
      WHERE p.status = 'target'
      ORDER BY k.jlpt_level DESC, k.id ASC
    ''');
    return rows.map(Kanji.fromMap).toList();
  }

  /// Bulk-set [ids] to 'target' only if currently 'unlearned'. Used by auto-progression.
  Future<void> bulkSetTarget(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await dbService.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.rawInsert('''
        INSERT INTO user_progress (kanji_id, status)
        VALUES (?, 'target')
        ON CONFLICT(kanji_id) DO UPDATE SET
          status = CASE WHEN status = 'unlearned' THEN 'target' ELSE status END
      ''', [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Returns all kanji characters at or below the given JLPT test level.
  /// testLevel: 5=N5 (easiest), 1=N1 (hardest). "At or below N4" = N4+N5 = jlpt_level >= 4.
  Future<Set<String>> getKanjiCharsAtOrBelowLevel(int testLevel) async {
    final rows = await dbService.query(
      'SELECT character FROM kanji WHERE jlpt_level >= ?',
      [testLevel],
    );
    return rows.map((r) => r['character'] as String).toSet();
  }

  Future<int> getHighPracticeTargetCount(int threshold) async {
    final rows = await dbService.query(
      "SELECT COUNT(*) as cnt FROM user_progress WHERE status='target' AND COALESCE(practice_correct_count,0) > ?",
      [threshold],
    );
    return rows.first['cnt'] as int? ?? 0;
  }
}

final kanjiRepo = KanjiRepository();
