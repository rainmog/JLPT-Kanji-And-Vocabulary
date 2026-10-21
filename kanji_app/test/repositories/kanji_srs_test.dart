import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kanji_app/repositories/progress_repository.dart';
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
}
