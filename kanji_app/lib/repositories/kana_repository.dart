import 'dart:convert';
import '../services/database_service.dart';

class KanaCharacter {
  final int id;
  final String character;
  final String type; // 'hiragana' | 'katakana'
  final String romaji;
  final List<String> acceptableRomaji;
  final String row;
  final String? counterpart;
  final String status; // 'unlearned' | 'target' | 'learned'

  const KanaCharacter({
    required this.id,
    required this.character,
    required this.type,
    required this.romaji,
    required this.acceptableRomaji,
    required this.row,
    required this.counterpart,
    required this.status,
  });

  factory KanaCharacter.fromRow(Map<String, dynamic> r) => KanaCharacter(
    id: r['id'] as int,
    character: r['character'] as String,
    type: r['type'] as String,
    romaji: r['romaji'] as String,
    acceptableRomaji: List<String>.from(jsonDecode(r['acceptable_romaji'] as String)),
    row: r['row'] as String,
    counterpart: r['counterpart'] as String?,
    status: r['status'] as String? ?? 'unlearned',
  );
}

class KanaWord {
  final int id;
  final String word;
  final String romaji;
  final List<String> acceptableRomaji;
  final String meaning;
  final String type;

  const KanaWord({
    required this.id,
    required this.word,
    required this.romaji,
    required this.acceptableRomaji,
    required this.meaning,
    required this.type,
  });

  factory KanaWord.fromRow(Map<String, dynamic> r) => KanaWord(
    id: r['id'] as int,
    word: r['word'] as String,
    romaji: r['romaji'] as String,
    acceptableRomaji: List<String>.from(jsonDecode(r['acceptable_romaji'] as String)),
    meaning: r['meaning'] as String,
    type: r['type'] as String,
  );
}

class KanaRepository {
  Future<List<KanaCharacter>> getAll({String? type}) async {
    final rows = await dbService.query(
      type != null
        ? '''SELECT k.*, COALESCE(p.status,'unlearned') AS status
             FROM kana k LEFT JOIN kana_progress p ON k.id=p.kana_id
             WHERE k.type=? ORDER BY k.id'''
        : '''SELECT k.*, COALESCE(p.status,'unlearned') AS status
             FROM kana k LEFT JOIN kana_progress p ON k.id=p.kana_id
             ORDER BY k.id''',
      type != null ? [type] : null,
    );
    return rows.map(KanaCharacter.fromRow).toList();
  }

  Future<List<String>> getRows({required String type}) async {
    final rows = await dbService.query(
      'SELECT DISTINCT row FROM kana WHERE type=? ORDER BY id',
      [type],
    );
    return rows.map((r) => r['row'] as String).toList();
  }

  Future<List<KanaCharacter>> getByRows(List<String> rows, {String? type}) async {
    if (rows.isEmpty) return [];
    final placeholders = rows.map((_) => '?').join(',');
    final args = [...rows];
    final typeClause = type != null ? 'AND k.type=?' : '';
    if (type != null) args.add(type);
    final result = await dbService.query(
      '''SELECT k.*, COALESCE(p.status,'unlearned') AS status
         FROM kana k LEFT JOIN kana_progress p ON k.id=p.kana_id
         WHERE k.row IN ($placeholders) $typeClause ORDER BY k.id''',
      args,
    );
    return result.map(KanaCharacter.fromRow).toList();
  }

  Future<List<KanaCharacter>> getTargeted({String? type}) async {
    final rows = await dbService.query(
      type != null
        ? '''SELECT k.*, p.status FROM kana k
             JOIN kana_progress p ON k.id=p.kana_id
             WHERE p.status IN ('target','learned') AND k.type=? ORDER BY k.id'''
        : '''SELECT k.*, p.status FROM kana k
             JOIN kana_progress p ON k.id=p.kana_id
             WHERE p.status IN ('target','learned') ORDER BY k.id''',
      type != null ? [type] : null,
    );
    return rows.map(KanaCharacter.fromRow).toList();
  }

