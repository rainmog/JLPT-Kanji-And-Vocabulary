import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kanji_app/repositories/kana_repository.dart';
import 'package:kanji_app/services/database_service.dart';
import 'package:kanji_app/utils/learning_constants.dart';
import 'package:kanji_app/utils/srs_scheduler.dart';

/// Builds the minimal kana + kana_progress schema (incl. srs_* columns) that
/// [KanaRepository.recordSrsReview] and [KanaRepository.getDuePracticeKana]
/// touch, then injects the open db into the global [dbService] via its test
/// seam.
Future<Database> _freshDb() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('DROP TABLE IF EXISTS kana');
  await db.execute('DROP TABLE IF EXISTS kana_progress');
  await db.execute('''
    CREATE TABLE kana(
      id INTEGER PRIMARY KEY,
      character TEXT NOT NULL,
      type TEXT NOT NULL,
      romaji TEXT NOT NULL,
      acceptable_romaji TEXT NOT NULL,
      row TEXT NOT NULL,
      counterpart TEXT)''');
  await db.execute('''
    CREATE TABLE kana_progress(
      kana_id INTEGER PRIMARY KEY REFERENCES kana(id),
      status TEXT NOT NULL DEFAULT 'unlearned',
      srs_box INTEGER NOT NULL DEFAULT 0,
      srs_due TEXT,
      srs_last_review TEXT)''');
  dbService.setTestDatabase(db);
  return db;
}

/// Seeds a kana row and its matching kana_progress row.
Future<void> _seed(
  Database db,
  int id, {
  required String type,
  required int box,
  String? due,
  String status = 'target',
  String? lastReview,
}) async {
  await db.insert('kana', {
    'id': id,
    'character': 'k$id',
    'type': type,
    'romaji': 'r$id',
    'acceptable_romaji': '["r$id"]',
    'row': 'row$id',
  });
  await db.insert('kana_progress', {
    'kana_id': id,
    'status': status,
    'srs_box': box,
    'srs_due': due,
    'srs_last_review': lastReview,
  });
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  final today = practiceDayKey();

  setUp(() async {
    db = await _freshDb();
  });
  tearDown(() async {
    await db.close();
  });

  group('getDuePracticeKana', () {
    test('returns a box1 hiragana char due today', () async {
      await _seed(db, 1, type: 'hiragana', box: 1, due: today);
      final list = await kanaRepo.getDuePracticeKana(sessionLen: 10, type: 'hiragana');
      expect(list.map((c) => c.id), contains(1));
    });

    test('excludes a learned char even if srs_due looks due', () async {
      await _seed(db, 1, type: 'hiragana', box: 1, due: today);
      await _seed(db, 2, type: 'hiragana', box: 5, due: today, status: 'learned');
      final list = await kanaRepo.getDuePracticeKana(sessionLen: 10, type: 'hiragana');
      expect(list.map((c) => c.id), isNot(contains(2)));
    });

    test('does not pull a not-yet-due char when due chars fill the session', () async {
      await _seed(db, 1, type: 'hiragana', box: 1, due: today);
      await _seed(db, 3, type: 'hiragana', box: 1, due: srsDueAfter(2, today));
      final list = await kanaRepo.getDuePracticeKana(sessionLen: 1, type: 'hiragana');
      expect(list.map((c) => c.id), [1]);
    });

    test('tops up with not-yet-due chars of the same type, soonest first', () async {
      await _seed(db, 1, type: 'hiragana', box: 1, due: today);
      await _seed(db, 2, type: 'hiragana', box: 3, due: srsDueAfter(3, today)); // +4d
      await _seed(db, 3, type: 'hiragana', box: 1, due: srsDueAfter(1, today)); // +1d
      await _seed(db, 4, type: 'katakana', box: 1, due: srsDueAfter(1, today)); // other type
      await _seed(db, 5, type: 'hiragana', box: 5, due: srsDueAfter(1, today), status: 'learned');
      final list = await kanaRepo.getDuePracticeKana(sessionLen: 10, type: 'hiragana');
      expect(list.map((c) => c.id), [1, 3, 2]);
    });

    test('respects the type filter', () async {
      await _seed(db, 1, type: 'hiragana', box: 1, due: today);
      await _seed(db, 4, type: 'katakana', box: 1, due: today);
      final list = await kanaRepo.getDuePracticeKana(sessionLen: 10, type: 'hiragana');
      expect(list.map((c) => c.id), contains(1));
      expect(list.map((c) => c.id), isNot(contains(4)));
    });
  });

  group('recordSrsReview', () {
    test('advances the box on a correct answer', () async {
      await _seed(db, 10, type: 'hiragana', box: 1, due: today);
      final r = await kanaRepo.recordSrsReview(10, isCorrect: true);
      expect(r.box, 2);
      expect(r.learned, false);
      expect(r.graduated, false);
      final row = (await db.query('kana_progress', where: 'kana_id=10')).first;
      expect(row['srs_box'], 2);
      expect(row['srs_due'], srsDueAfter(2, today));
    });

    test('resets to box 1 on a wrong answer', () async {
      await _seed(db, 11, type: 'hiragana', box: 4, due: today);
      final r = await kanaRepo.recordSrsReview(11, isCorrect: false);
      expect(r.box, 1);
      expect(r.graduated, false);
      final row = (await db.query('kana_progress', where: 'kana_id=11')).first;
      expect(row['srs_box'], 1);
      expect(row['srs_due'], srsDueAfter(1, today));
    });

    test('graduates at box 5 and marks learned', () async {
      await _seed(db, 12, type: 'hiragana', box: 5, due: today);
      final r = await kanaRepo.recordSrsReview(12, isCorrect: true);
      expect(r.graduated, true);
      expect(r.learned, true);
      expect(r.box, kSrsBoxCount);
      final row = (await db.query('kana_progress', where: 'kana_id=12')).first;
      expect(row['status'], 'learned');
      expect(row['srs_box'], kSrsBoxCount);
    });

    test('second same-day correct answer does not advance the box', () async {
      await _seed(db, 13, type: 'hiragana', box: 1, due: today);
      final first = await kanaRepo.recordSrsReview(13, isCorrect: true);
      expect(first.box, 2);
      final second = await kanaRepo.recordSrsReview(13, isCorrect: true);
      expect(second.box, 2); // unchanged — same-day repeat is practice-only
      final row = (await db.query('kana_progress', where: 'kana_id=13')).first;
      expect(row['srs_box'], 2);
    });
  });
}
