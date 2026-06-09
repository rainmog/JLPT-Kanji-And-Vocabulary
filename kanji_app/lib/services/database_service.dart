import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  // Bump when shipping a new kanji.db asset (e.g. N1 sentences added).
  // Users will get the new content; user_progress is preserved across the rebuild.
  static const int _assetDbVersion = 2;
  static const String _prefDbVersion = 'db_asset_version';

  static Future<Database>? _initFuture;

  Future<Database> get database async {
    _initFuture ??= _init();
    return _initFuture!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'kanji.db');
    final prefs = await SharedPreferences.getInstance();

    bool needsRebuild = false;
    bool preserveProgress = false;

    if (!await File(path).exists()) {
      needsRebuild = true;
    } else {
      try {
        final db = await openDatabase(path);
        final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM kanji');
        final kanjiCount = (countResult.first['cnt'] as int?) ?? 0;
        final vocabResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM vocabulary');
        final vocabCount = (vocabResult.first['cnt'] as int?) ?? 0;
        await db.close();

        if (kanjiCount < 2230 || vocabCount == 0) {
          // Old stale DB — no meaningful progress to preserve
          needsRebuild = true;
        } else {
          final storedVersion = prefs.getInt(_prefDbVersion) ?? 1;
          if (storedVersion < _assetDbVersion) {
            needsRebuild = true;
            preserveProgress = true;
          }
        }
      } catch (_) {
        needsRebuild = true;
      }
    }

    if (needsRebuild) {
      List<Map<String, dynamic>> savedProgress = [];

      if (preserveProgress) {
        try {
          final db = await openDatabase(path);
          savedProgress = await db.query('user_progress');
          await db.close();
        } catch (_) {}
      }

      try { await File(path).delete(); } catch (_) {}
      final data = await rootBundle.load('assets/kanji.db');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);

      if (savedProgress.isNotEmpty) {
        final db = await openDatabase(path);
        final batch = db.batch();
        for (final row in savedProgress) {
          batch.insert('user_progress', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        await db.close();
      }
    }

    final db = await openDatabase(path);
    await _runMigrations(db);
    await prefs.setInt(_prefDbVersion, _assetDbVersion);
    return db;
  }

  Future<void> _runMigrations(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vocabulary_targets (
        vocab_id INTEGER PRIMARY KEY REFERENCES vocabulary(id),
        added_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vocabulary_progress (
        vocab_id INTEGER PRIMARY KEY REFERENCES vocabulary(id),
        word_to_meaning INTEGER NOT NULL DEFAULT 0,
        meaning_to_word INTEGER NOT NULL DEFAULT 0,
        learned_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS test_history (
        id        INTEGER PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        test_type TEXT    NOT NULL,
        level     INTEGER,
        section   TEXT,
        score     INTEGER NOT NULL,
        total     INTEGER NOT NULL,
        detail    TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_test_history_timestamp ON test_history(timestamp DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kana_progress (
        kana_id INTEGER PRIMARY KEY REFERENCES kana(id),
        status TEXT NOT NULL DEFAULT 'unlearned',
        consecutive_correct INTEGER NOT NULL DEFAULT 0,
        total_seen INTEGER NOT NULL DEFAULT 0,
        total_correct INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // practice_correct_count — guarded by try/catch (ALTER TABLE fails if column already exists)
    for (final migration in [
      'ALTER TABLE user_progress ADD COLUMN practice_correct_count INTEGER DEFAULT 0',
      'ALTER TABLE vocabulary_progress ADD COLUMN practice_correct_count INTEGER DEFAULT 0',
      'ALTER TABLE kana_progress ADD COLUMN practice_correct_count INTEGER DEFAULT 0',
    ]) {
      try {
        await db.execute(migration);
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, [List<dynamic>? args]
  ) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<int> execute(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return db.rawUpdate(sql, args ?? []);
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final dbService = DatabaseService();
