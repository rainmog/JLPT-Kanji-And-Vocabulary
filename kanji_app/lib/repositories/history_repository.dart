import 'dart:convert';
import '../services/database_service.dart';

class TestHistoryEntry {
  final int id;
  final int timestamp;
  final String testType;
  final int? level;
  final String? section;
  final int score;
  final int total;
  final Map<String, dynamic>? detail;

  const TestHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.testType,
    this.level,
    this.section,
    required this.score,
    required this.total,
    this.detail,
  });

  factory TestHistoryEntry.fromMap(Map<String, dynamic> m) => TestHistoryEntry(
    id: m['id'] as int,
    timestamp: m['timestamp'] as int,
    testType: m['test_type'] as String,
    level: m['level'] as int?,
    section: m['section'] as String?,
    score: m['score'] as int,
    total: m['total'] as int,
    detail: m['detail'] != null ? jsonDecode(m['detail'] as String) as Map<String, dynamic> : null,
  );

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
  double get percentage => total == 0 ? 0 : score / total;

  String get label {
    if (testType == 'jlpt') {
      final lvl = level != null ? 'N$level' : '';
      final sec = section != null
          ? ' ${section![0].toUpperCase()}${section!.substring(1)}'
          : ' Full Test';
      return '$lvl$sec';
    }
    if (testType == 'target_kanji') return 'Kanji Test';
    if (testType == 'vocab') return 'Vocabulary Test';
    return testType;
  }
}

class HistoryRepository {
  Future<void> logResult({
    required String testType,
    int? level,
    String? section,
    required int score,
    required int total,
    Map<String, dynamic>? detail,
  }) async {
    await dbService.insert('test_history', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'test_type': testType,
      if (level != null) 'level': level,
      if (section != null) 'section': section,
      'score': score,
      'total': total,
      if (detail != null) 'detail': jsonEncode(detail),
    });
  }

  Future<List<TestHistoryEntry>> getHistory({
    String? testType,
    int? level,
    int limit = 200,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    if (testType != null) { conditions.add('test_type=?'); args.add(testType); }
    if (level != null) { conditions.add('level=?'); args.add(level); }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await dbService.query(
      'SELECT * FROM test_history $where ORDER BY timestamp DESC LIMIT $limit',
      args,
    );
    return rows.map(TestHistoryEntry.fromMap).toList();
  }
}

final historyRepo = HistoryRepository();
