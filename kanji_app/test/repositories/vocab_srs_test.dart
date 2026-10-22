import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kanji_app/repositories/vocab_repository.dart';
import 'package:kanji_app/services/database_service.dart';
import 'package:kanji_app/utils/learning_constants.dart';
import 'package:kanji_app/utils/srs_scheduler.dart';

/// Builds the minimal vocabulary + vocabulary_progress schema (incl. srs_*
/// columns) that [VocabRepository.recordSrsReview] and
/// [VocabRepository.getDuePracticeVocab] touch, then injects the open db into
/// the global [dbService] via its test seam.
Future<Database> _freshDb() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('DROP TABLE IF EXISTS vocabulary');
  await db.execute('DROP TABLE IF EXISTS vocabulary_progress');
  await db.execute('''
    CREATE TABLE vocabulary(
      id INTEGER PRIMARY KEY,
      word TEXT NOT NULL,
      reading TEXT NOT NULL,
      meanings TEXT,
      acceptable_answers TEXT,
      jlpt_level INTEGER NOT NULL,
      tags TEXT)''');
  await db.execute('''
    CREATE TABLE vocabulary_progress(
      vocab_id INTEGER PRIMARY KEY REFERENCES vocabulary(id),
      word_to_meaning INTEGER NOT NULL DEFAULT 0,
      meaning_to_word INTEGER NOT NULL DEFAULT 0,
      learned_at INTEGER,
      practice_correct_count INTEGER DEFAULT 0,
      srs_box INTEGER NOT NULL DEFAULT 0,
      srs_due TEXT,
      srs_last_review TEXT)''');
  dbService.setTestDatabase(db);
  return db;
}

/// Seeds a vocabulary row and its matching vocabulary_progress row.
Future<void> _seed(
  Database db,
  int id, {
  required int box,
  String? due,
  int? learnedAt,
  String? lastReview,
}) async {
  await db.insert('vocabulary', {
    'id': id,
    'word': 'word$id',
    'reading': 'word$id',
    'meanings': 'meaning$id',
    'jlpt_level': 5,
  });
  await db.insert('vocabulary_progress', {
    'vocab_id': id,
    'srs_box': box,
    'srs_due': due,
    'learned_at': learnedAt,
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

  group('getDuePracticeVocab', () {
    test('returns a box1 word due today', () async {
      await _seed(db, 1, box: 1, due: today);
      final words = await vocabRepo.getDuePracticeVocab(sessionLen: 10);
      expect(words.map((w) => w.id), contains(1));
    });

    test('excludes a learned word even if srs_due looks due', () async {
      await _seed(db, 1, box: 1, due: today);
      await _seed(db, 2, box: 5, due: today, learnedAt: DateTime.now().millisecondsSinceEpoch);
      final words = await vocabRepo.getDuePracticeVocab(sessionLen: 10);
      expect(words.map((w) => w.id), isNot(contains(2)));
    });

    test('does not pull a not-yet-due word when due words fill the session', () async {
      await _seed(db, 1, box: 1, due: today);
      await _seed(db, 3, box: 1, due: srsDueAfter(2, today)); // due later
      final words = await vocabRepo.getDuePracticeVocab(sessionLen: 1);
      expect(words.map((w) => w.id), [1]);
    });

    test('tops up with not-yet-due words, soonest first, after the due ones', () async {
      await _seed(db, 1, box: 1, due: today);
      await _seed(db, 2, box: 2, due: today);
      await _seed(db, 3, box: 3, due: srsDueAfter(3, today)); // +4 days
      await _seed(db, 4, box: 1, due: srsDueAfter(1, today)); // +1 day
      await _seed(db, 5, box: 4, due: srsDueAfter(4, today)); // +9 days
      final words = await vocabRepo.getDuePracticeVocab(sessionLen: 4);
      expect(words.map((w) => w.id), [1, 2, 4, 3]);
    });

    test('top-up never pulls learned or unseen words', () async {
      await _seed(db, 1, box: 1, due: today);
      await _seed(db, 2, box: 5, due: srsDueAfter(1, today),
          learnedAt: DateTime.now().millisecondsSinceEpoch);
      await _seed(db, 3, box: 0); // unseen — introducer's job, not the selector's
      final words = await vocabRepo.getDuePracticeVocab(sessionLen: 10);
      expect(words.map((w) => w.id), [1]);
    });

    test('returns each due word exactly once', () async {
      await _seed(db, 1, box: 1, due: today);
      final words = await vocabRepo.getDuePracticeVocab(sessionLen: 10);
      expect(words.where((w) => w.id == 1).length, 1);
    });
  });

  group('recordSrsReview', () {
    test('advances the box on a correct answer', () async {
      await _seed(db, 10, box: 1, due: today);
      final r = await vocabRepo.recordSrsReview(10, isCorrect: true);
      expect(r.box, 2);
      expect(r.learned, false);
      expect(r.graduated, false);
      final row = (await db.query('vocabulary_progress', where: 'vocab_id=10')).first;
      expect(row['srs_box'], 2);
      expect(row['srs_due'], srsDueAfter(2, today));
    });

    test('resets to box 1 on a wrong answer', () async {
      await _seed(db, 11, box: 4, due: today);
      final r = await vocabRepo.recordSrsReview(11, isCorrect: false);
      expect(r.box, 1);
      expect(r.graduated, false);
      final row = (await db.query('vocabulary_progress', where: 'vocab_id=11')).first;
      expect(row['srs_box'], 1);
      expect(row['srs_due'], srsDueAfter(1, today));
    });

    test('graduates at box 5 and marks learned_at', () async {
      await _seed(db, 12, box: 5, due: today);
      final r = await vocabRepo.recordSrsReview(12, isCorrect: true);
      expect(r.graduated, true);
      expect(r.learned, true);
      expect(r.box, kSrsBoxCount);
      final row = (await db.query('vocabulary_progress', where: 'vocab_id=12')).first;
      expect(row['learned_at'], isNotNull);
      expect(row['srs_box'], kSrsBoxCount);
    });

    test('second same-day correct answer does not advance the box', () async {
      await _seed(db, 13, box: 1, due: today);
      final first = await vocabRepo.recordSrsReview(13, isCorrect: true);
      expect(first.box, 2);
      final second = await vocabRepo.recordSrsReview(13, isCorrect: true);
      expect(second.box, 2); // unchanged — same-day repeat is practice-only
      final row = (await db.query('vocabulary_progress', where: 'vocab_id=13')).first;
      expect(row['srs_box'], 2);
    });
  });
}
