import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  // Bump when shipping a new kanji.db asset (e.g. new JLPT questions added).
  // Users get the new content; all user-state tables (below) are preserved
  // across the rebuild.
  // v9: N5 JLPT questions quadrupled (115→465).
  // v10: N4 JLPT questions quadrupled (132→529); N5 idx-41 fairness fix.
  static const int _assetDbVersion = 10;
  static const String _prefDbVersion = 'db_asset_version';

  // Every table that holds USER data (not shipped content). These are saved
  // before an asset rebuild and restored after, so a version bump never wipes
  // a user's progress, targets, or history. Content tables (kanji, vocabulary,
  // jlpt_questions, sentences, …) come fresh from the asset and are not listed.
  static const List<String> _userTables = [
    'user_progress',        // kanji
    'vocabulary_progress',
    'vocabulary_targets',
    'kana_progress',
    'session_log',
    'test_history',
  ];

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
      // Snapshot every user-state table before swapping in the new asset.
      final Map<String, List<Map<String, dynamic>>> saved = {};

      if (preserveProgress) {
        try {
          final db = await openDatabase(path);
          for (final table in _userTables) {
            try {
              saved[table] = await db.query(table);
            } catch (_) {
              // Table may not exist in an older DB — skip it.
            }
          }
          await db.close();
        } catch (_) {}
      }

      try { await File(path).delete(); } catch (_) {}
      final data = await rootBundle.load('assets/kanji.db');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);

      if (saved.isNotEmpty) {
        final db = await openDatabase(path);
        await _runMigrations(db); // ensure every user table + column exists first
        for (final entry in saved.entries) {
          if (entry.value.isEmpty) continue;
          try {
            final batch = db.batch();
            for (final row in entry.value) {
              batch.insert(entry.key, row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
          } catch (_) {
            // Never let one table's restore failure abort the rebuild.
          }
        }
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

    // guarded ALTER TABLEs — fail silently if column already exists
    for (final migration in [
      'ALTER TABLE user_progress ADD COLUMN practice_correct_count INTEGER DEFAULT 0',
      'ALTER TABLE vocabulary_progress ADD COLUMN practice_correct_count INTEGER DEFAULT 0',
      'ALTER TABLE kana_progress ADD COLUMN practice_correct_count INTEGER DEFAULT 0',
      'ALTER TABLE session_log ADD COLUMN question_count INTEGER DEFAULT 0',
      'ALTER TABLE user_progress ADD COLUMN practice_progress INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE vocabulary_progress ADD COLUMN practice_progress INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE kana_progress ADD COLUMN practice_progress INTEGER NOT NULL DEFAULT 0',
      // Spaced points-based learning (replaces the 0..4 practice_progress counter).
      // New columns default to 0 / NULL, so any in-progress item restarts at 0
      // points under the new system; already-learned items are untouched.
      'ALTER TABLE user_progress ADD COLUMN practice_points INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE user_progress ADD COLUMN practice_day TEXT',
      'ALTER TABLE user_progress ADD COLUMN practice_seen_today INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE user_progress ADD COLUMN practice_correct_today INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE vocabulary_progress ADD COLUMN practice_points INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE vocabulary_progress ADD COLUMN practice_day TEXT',
      'ALTER TABLE vocabulary_progress ADD COLUMN practice_seen_today INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE vocabulary_progress ADD COLUMN practice_correct_today INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE kana_progress ADD COLUMN practice_points INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE kana_progress ADD COLUMN practice_day TEXT',
      'ALTER TABLE kana_progress ADD COLUMN practice_seen_today INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE kana_progress ADD COLUMN practice_correct_today INTEGER NOT NULL DEFAULT 0',
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
