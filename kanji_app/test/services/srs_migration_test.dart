import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kanji_app/services/database_service.dart';
import 'package:kanji_app/utils/learning_constants.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('backfill resets target items to box 1 and excludes learned', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE vocabulary_progress(
      vocab_id INTEGER PRIMARY KEY, learned_at INTEGER,
      srs_box INTEGER NOT NULL DEFAULT 0, srs_due TEXT, srs_last_review TEXT)''');
    await db.execute('CREATE TABLE vocabulary_targets(vocab_id INTEGER PRIMARY KEY, added_at INTEGER)');
    // In-rotation word (targeted, not learned)
    await db.insert('vocabulary_progress', {'vocab_id': 10});
    await db.insert('vocabulary_targets', {'vocab_id': 10, 'added_at': 0});
    // Stuck learned word (targeted AND learned — the bug)
    await db.insert('vocabulary_progress', {'vocab_id': 20, 'learned_at': 1});
    await db.insert('vocabulary_targets', {'vocab_id': 20, 'added_at': 0});
    // Never-practiced target (targeted, but no vocabulary_progress row yet)
    await db.insert('vocabulary_targets', {'vocab_id': 30, 'added_at': 0});

    await dbService.backfillVocabForTest(db, practiceDayKey());

    final rows = await db.query('vocabulary_progress', orderBy: 'vocab_id');
    expect(rows.firstWhere((r) => r['vocab_id'] == 10)['srs_box'], 1);
    expect(rows.firstWhere((r) => r['vocab_id'] == 10)['srs_due'], isNotNull);
    expect(rows.firstWhere((r) => r['vocab_id'] == 20)['srs_box'], 0); // learned excluded
    expect(rows.firstWhere((r) => r['vocab_id'] == 30)['srs_box'], 1); // never-practiced, backfilled
    expect(rows.firstWhere((r) => r['vocab_id'] == 30)['srs_due'], isNotNull);
    await db.close();
  });

  test('backfill resets kanji targets to box 1 with staggered due dates', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE user_progress(
      kanji_id INTEGER PRIMARY KEY, status TEXT NOT NULL DEFAULT 'unlearned',
      srs_box INTEGER NOT NULL DEFAULT 0, srs_due TEXT, srs_last_review TEXT)''');
    await db.insert('user_progress', {'kanji_id': 1, 'status': 'target'});
    await db.insert('user_progress', {'kanji_id': 2, 'status': 'learned'});

    await dbService.backfillKanjiForTest(db, practiceDayKey());

    final rows = await db.query('user_progress', orderBy: 'kanji_id');
    expect(rows.firstWhere((r) => r['kanji_id'] == 1)['srs_box'], 1);
    expect(rows.firstWhere((r) => r['kanji_id'] == 1)['srs_due'], isNotNull);
    expect(rows.firstWhere((r) => r['kanji_id'] == 2)['srs_box'], 0);
    await db.close();
  });

  test('backfill resets kana targets to box 1 with staggered due dates', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE kana_progress(
      kana_id INTEGER PRIMARY KEY, status TEXT NOT NULL DEFAULT 'unlearned',
      srs_box INTEGER NOT NULL DEFAULT 0, srs_due TEXT, srs_last_review TEXT)''');
    await db.insert('kana_progress', {'kana_id': 1, 'status': 'target'});
    await db.insert('kana_progress', {'kana_id': 2, 'status': 'learned'});

    await dbService.backfillKanaForTest(db, practiceDayKey());

    final rows = await db.query('kana_progress', orderBy: 'kana_id');
    expect(rows.firstWhere((r) => r['kana_id'] == 1)['srs_box'], 1);
    expect(rows.firstWhere((r) => r['kana_id'] == 1)['srs_due'], isNotNull);
    expect(rows.firstWhere((r) => r['kana_id'] == 2)['srs_box'], 0);
    await db.close();
  });
}
