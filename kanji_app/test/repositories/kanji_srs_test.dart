import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kanji_app/repositories/progress_repository.dart';
import 'package:kanji_app/repositories/sentence_repository.dart';
import 'package:kanji_app/services/database_service.dart';
import 'package:kanji_app/utils/learning_constants.dart';
import 'package:kanji_app/utils/srs_scheduler.dart';

/// Builds the minimal kanji + user_progress schema (incl. srs_* columns) that
/// [ProgressRepository.recordSrsReview] and the SRS due-selection SQL touch,
/// then injects the open db into the global [dbService] via its test seam.
Future<Database> _freshDb() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('DROP TABLE IF EXISTS user_progress');
  await db.execute('''
    CREATE TABLE user_progress(
      kanji_id INTEGER PRIMARY KEY,
      status TEXT NOT NULL DEFAULT 'unlearned',
      consecutive_correct INTEGER NOT NULL DEFAULT 0,
      total_seen INTEGER NOT NULL DEFAULT 0,
      total_correct INTEGER NOT NULL DEFAULT 0,
      practice_correct_count INTEGER NOT NULL DEFAULT 0,
      last_practiced_at INTEGER,
      srs_box INTEGER NOT NULL DEFAULT 0,
      srs_due TEXT,
      srs_last_review TEXT)''');
  dbService.setTestDatabase(db);
  return db;
}

/// Seeds one user_progress row at a given SRS box/due/status.
Future<void> _seed(
  Database db,
  int id, {
  required int box,
  String? due,
  String status = 'target',
  String? lastReview,
}) async {
  await db.insert('user_progress', {
    'kanji_id': id,
    'status': status,
    'srs_box': box,
    'srs_due': due,
    'srs_last_review': lastReview,
  });
}