  Future<({int learned, int targeted, int total})> getProgress({String? type}) async {
    final typeClause = type != null ? 'WHERE k.type=?' : '';
    final args = type != null ? [type] : null;
    final total = (await dbService.query(
      'SELECT COUNT(*) as cnt FROM kana k $typeClause', args,
    )).first['cnt'] as int;
    final learned = (await dbService.query(
      '''SELECT COUNT(*) as cnt FROM kana k
         JOIN kana_progress p ON k.id=p.kana_id
         WHERE p.status='learned' ${type != null ? "AND k.type='$type'" : ''}''',
    )).first['cnt'] as int;
    final targeted = (await dbService.query(
      '''SELECT COUNT(*) as cnt FROM kana k
         JOIN kana_progress p ON k.id=p.kana_id
         WHERE p.status='target' ${type != null ? "AND k.type='$type'" : ''}''',
    )).first['cnt'] as int;
    return (learned: learned, targeted: targeted, total: total);
  }

  Future<void> setStatus(int kanaId, String status) async {
    await dbService.execute(
      '''INSERT INTO kana_progress (kana_id, status) VALUES (?, ?)
         ON CONFLICT(kana_id) DO UPDATE SET status = excluded.status''',
      [kanaId, status],
    );
  }

  Future<void> setAllLearned({required String type}) async {
    final chars = await getAll(type: type);
    for (final ch in chars) {
      await setStatus(ch.id, 'learned');
    }
  }

  Future<List<KanaCharacter>> getNextUntargetedKana(int count) async {
    if (count <= 0) return [];
    final rows = await dbService.query('''
      SELECT k.*, COALESCE(p.status, 'unlearned') AS status
      FROM kana k
      LEFT JOIN kana_progress p ON k.id = p.kana_id
      WHERE COALESCE(p.status, 'unlearned') = 'unlearned'
      ORDER BY k.id ASC
      LIMIT ?
    ''', [count]);
    return rows.map(KanaCharacter.fromRow).toList();
  }

  Future<int> getTargetedCount() async {
    final rows = await dbService.query('''
      SELECT COUNT(*) as cnt FROM kana_progress WHERE status = 'target'
    ''');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<bool> allKanaLearned() async {
    final total = (await dbService.query('SELECT COUNT(*) as cnt FROM kana')).first['cnt'] as int;
    final learned = (await dbService.query(
      "SELECT COUNT(*) as cnt FROM kana_progress WHERE status='learned'"
    )).first['cnt'] as int;
    return learned >= total;
  }

  Future<void> setRowStatus(String row, String type, String status) async {
    final chars = await getByRows([row], type: type);
    for (final ch in chars) {
      await setStatus(ch.id, status);
    }
  }

  Future<void> recordResult(int kanaId, bool correct) async {
    await dbService.execute('''
      INSERT INTO kana_progress (kana_id, status, consecutive_correct, total_seen, total_correct)
      VALUES (?, 'unlearned', ?, 1, ?)
      ON CONFLICT(kana_id) DO UPDATE SET
        consecutive_correct = CASE WHEN ? THEN consecutive_correct+1 ELSE 0 END,
        total_seen = total_seen+1,
        total_correct = total_correct + CASE WHEN ? THEN 1 ELSE 0 END,
        status = CASE
          WHEN ? AND consecutive_correct+1 >= 3 THEN 'learned'
          WHEN status='learned' AND NOT ? THEN 'target'
          ELSE status
        END
    ''', [kanaId, correct ? 1 : 0, correct ? 1 : 0, correct, correct, correct, correct]);
  }

  // Words

  Future<List<KanaWord>> getWords({required String type}) async {
    final rows = await dbService.query(
      'SELECT * FROM kana_words WHERE type=? ORDER BY id', [type],
    );
    return rows.map(KanaWord.fromRow).toList();
  }

  Future<List<KanaWord>> getWordsForTargetedRows({
    required String type,
    required List<String> targetedRows,
    int minWords = 8,
  }) async {
    if (targetedRows.isEmpty) return [];
    final all = await getWords(type: type);

    // Get all targeted/learned kana characters
    final targeted = await getTargeted(type: type);
    final targetedChars = targeted.map((c) => c.character).toSet();

    // Prefer words where all kana are in targeted rows
    final strict = all.where((w) {
      return w.word.split('').every((c) => targetedChars.contains(c) || !_isKana(c));
    }).toList();

    if (strict.length >= minWords) return strict;

    // Fallback: at least one char from targeted rows
    return all.where((w) {
      return w.word.split('').any((c) => targetedChars.contains(c));
    }).toList();
  }

  bool _isKana(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x3041 && code <= 0x3096) || // hiragana
           (code >= 0x30A1 && code <= 0x30F6);    // katakana
  }
}

final kanaRepo = KanaRepository();
