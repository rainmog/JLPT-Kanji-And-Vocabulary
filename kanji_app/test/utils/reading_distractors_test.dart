import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/utils/kanji_distractors.dart';
import 'package:kanji_app/utils/reading_distractors.dart';


WordReading w(String word, String reading) => (word: word, reading: reading);

void main() {
  group('trailingKana', () {
    test('okurigana is the shared hiragana tail', () {
      expect(trailingKana('喜び', 'よろこび'), 'び');
      expect(trailingKana('難しい', 'むずかしい'), 'しい');
      expect(trailingKana('食べる', 'たべる'), 'べる');
    });
    test('kanji / katakana / all-kana endings have none', () {
      expect(trailingKana('会議', 'かいぎ'), '');
      expect(trailingKana('煙草', 'タバコ'), '');
      expect(trailingKana('きれい', 'きれい'), '');
    });
  });

  group('pickReadingDistractors', () {
    final pool = [
      w('旅', 'たび'), w('帯', 'おび'), w('お詫び', 'おわび'), w('学び', 'まなび'),
      w('悲しみ', 'かなしみ'), w('会議', 'かいぎ'), w('生活', 'せいかつ'),
      w('旅行', 'りょこう'), w('美しい', 'うつくしい'), w('食べる', 'たべる'),
      w('喜び', 'よろこび'), w('遊び', 'あそび'), w('忙しい', 'いそがしい'),
    ];

    test('every option of a hiragana-ending word ends in the same kana', () {
      for (var seed = 0; seed < 50; seed++) {
        final out = pickReadingDistractors(
            word: '喜び', reading: 'よろこび', pool: pool, rng: Random(seed));
        expect(out, hasLength(3));
        expect(out.toSet(), hasLength(3));
        expect(out, isNot(contains('よろこび')));
        for (final r in out) {
          expect(r.endsWith('び'), isTrue, reason: '$r should end in び');
        }
      }
    });

    test('multi-kana okurigana (…しい) is matched too', () {
      final p = [w('美しい', 'うつくしい'), w('忙しい', 'いそがしい'),
        w('楽しい', 'たのしい'), w('悲しい', 'かなしい'), w('会議', 'かいぎ')];
      final out = pickReadingDistractors(
          word: '難しい', reading: 'むずかしい', pool: p, rng: Random(1));
      expect(out.toSet(), {'うつくしい', 'いそがしい', 'たのしい'}.intersection(out.toSet()));
      expect(out.every((r) => r.endsWith('しい')), isTrue);
    });

    test('a kanji-ending word gets distractors without okurigana', () {
      for (var seed = 0; seed < 50; seed++) {
        final out = pickReadingDistractors(
            word: '会議', reading: 'かいぎ', pool: pool, rng: Random(seed));
        expect(out, hasLength(3));
        for (final r in out) {
          final word = pool.firstWhere((e) => e.reading == r).word;
          expect(trailingKana(word, r), '', reason: '$word should end in kanji');
        }
      }
    });

    test('too few suffix matches → grafts the ending onto other stems', () {
      final tiny = [w('旅', 'たび'), w('会議', 'かいぎ'), w('生活', 'せいかつ'),
        w('旅行', 'りょこう'), w('電話', 'でんわ')];
      final out = pickReadingDistractors(
          word: '喜び', reading: 'よろこび', pool: tiny, rng: Random(3));
      expect(out, hasLength(3));
      expect(out.toSet(), hasLength(3));
      expect(out.every((r) => r.endsWith('び') && r != 'よろこび'), isTrue);
    });

    test('never returns the correct reading, junk, or duplicates', () {
      final dirty = [w('喜び', 'よろこび'), w('旅', 'たび'), w('帯', 'おび'),
        w('帯', 'おび'), w('x び', 'ぶngaku'), w('学び', 'まなび'), w('遊び', 'あそび')];
      final out = pickReadingDistractors(
          word: '喜び', reading: 'よろこび', pool: dirty, rng: Random(2));
      expect(out.toSet(), hasLength(out.length));
      expect(out, isNot(contains('よろこび')));
      expect(out.every(isKanaReading), isTrue);
    });

    test('draws a fresh sample each call (no shared cursor to exhaust)', () {
      final rng = Random(7);
      for (var i = 0; i < 200; i++) {
        final out = pickReadingDistractors(
            word: '会議', reading: 'かいぎ', pool: pool, rng: rng);
        expect(out, hasLength(3), reason: 'call $i');
      }
    });
  });

  group('kanji distractors', () {
    final pool = <KanjiChoice>[
      for (var i = 0; i < 120; i++)
        (id: i, level: 1 + i % 5, readingLabel: 'オン$i・くん$i', meaning: 'meaning $i'),
      (id: 900, level: 1, readingLabel: 'カク・たし', meaning: 'certain'),
      (id: 901, level: 1, readingLabel: 'カク・おぼ', meaning: 'memorize'),
    ];

    test('120 questions in a row still get 3 real, distinct options', () {
      final rng = Random(5);
      for (var q = 0; q < 120; q++) {
        final correct = 'オン${q}x・くん${q}x';
        final r = pickKanjiReadingDistractors(
            correct: correct, level: 3, pool: pool, rng: rng);
        final m = pickKanjiMeaningDistractors(
            correct: 'right', level: 3, pool: pool, rng: rng);
        expect(r.toSet(), hasLength(3));
        expect(m.toSet(), hasLength(3));
        expect(r.every((x) => x.contains('・')), isTrue);
      }
    });

    test('options sharing the on or kun part of the answer are excluded', () {
      final out = pickKanjiReadingDistractors(
          correct: 'カク・たし', level: 1, pool: pool, rng: Random(1), count: 200);
      expect(out, isNot(contains('カク・おぼ')));
    });

    test('label formatting matches the correct answer', () {
      expect(kanjiReadingLabel('カク', 'たし.か・たし.かめる'), 'カク・たし');
      expect(kanjiReadingLabel('カク', ''), 'カク');
      expect(kanjiReadingLabel(null, 'ひと.つ'), 'ひと');
    });
  });
}