/// The exact due-selection predicate used by pickKanjiForSession's targetOnly
/// (SRS) path: not-learned, box ≥ 1, due on or before [today].
Future<List<int>> _dueIds(Database db, String today) async {
  final rows = await db.rawQuery(
    "SELECT kanji_id FROM user_progress "
    "WHERE status != 'learned' AND srs_box >= 1 AND srs_due <= ? "
    "ORDER BY srs_due ASC, kanji_id ASC",
    [today],
  );
  return rows.map((r) => r['kanji_id'] as int).toList();
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

  test('correct review advances box and pushes the item out of today\'s due set',
      () async {
    await _seed(db, 1, box: 1, due: today);
    expect(await _dueIds(db, today), [1]);

    final r = await progressRepo.recordSrsReview(1, isCorrect: true);
    expect(r.box, 2);
    expect(r.learned, false);
    expect(r.graduated, false);

    // New due date is today+2 (box-2 interval), so it is no longer due today.
    final row = (await db.query('user_progress', where: 'kanji_id=1')).first;
    expect(row['srs_box'], 2);
    expect(row['srs_due'], srsDueAfter(2, today));
    expect(row['srs_last_review'], today);
    expect(await _dueIds(db, today), isEmpty);
  });

  test('wrong review from box 4 resets to box 1 (due again tomorrow)', () async {
    await _seed(db, 2, box: 4, due: today);
    final r = await progressRepo.recordSrsReview(2, isCorrect: false);
    expect(r.box, 1);
    expect(r.graduated, false);

    final row = (await db.query('user_progress', where: 'kanji_id=2')).first;
    expect(row['srs_box'], 1);
    expect(row['srs_due'], srsDueAfter(1, today));
  });

  test('wrong review from box 5 resets to box 1 and does NOT graduate',
      () async {
    await _seed(db, 5, box: 5, due: today);
    final r = await progressRepo.recordSrsReview(5, isCorrect: false);
    expect(r.box, 1);
    expect(r.learned, false);
    expect(r.graduated, false);

    final row = (await db.query('user_progress', where: 'kanji_id=5')).first;
    expect(row['status'], 'target'); // still in rotation
    expect(row['srs_box'], 1);
  });

  test('correct review in box 5 graduates and leaves the due set', () async {
    await _seed(db, 3, box: 5, due: today);
    final r = await progressRepo.recordSrsReview(3, isCorrect: true);
    expect(r.graduated, true);
    expect(r.learned, true);
    expect(r.box, kSrsBoxCount);

    final row = (await db.query('user_progress', where: 'kanji_id=3')).first;
    expect(row['status'], 'learned');
    expect(row['srs_box'], kSrsBoxCount);
    expect(row['srs_last_review'], today);
    // Learned items are excluded from the due set regardless of srs_due.
    expect(await _dueIds(db, today), isEmpty);
  });

  test('second same-day correct does not advance the box', () async {
    await _seed(db, 4, box: 1, due: today);
    final first = await progressRepo.recordSrsReview(4, isCorrect: true);
    expect(first.box, 2);

    final second = await progressRepo.recordSrsReview(4, isCorrect: true);
    expect(second.box, 2); // unchanged — same-day repeat is practice-only

    final row = (await db.query('user_progress', where: 'kanji_id=4')).first;
    expect(row['srs_box'], 2);
  });

  test('recordSrsReview creates a target row for an unknown kanji', () async {
    final r = await progressRepo.recordSrsReview(99, isCorrect: true);
    // Fresh row starts at box 0 → correct advances to box 1.
    expect(r.box, 1);
    expect(r.graduated, false);
    final row = (await db.query('user_progress', where: 'kanji_id=99')).first;
    expect(row['status'], 'target');
    expect(row['srs_box'], 1);
    expect(row['srs_due'], srsDueAfter(1, today));
  });

  test('due query is empty when nothing is due', () async {
    // box 0 (new, never introduced) and a box-2 item due in the future.
    await _seed(db, 10, box: 0, due: null);
    await _seed(db, 11, box: 2, due: srsDueAfter(2, today));
    expect(await _dueIds(db, today), isEmpty);
  });

  test('due query returns only the due item among due-today + due-future rows',
      () async {
    await _seed(db, 20, box: 1, due: today); // due today
    await _seed(db, 21, box: 2, due: srsDueAfter(2, today)); // due in future
    await _seed(db, 22, box: 0, due: null); // new, not introduced
    expect(await _dueIds(db, today), [20]);
  });

  group('pickKanjiForSession (practice)', () {
    final yesterday =
        practiceDayKey(DateTime.now().subtract(const Duration(days: 1)));

    // Adds the kanji + session_log tables pickKanjiForSession reads, and a
    // kanji row for each id.
    Future<void> withKanji(List<int> ids, {List<int> lastSession = const []}) async {
      await db.execute('''
        CREATE TABLE kanji(
          id INTEGER PRIMARY KEY, character TEXT NOT NULL, jlpt_level INTEGER NOT NULL,
          on_reading TEXT, kun_reading TEXT, meaning TEXT, stroke_count INTEGER)''');
      await db.execute(
          'CREATE TABLE session_log(mode TEXT, kanji_ids TEXT, timestamp INTEGER)');
      for (final id in ids) {
        await db.insert('kanji', {
          'id': id, 'character': 'k$id', 'jlpt_level': 3, 'meaning': 'm$id',
        });
      }
      if (lastSession.isNotEmpty) {
        await db.insert('session_log', {
          'mode': 'wordpractice', 'kanji_ids': lastSession.join(','), 'timestamp': 1,
        });
      }
    }

    Future<List<int>> pick(int count) async => (await SentenceRepository()
            .pickKanjiForSession(
                jlptLevels: const [3], tags: const [], count: count,
                targetOnly: true, reviewOnly: false))
        .map((k) => k.id)
        .toList();

    test('fills the session: due first, then not-yet-due soonest first', () async {
      await withKanji([1, 2, 3, 4, 5, 6, 7]);
      await _seed(db, 1, box: 1, due: yesterday); // overdue
      await _seed(db, 2, box: 2, due: today); // due
      await _seed(db, 3, box: 3, due: srsDueAfter(3, today)); // +4d
      await _seed(db, 4, box: 1, due: srsDueAfter(1, today)); // +1d
      await _seed(db, 5, box: 4, due: srsDueAfter(4, today)); // +9d
      await _seed(db, 6, box: 5, due: srsDueAfter(1, today), status: 'learned');
      await _seed(db, 7, box: 0); // unseen — introducer's job
      expect(await pick(4), [1, 2, 4, 3]);
    });

    test('does not pull not-yet-due kanji when due kanji fill the session', () async {
      await withKanji([1, 2, 3]);
      await _seed(db, 1, box: 1, due: yesterday);
      await _seed(db, 2, box: 1, due: today);
      await _seed(db, 3, box: 1, due: srsDueAfter(1, today));
      expect(await pick(2), [1, 2]);
    });

    test('a due kanji from the last session still beats a not-yet-due one', () async {
      await withKanji([1, 2], lastSession: [1]);
      await _seed(db, 1, box: 1, due: today);
      await _seed(db, 2, box: 1, due: srsDueAfter(1, today));
      expect(await pick(1), [1]);
      expect(await pick(2), [1, 2]);
    });

    test('never pulls learned or unseen kanji, even when short', () async {
      await withKanji([1, 2, 3]);
      await _seed(db, 1, box: 1, due: today);
      await _seed(db, 2, box: 5, due: today, status: 'learned');
      await _seed(db, 3, box: 0);
      expect(await pick(10), [1]);
    });
  });
}
