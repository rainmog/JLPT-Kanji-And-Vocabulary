import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/repositories/kanji_repository.dart';
import 'package:kanji_app/repositories/sentence_repository.dart';
import 'package:kanji_app/repositories/vocab_repository.dart';
import 'package:kanji_app/models/quiz_models.dart';
import 'package:kanji_app/services/database_service.dart';
import 'package:kanji_app/utils/kanji_distractors.dart';
import 'package:kanji_app/utils/reading_distractors.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs the real question builders against the shipped asset database, so the
/// distractor rules are checked on real data (the bugs they cover — option
/// pools running dry, fallback words, okurigana giveaways — only show up at
/// real-deck scale).
void main() {
  sqfliteFfiInit();
  late List<Kanji> allKanji;
  late SentenceRepository repo;

  setUpAll(() async {
    // Open a scratch copy so the asset is never touched.
    final tmp = await Directory.systemTemp.createTemp('kanji_asset_test');
    final copy = File('${tmp.path}/kanji.db');
    await File('assets/kanji.db').copy(copy.path);
    final db = await databaseFactoryFfi.openDatabase(copy.path);
    dbService.setTestDatabase(db);
    resetWordReadingPoolForTest();
    resetKanjiChoicePoolForTest();
    final rows = await db.rawQuery('SELECT * FROM kanji');
    allKanji = rows.map(Kanji.fromMap).toList();
    repo = SentenceRepository(dbService: dbService);
  });

  test('40-kanji test: every kanji question has 4 distinct real on/kun options and meanings', () async {
    final picks = ([...allKanji]..shuffle(Random(11))).take(40).toList();
    final qs = await repo.buildMixedTestQuestions(targetKanji: picks);
    final kanjiQs = qs.whereType<KanjiQuestion>().toList();
    expect(kanjiQs, hasLength(40));
    const oldFallbackWords = {'かいぎ', 'せいかつ', 'りょこう', 'しごと', 'べんきょう', 'でんわ', 'じかん', 'にほん'};
    const oldFallbackMeanings = {'peace', 'safety', 'inexpensive', 'valuable'};
    for (final q in kanjiQs) {
      expect(q.readingOptions.toSet(), hasLength(4), reason: q.character);
      expect(q.meaningOptions.toSet(), hasLength(4), reason: q.character);
      expect(q.readingOptions.where(oldFallbackWords.contains), isEmpty, reason: q.character);
      if (!oldFallbackMeanings.contains(q.correctMeaning)) {
        expect(q.meaningOptions.where(oldFallbackMeanings.contains).length <= 1 + 0, isTrue,
            reason: '${q.character} ${q.meaningOptions}');
      }
    }
  });

  test('word questions: options share the answer\'s okurigana', () async {
    final picks = ([...allKanji]..shuffle(Random(12))).take(150).toList();
    final qs = await repo.buildMixedTestQuestions(targetKanji: picks);
    final words = qs.whereType<WordQuestion>().toList();
    expect(words.length, greaterThan(100));
    var withOkurigana = 0;
    for (final q in words) {
      expect(q.mcOptions.toSet(), hasLength(4), reason: q.word);
      final suffix = trailingKana(q.word, q.correctReading);
      if (suffix.isNotEmpty) {
        withOkurigana++;
        for (final o in q.mcOptions) {
          expect(o.endsWith(suffix), isTrue,
              reason: '${q.word} → ${q.correctReading}; option $o should end in $suffix');
        }
      }
    }
    expect(withOkurigana, greaterThan(5), reason: 'sample should include okurigana words');
  });

  test('sentence test mc options follow the same rule', () async {
    final picks = ([...allKanji]..shuffle(Random(13))).take(60).toList();
    final qs = await repo.buildTestQuestions(targetKanji: picks);
    expect(qs, isNotEmpty);
    for (final q in qs) {
      expect(q.mcOptions.toSet(), hasLength(4), reason: q.sentenceKanji);
      final word = q.targetWord;
      if (word == null) continue;
      final suffix = trailingKana(word, q.correctReading);
      if (suffix.isEmpty) continue;
      for (final o in q.mcOptions) {
        expect(o.endsWith(suffix), isTrue,
            reason: '$word → ${q.correctReading}; option $o should end in $suffix');
      }
    }
  });

  test('vocab reading options: same ending as the word, katakana words stay katakana', () async {
    final rows = await dbService.query('SELECT * FROM vocabulary ORDER BY RANDOM() LIMIT 400');
    final words = rows.map(VocabWord.fromMap).toList();
    var okurigana = 0, katakana = 0;
    for (final v in words) {
      final wrong = await vocabRepo.getReadingDistractors(v);
      expect(wrong.toSet(), hasLength(3), reason: v.word);
      expect(wrong, isNot(contains(v.reading)), reason: v.word);
      final suffix = trailingKana(v.word, toHiragana(v.reading));
      if (suffix.isNotEmpty) {
        okurigana++;
        for (final o in wrong) {
          expect(o.endsWith(suffix), isTrue, reason: '${v.word}: $o should end in $suffix');
        }
      }
      if (isAllKatakana(v.reading)) {
        katakana++;
        expect(wrong.every(isAllKatakana), isTrue, reason: '${v.word}: $wrong');
      }
    }
    expect(okurigana, greaterThan(20));
    expect(katakana, greaterThan(5));
  });
}
