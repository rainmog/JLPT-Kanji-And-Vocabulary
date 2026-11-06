import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/repositories/progress_repository.dart';
import 'package:kanji_app/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // The real schema comes from DatabaseService's migrations.
    await dbService.runMigrationsForTest(db);
    dbService.setTestDatabase(db);
  });
  tearDown(() async => db.close());

  test('every answer — right or wrong — counts toward today', () async {
    expect(await progressRepo.getTodayAnswerCount(), 0);
    await progressRepo.logAnswer(track: 'kanji', correct: true);
    await progressRepo.logAnswer(track: 'vocab', correct: false);
    await progressRepo.logAnswer(track: 'kana', correct: false);
    expect(await progressRepo.getTodayAnswerCount(), 3);
  });

  test('yesterday\'s answers do not count', () async {
    final yesterday =
        DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    await db.insert('answer_log',
        {'timestamp': yesterday, 'track': 'kanji', 'correct': 1});
    await progressRepo.logAnswer(track: 'kanji', correct: true);
    expect(await progressRepo.getTodayAnswerCount(), 1);
  });

  test('each logged answer notifies listeners (live goal ring)', () async {
    final before = progressRepo.answerTick.value;
    await progressRepo.logAnswer(track: 'kanji', correct: false);
    await progressRepo.logAnswer(track: 'kanji', correct: true);
    expect(progressRepo.answerTick.value, before + 2);
  });

  test('answer_log survives an asset-db rebuild (listed as a user table)', () {
    expect(DatabaseService.userTablesForTest, contains('answer_log'));
  });
}
