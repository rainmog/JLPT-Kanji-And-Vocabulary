import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kanji_app/services/auto_progression_service.dart';
import 'package:kanji_app/services/database_service.dart';
import 'package:kanji_app/services/onboarding_service.dart';
import 'package:kanji_app/utils/learning_constants.dart';

/// Creates the kanji/vocabulary source tables plus the three progress tables
/// (with the Leitner srs_* columns) in a fresh in-memory db, routes dbService
/// at it, and resets the SharedPreferences mock store.
Future<Database> _freshDb() async {
  SharedPreferences.setMockInitialValues({});
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute(
      'CREATE TABLE kanji(id INTEGER PRIMARY KEY, character TEXT, jlpt_level INTEGER)');
  await db.execute(
      'CREATE TABLE vocabulary(id INTEGER PRIMARY KEY, jlpt_level INTEGER)');
  await db.execute('''CREATE TABLE user_progress(
    kanji_id INTEGER PRIMARY KEY, status TEXT NOT NULL DEFAULT 'unlearned',
    srs_box INTEGER NOT NULL DEFAULT 0, srs_due TEXT, srs_last_review TEXT)''');
  await db.execute('''CREATE TABLE vocabulary_progress(
    vocab_id INTEGER PRIMARY KEY, learned_at INTEGER,
    srs_box INTEGER NOT NULL DEFAULT 0, srs_due TEXT, srs_last_review TEXT)''');
  await db.execute(
      'CREATE TABLE vocabulary_targets(vocab_id INTEGER PRIMARY KEY, added_at INTEGER)');
  await db.execute('''CREATE TABLE kana_progress(
    kana_id INTEGER PRIMARY KEY, status TEXT NOT NULL DEFAULT 'unlearned',
    srs_box INTEGER NOT NULL DEFAULT 0, srs_due TEXT, srs_last_review TEXT)''');
  dbService.setTestDatabase(db);
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final svc = AutoProgressionService();

  test('introduceDaily kanji: up to quota as box1 due today, once per day', () async {
    final db = await _freshDb();
    for (var i = 1; i <= 50; i++) {
      await db.insert('kanji', {'id': i, 'character': 'x', 'jlpt_level': 5});
    }

    final r1 = await svc.introduceDaily(track: 'kanji', quota: 10, day: '2026-10-21');
    expect(r1, 10);
    final promoted1 = await db.query('user_progress',
        where: 'srs_box = 1', orderBy: 'kanji_id');
    expect(promoted1.length, 10);
    for (final r in promoted1) {
      expect(r['status'], 'target');
      expect(r['srs_due'], '2026-10-21');
      expect(r['srs_last_review'], isNull);
    }

    // Same day: cap already used.
    final r2 = await svc.introduceDaily(track: 'kanji', quota: 10, day: '2026-10-21');
    expect(r2, 0);

    // New day: quota available again.
    final r3 = await svc.introduceDaily(track: 'kanji', quota: 10, day: '2026-10-22');
    expect(r3, 10);
    final total = await db.query('user_progress', where: 'srs_box = 1');
    expect(total.length, 20);
    await db.close();
  });

  test('introduceDaily kanji: frequency-ordered, skips learned', () async {
    final db = await _freshDb();
    // ids 1..3 are N4 (less frequent), ids 4..13 are N5 (more frequent).
    for (var i = 1; i <= 3; i++) {
      await db.insert('kanji', {'id': i, 'character': 'x', 'jlpt_level': 4});
    }
    for (var i = 4; i <= 13; i++) {
      await db.insert('kanji', {'id': i, 'character': 'x', 'jlpt_level': 5});
    }
    // id 4 is already learned — must never be introduced.
    await db.insert('user_progress', {'kanji_id': 4, 'status': 'learned'});

    final n = await svc.introduceDaily(track: 'kanji', quota: 5, day: '2026-10-21');
    expect(n, 5);
    final promoted = await db.query('user_progress',
        where: 'srs_box = 1', orderBy: 'kanji_id');
    // N5 first (jlpt_level DESC), id ASC, skipping learned id 4 → 5,6,7,8,9.
    expect(promoted.map((r) => r['kanji_id']).toList(), [5, 6, 7, 8, 9]);
    // Learned stays box 0; N4 kanji untouched.
    final learned = await db.query('user_progress', where: 'kanji_id = 4');
    expect(learned.first['srs_box'], 0);
    await db.close();
  });

  test('introduceDaily vocab: box1 + inserts vocabulary_targets', () async {
    final db = await _freshDb();
    for (var i = 1; i <= 20; i++) {
      await db.insert('vocabulary', {'id': i, 'jlpt_level': 5});
    }
    // id 1 already learned — excluded.
    await db.insert('vocabulary_progress', {'vocab_id': 1, 'learned_at': 1});

    final n = await svc.introduceDaily(track: 'vocab', quota: 5, day: '2026-10-21');
    expect(n, 5);
    final promoted = await db.query('vocabulary_progress',
        where: 'srs_box = 1', orderBy: 'vocab_id');
    expect(promoted.map((r) => r['vocab_id']).toList(), [2, 3, 4, 5, 6]);
    for (final r in promoted) {
      expect(r['srs_due'], '2026-10-21');
      expect(r['srs_last_review'], isNull);
    }
    final targets = await db.query('vocabulary_targets', orderBy: 'vocab_id');
    expect(targets.map((r) => r['vocab_id']).toList(), [2, 3, 4, 5, 6]);
    await db.close();
  });

  test('onboarding finalizeSeeding promotes box0 targets, leaves box>=1 alone',
      () async {
    final db = await _freshDb();
    // Freshly-seeded, in-rotation but still box0 (the fresh-install case).
    await db.insert('user_progress', {'kanji_id': 100, 'status': 'target'});
    await db.insert('kana_progress', {'kana_id': 200, 'status': 'target'});
    await db.insert('vocabulary_targets', {'vocab_id': 300, 'added_at': 0});
    // Already in a higher box — must NOT be reset by the box0 guard.
    await db.insert('user_progress',
        {'kanji_id': 101, 'status': 'target', 'srs_box': 2, 'srs_due': '2000-01-01'});

    await OnboardingService.finalizeSeeding();

    final k = await db.query('user_progress', where: 'kanji_id = 100');
    expect(k.first['srs_box'], 1);
    expect(k.first['srs_due'], isNotNull);
    final kana = await db.query('kana_progress', where: 'kana_id = 200');
    expect(kana.first['srs_box'], 1);
    expect(kana.first['srs_due'], isNotNull);
    // vocabulary_progress row was created from the target and promoted.
    final v = await db.query('vocabulary_progress', where: 'vocab_id = 300');
    expect(v.length, 1);
    expect(v.first['srs_box'], 1);
    expect(v.first['srs_due'], isNotNull);
    // box2 row untouched.
    final high = await db.query('user_progress', where: 'kanji_id = 101');
    expect(high.first['srs_box'], 2);
    expect(high.first['srs_due'], '2000-01-01');
    await db.close();
  });
}
