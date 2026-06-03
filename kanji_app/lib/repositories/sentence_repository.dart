import 'dart:convert';
import '../services/database_service.dart';
import '../models/quiz_models.dart';
import 'kanji_repository.dart';

class SentenceToken {
  final String surface;
  final String reading;
  final bool isKanji;
  final String? kanjiChar;

  const SentenceToken({required this.surface, required this.reading,
    required this.isKanji, this.kanjiChar});

  factory SentenceToken.fromJson(Map<String, dynamic> j) => SentenceToken(
    surface: j['surface'] as String,
    reading: j['reading'] as String,
    isKanji: j['is_kanji'] as bool,
    kanjiChar: j['kanji_char'] as String?,
  );
}

class Sentence {
  final int id;
  final int kanjiId;
  final int difficulty;
  final String textKanji;
  final List<SentenceToken> tokens;
  final String englishTranslation;
  final List<String> validReadings;

  const Sentence({required this.id, required this.kanjiId, required this.difficulty,
    required this.textKanji, required this.tokens, required this.englishTranslation,
    required this.validReadings});

  factory Sentence.fromMap(Map<String, dynamic> m) {
    final rawTokens = jsonDecode(m['text_structured'] as String) as List;
    final rawReadings = jsonDecode(m['valid_readings'] as String) as List;
    return Sentence(
      id: m['id'] as int,
      kanjiId: m['kanji_id'] as int,
      difficulty: m['difficulty'] as int,
      textKanji: m['text_kanji'] as String,
      tokens: rawTokens.map((t) => SentenceToken.fromJson(t as Map<String, dynamic>)).toList(),
      englishTranslation: m['english_translation'] as String,
      validReadings: rawReadings.map((e) => e as String).toList(),
    );
  }
}

class SentenceRepository {
  final DatabaseService db;

  SentenceRepository({DatabaseService? dbService}) : db = dbService ?? _dbService;

  static const _fallbackMeanings = ['peace', 'safety', 'inexpensive', 'valuable'];
  static const _fallbackReadings = ['かいぎ', 'せいかつ', 'りょこう', 'しごと', 'べんきょう', 'でんわ', 'じかん', 'にほん'];

  static bool _hasKanji(String text) =>
      text.codeUnits.any((c) => c >= 0x4E00 && c <= 0x9FFF);

  Future<Map<String, String>> _fetchVocabMeanings(Set<String> words) async {
    if (words.isEmpty) return {};
    final placeholders = List.filled(words.length, '?').join(',');
    final rows = await db.query(
      'SELECT word, meanings FROM vocabulary WHERE word IN ($placeholders)',
      words.toList(),
    );
    return {for (final r in rows) r['word'] as String: r['meanings'] as String};
  }

  Future<String> _vocabMeaning(String word, Map<String, String> cache) async {
    if (cache.containsKey(word)) return cache[word]!;
    final rows = await db.query(
      'SELECT meanings FROM vocabulary WHERE word = ? LIMIT 1', [word]);
    final m = rows.isNotEmpty ? rows.first['meanings'] as String : '';
    cache[word] = m;
    return m;
  }

  static String _toHiragana(String s) => String.fromCharCodes(
      s.codeUnits.map((c) => (c >= 0x30A1 && c <= 0x30F6) ? c - 0x60 : c));

  static String _readingLabel(String? on, String? kun) {
    final onStr = (on ?? '').split('・')[0].trim();
    // strip okurigana suffix (e.g. "たべ.る" → "たべ")
    final kunStr = (kun ?? '').split('・')[0].split('.')[0].trim();
    if (onStr.isNotEmpty && kunStr.isNotEmpty) return '$onStr・$kunStr';
    if (onStr.isNotEmpty) return onStr;
    if (kunStr.isNotEmpty) return kunStr;
    return '';
  }

  /// Maps JLPT level (DB value) to max difficulty for test questions.
  /// N4=4→2, N3=3→3, N2=2→5, N1=1→7. Falls back to 3 for unknown levels.
  static int _testDiffCap(int jlptLevel) {
    switch (jlptLevel) {
      case 4: return 2;
      case 3: return 3;
      case 2: return 5;
      case 1: return 7;
      default: return 3;
    }
  }

  /// Builds 3 SentenceQuestions for each kanji in [targetKanji].
  /// Difficulty is capped per JLPT level; falls back to D9 if not enough found.
  /// Returns questions shuffled so same-kanji questions aren't consecutive.
  Future<List<SentenceQuestion>> buildTestQuestions({
    required List<Kanji> targetKanji,
  }) async {
    // Build wrong-reading pool from compound tokens
    final wrongRows = await db.query('''
      SELECT DISTINCT s.text_structured FROM sentences s
      JOIN kanji k ON k.id = s.kanji_id
      ORDER BY RANDOM() LIMIT 120
    ''');
    final wrongPool = <String>[];
    final seenWrong = <String>{};
    for (final row in wrongRows) {
      try {
        final tokens = jsonDecode(row['text_structured'] as String) as List;
        for (final t in tokens) {
          final token = t as Map<String, dynamic>;
          final surface = token['surface'] as String? ?? '';
          final reading = token['reading'] as String? ?? '';
          if (token['kanji_char'] != null && surface.length > 1 && reading.isNotEmpty) {
            final h = _toHiragana(reading);
            if (!seenWrong.contains(h)) { seenWrong.add(h); wrongPool.add(h); }
          }
        }
      } catch (_) {}
      if (wrongPool.length >= 60) break;
    }
    wrongPool.shuffle();

    final allQuestions = <SentenceQuestion>[];

    for (final kanji in targetKanji) {
      final cap = _testDiffCap(kanji.jlptLevel);

      // Try within cap first, fallback to D9
      var sentenceRows = await db.query('''
        SELECT s.* FROM sentences s
        WHERE s.kanji_id = ? AND s.difficulty <= ?
        ORDER BY RANDOM() LIMIT 3
      ''', [kanji.id, cap]);

      if (sentenceRows.length < 3) {
        sentenceRows = await db.query('''
          SELECT s.* FROM sentences s
          WHERE s.kanji_id = ?
          ORDER BY RANDOM() LIMIT 3
        ''', [kanji.id]);
      }

      int wrongIdx = 0;
      for (final row in sentenceRows) {
        try {
          final tokens = (jsonDecode(row['text_structured'] as String) as List)
              .map((t) => SentenceToken.fromJson(t as Map<String, dynamic>))
              .toList();
          final validReadings = (jsonDecode(row['valid_readings'] as String) as List)
              .map((e) => e as String)
              .toList();

          if (validReadings.isEmpty) continue;
          final correctReading = _toHiragana(validReadings[0]);

          // Build target tokens (highlight kanji character)
          final questionTokens = tokens.map((t) {
            final isTarget = t.isKanji && t.kanjiChar == kanji.character;
            return (
              surface: t.surface,
              reading: t.reading,
              isTarget: isTarget,
              hint: (!isTarget && _hasKanji(t.surface)) ? _toHiragana(t.reading) : null,
            );
          }).toList();

          // MC options: correct + 3 wrong compound readings
          final seenOpts = <String>{correctReading};
          final wrong = <String>[];
          while (wrong.length < 3 && wrongIdx < wrongPool.length) {
            final r = wrongPool[wrongIdx++];
            if (!seenOpts.contains(r)) { seenOpts.add(r); wrong.add(r); }
          }
          for (var fi = 0; wrong.length < 3; fi++) {
            final f = _fallbackReadings[fi % _fallbackReadings.length];
            if (!seenOpts.contains(f)) { wrong.add(f); seenOpts.add(f); }
          }
          final mcOptions = [correctReading, ...wrong]..shuffle();

          allQuestions.add(SentenceQuestion(
            kanjiId: kanji.id,
            character: kanji.character,
            meaning: kanji.meaning.split(',')[0],
            sentenceKanji: row['text_kanji'] as String,
            tokens: questionTokens,
            mcOptions: mcOptions,
            correctReading: correctReading,
            englishTranslation: row['english_translation'] as String? ?? '',
            difficulty: row['difficulty'] as int,
          ));
        } catch (_) {
          continue;
        }
      }
    }

    allQuestions.shuffle();
    return allQuestions;
  }

  /// Builds 2 WordQuestions (compound) + 1 KanjiQuestion (on/kun) per kanji.
  /// Returns shuffled so same-kanji questions aren't consecutive.
  Future<List<QuizQuestion>> buildMixedTestQuestions({
    required List<Kanji> targetKanji,
  }) async {
    if (targetKanji.isEmpty) return [];

    // Wrong pool for compound readings
    final wrongCompoundRows = await db.query('''
      SELECT DISTINCT s.text_structured FROM sentences s
      ORDER BY RANDOM() LIMIT 120
    ''');
    final compoundWrongPool = <String>[];
    final seenCompound = <String>{};
    for (final row in wrongCompoundRows) {
      try {
        final tokens = jsonDecode(row['text_structured'] as String) as List;
        for (final t in tokens) {
          final token = t as Map<String, dynamic>;
          final surface = token['surface'] as String? ?? '';
          final reading = token['reading'] as String? ?? '';
          if (token['kanji_char'] != null && surface.length > 1 && reading.isNotEmpty) {
            final h = _toHiragana(reading);
            if (!seenCompound.contains(h)) { seenCompound.add(h); compoundWrongPool.add(h); }
          }
        }
      } catch (_) {}
      if (compoundWrongPool.length >= 60) break;
    }
    compoundWrongPool.shuffle();

    final ids = targetKanji.map((k) => k.id).toList();
    final idPlaceholders = List.filled(ids.length, '?').join(',');

    // Wrong pools for on/kun reading and meaning
    final wrongReadingRows = await db.query(
      'SELECT DISTINCT on_reading, kun_reading FROM kanji WHERE id NOT IN ($idPlaceholders) ORDER BY RANDOM() LIMIT 60',
      ids,
    );
    final kanjiWrongLabels = wrongReadingRows
        .map((r) => _readingLabel(r['on_reading'] as String?, r['kun_reading'] as String?))
        .where((r) => r.isNotEmpty)
        .toList();

    final wrongMeanRows = await db.query(
      'SELECT DISTINCT meaning FROM kanji WHERE id NOT IN ($idPlaceholders) ORDER BY RANDOM() LIMIT 60',
      ids,
    );
    final kanjiWrongMeanings = wrongMeanRows
        .map((r) => ((r['meaning'] as String? ?? '').split(',')[0]).trim())
        .where((m) => m.isNotEmpty)
        .toList();

    final allQuestions = <QuizQuestion>[];
    int compoundWrongIdx = 0;
    int readingWrongIdx = 0;
    int meaningWrongIdx = 0;
    final vocabCache = <String, String>{};

    for (final kanji in targetKanji) {
      final cap = _testDiffCap(kanji.jlptLevel);

      // Fetch sentences (try capped, fallback uncapped)
      var sentenceRows = await db.query('''
        SELECT s.* FROM sentences s
        WHERE s.kanji_id = ? AND s.difficulty <= ?
        ORDER BY RANDOM() LIMIT 10
      ''', [kanji.id, cap]);
      if (sentenceRows.length < 4) {
        sentenceRows = await db.query('''
          SELECT s.* FROM sentences s WHERE s.kanji_id = ? ORDER BY RANDOM() LIMIT 10
        ''', [kanji.id]);
      }

      // 2 compound WordQuestions
      int compoundCount = 0;
      for (final row in sentenceRows) {
        if (compoundCount >= 2) break;
        try {
          final tokens = (jsonDecode(row['text_structured'] as String) as List)
              .map((t) => SentenceToken.fromJson(t as Map<String, dynamic>))
              .toList();
          String? word;
          String? correctReading;
          for (final t in tokens) {
            if (t.isKanji && t.kanjiChar == kanji.character && t.surface.length > 1) {
              word = t.surface;
              correctReading = _toHiragana(t.reading);
              break;
            }
          }
          if (word == null || correctReading == null) continue;

          final wm = await _vocabMeaning(word, vocabCache);
          final seen = <String>{correctReading};
          final wrong = <String>[];
          while (wrong.length < 3 && compoundWrongIdx < compoundWrongPool.length) {
            final r = compoundWrongPool[compoundWrongIdx++];
            if (!seen.contains(r)) { seen.add(r); wrong.add(r); }
          }
          for (var fi = 0; wrong.length < 3; fi++) {
            final f = _fallbackReadings[fi % _fallbackReadings.length];
            if (!seen.contains(f)) { wrong.add(f); seen.add(f); }
          }

          allQuestions.add(WordQuestion(
            kanjiId: kanji.id,
            character: kanji.character,
            meaning: kanji.meaning.split(',')[0],
            word: word,
            correctReading: correctReading,
            sentenceContext: row['text_kanji'] as String,
            mcOptions: [correctReading, ...wrong]..shuffle(),
            englishTranslation: row['english_translation'] as String? ?? '',
            wordMeaning: wm,
          ));
          compoundCount++;
        } catch (_) {
          continue;
        }
      }

      // 1 on/kun KanjiQuestion
      final correctLabel = _readingLabel(kanji.onReading, kanji.kunReading);
      final meaning = kanji.meaning.split(',')[0];

      final seenR = <String>{correctLabel};
      final wrongReadings = <String>[];
      while (wrongReadings.length < 3 && readingWrongIdx < kanjiWrongLabels.length) {
        final r = kanjiWrongLabels[readingWrongIdx++];
        if (!seenR.contains(r)) { seenR.add(r); wrongReadings.add(r); }
      }
      for (var fi = 0; wrongReadings.length < 3; fi++) {
        final f = _fallbackReadings[fi % _fallbackReadings.length];
        if (!seenR.contains(f)) { wrongReadings.add(f); seenR.add(f); }
      }

      final seenMeaning = <String>{meaning};
      final wrongMeanings = <String>[];
      while (wrongMeanings.length < 3 && meaningWrongIdx < kanjiWrongMeanings.length) {
        final m = kanjiWrongMeanings[meaningWrongIdx++];
        if (!seenMeaning.contains(m)) { seenMeaning.add(m); wrongMeanings.add(m); }
      }
      for (var fi = 0; wrongMeanings.length < 3; fi++) {
        final f = _fallbackMeanings[fi % _fallbackMeanings.length];
        if (!seenMeaning.contains(f)) { wrongMeanings.add(f); seenMeaning.add(f); }
      }

      allQuestions.add(KanjiQuestion(
        kanjiId: kanji.id,
        character: kanji.character,
        meaning: meaning,
        readingOptions: [correctLabel, ...wrongReadings]..shuffle(),
        meaningOptions: [meaning, ...wrongMeanings]..shuffle(),
        correctReading: correctLabel,
        correctMeaning: meaning,
      ));
    }

    allQuestions.shuffle();
    return allQuestions;
  }

  Future<List<Sentence>> getSentences({
    required int kanjiId,
    required int difficultyMin,
    required int difficultyMax,
    int limit = 3,
  }) async {
    final rows = await db.query('''
      SELECT * FROM sentences
      WHERE kanji_id = ? AND difficulty >= ? AND difficulty <= ?
      ORDER BY RANDOM()
      LIMIT ?
    ''', [kanjiId, difficultyMin, difficultyMax, limit]);
    return rows.map(Sentence.fromMap).toList();
  }

  /// Build Mode 1: Kanji questions (reading + meaning MC)
  Future<List<KanjiQuestion>> buildKanjiQuestions({
    required List<int> jlptLevels,
    required List<String> tags,
    required int count,
    bool targetOnly = false,
    bool reviewOnly = false,
  }) async {
    final levelPlaceholders = List.filled(jlptLevels.length, '?').join(',');
    final args = <dynamic>[...jlptLevels];
    String tagJoin = '';
    if (tags.isNotEmpty) {
      tagJoin = 'JOIN kanji_tags kt ON k.id = kt.kanji_id AND kt.tag IN (${List.filled(tags.length, '?').join(',')})';
      args.addAll(tags);
    }
    args.add(count);

    final rows = await db.query('''
      SELECT DISTINCT k.id, k.character, k.jlpt_level, k.on_reading, k.kun_reading, k.meaning
      FROM kanji k
      JOIN user_progress p ON k.id = p.kanji_id
      $tagJoin
      WHERE k.jlpt_level IN ($levelPlaceholders)
        ${targetOnly ? "AND p.status = 'target'" : reviewOnly ? "AND p.status = 'learned'" : "AND p.status != 'learned'"}
      ORDER BY RANDOM()
      LIMIT ?
    ''', args);

    // Fetch wrong-reading pool upfront (both on + kun)
    final wrongReadingRows = await db.query(
      'SELECT DISTINCT on_reading, kun_reading FROM kanji WHERE id NOT IN (${List.filled(rows.length, '?').join(',')}) AND jlpt_level IN ($levelPlaceholders) ORDER BY RANDOM() LIMIT 60',
      [...rows.map((r) => r['id'] as int), ...jlptLevels],
    );
    final allWrongLabels = wrongReadingRows
      .map((r) => _readingLabel(r['on_reading'] as String?, r['kun_reading'] as String?))
      .where((r) => r.isNotEmpty)
      .toList();

    final wrongMeaningRows = await db.query(
      'SELECT DISTINCT meaning FROM kanji WHERE id NOT IN (${List.filled(rows.length, '?').join(',')}) AND jlpt_level IN ($levelPlaceholders) ORDER BY RANDOM() LIMIT 60',
      [...rows.map((r) => r['id'] as int), ...jlptLevels],
    );
    final allWrongMeanings = wrongMeaningRows
        .map((r) => ((r['meaning'] as String? ?? '').split(',')[0]).trim())
        .where((m) => m.isNotEmpty)
        .toList();

    final questions = <KanjiQuestion>[];
    var wrongIdx = 0;
    var meaningIdx = 0;
    for (final row in rows) {
      final id = row['id'] as int;
      final char = row['character'] as String;
      final meaning = (row['meaning'] as String).split(',')[0];
      final correctLabel = _readingLabel(
        row['on_reading'] as String?, row['kun_reading'] as String?);

      // Gather 3 wrong readings — skip any that duplicate correctLabel
      final seen = <String>{correctLabel};
      final wrongReadings = <String>[];
      while (wrongReadings.length < 3 && wrongIdx < allWrongLabels.length) {
        final r = allWrongLabels[wrongIdx++];
        if (!seen.contains(r)) { seen.add(r); wrongReadings.add(r); }
      }
      // Fallback if pool exhausted
      for (var fi = 0; wrongReadings.length < 3; fi++) {
        final f = _fallbackReadings[fi % _fallbackReadings.length];
        if (!seen.contains(f)) { wrongReadings.add(f); seen.add(f); }
      }

      final readingOptions = [correctLabel, ...wrongReadings]..shuffle();

      final seenM = <String>{meaning};
      final wrongMeanings = <String>[];
      while (wrongMeanings.length < 3 && meaningIdx < allWrongMeanings.length) {
        final m = allWrongMeanings[meaningIdx++];
        if (!seenM.contains(m)) { seenM.add(m); wrongMeanings.add(m); }
      }
      for (var fi = 0; wrongMeanings.length < 3; fi++) {
        final f = _fallbackMeanings[fi % _fallbackMeanings.length];
        if (!seenM.contains(f)) { wrongMeanings.add(f); seenM.add(f); }
      }
      final meaningOptions = [meaning, ...wrongMeanings]..shuffle();

      questions.add(KanjiQuestion(
        kanjiId: id,
        character: char,
        meaning: meaning,
        readingOptions: readingOptions,
        meaningOptions: meaningOptions,
        correctReading: correctLabel,
        correctMeaning: meaning,
      ));
    }
    return questions;
  }

  /// Build Mode 2: Kanji compound questions
  Future<List<WordQuestion>> buildWordQuestions({
    required List<int> jlptLevels,
    required List<String> tags,
    required int count,
    required int minDifficulty,
    required int maxDifficulty,
    bool multipleChoice = false,
    bool targetOnly = false,
    bool reviewOnly = false,
  }) async {
    final levelPlaceholders = List.filled(jlptLevels.length, '?').join(',');
    final args = <dynamic>[...jlptLevels];
    String tagJoin = '';
    if (tags.isNotEmpty) {
      tagJoin = 'JOIN kanji_tags kt ON k.id = kt.kanji_id AND kt.tag IN (${List.filled(tags.length, '?').join(',')})';
      args.addAll(tags);
    }
    args.addAll([minDifficulty, maxDifficulty]);
    args.add(count * 3); // fetch extra to account for skipped standalone kanji

    final query = '''
      SELECT DISTINCT
        k.id, k.character, k.meaning,
        s.text_kanji, s.text_structured, s.valid_readings
      FROM kanji k
      JOIN sentences s ON k.id = s.kanji_id
      JOIN user_progress p ON k.id = p.kanji_id
      $tagJoin
      WHERE k.jlpt_level IN ($levelPlaceholders)
        AND s.difficulty BETWEEN ? AND ?
        ${targetOnly ? "AND p.status = 'target'" : reviewOnly ? "AND p.status = 'learned'" : "AND p.status != 'learned'"}
      ORDER BY RANDOM()
      LIMIT ?
    ''';

    final rows = await db.query(query, args);

    // Wrong-reading pool for MC — use other compound word readings, not on/kun labels
    List<String> wrongPool = [];
    if (multipleChoice) {
      final wrongRows = await db.query(
        '''SELECT DISTINCT s.text_structured
           FROM sentences s
           JOIN kanji k ON k.id = s.kanji_id
           WHERE k.jlpt_level IN ($levelPlaceholders)
           ORDER BY RANDOM() LIMIT 120''',
        jlptLevels,
      );
      final seen = <String>{};
      for (final row in wrongRows) {
        try {
          final tokens = jsonDecode(row['text_structured'] as String) as List;
          for (final t in tokens) {
            final token = t as Map<String, dynamic>;
            final surface = token['surface'] as String? ?? '';
            final reading = token['reading'] as String? ?? '';
            final kanjiChar = token['kanji_char'];
            if (kanjiChar != null && surface.length > 1 && reading.isNotEmpty) {
              final h = _toHiragana(reading);
              if (!seen.contains(h)) { seen.add(h); wrongPool.add(h); }
            }
          }
        } catch (_) {}
        if (wrongPool.length >= 60) break;
      }
      wrongPool.shuffle();
    }

    final questions = <WordQuestion>[];
    var wrongIdx = 0;
    final vocabCache = <String, String>{};

    for (final row in rows) {
      if (questions.length >= count) break;
      try {
        final id = row['id'] as int;
        final char = row['character'] as String;
        final meaning = (row['meaning'] as String).split(',')[0];
        final textStructured = jsonDecode(row['text_structured'] as String) as List;

        // Only accept compound tokens (length > 1) — skip standalone kanji
        String? word;
        String? correctReading;
        for (final t in textStructured) {
          final token = t as Map<String, dynamic>;
          if (token['kanji_char'] == char && (token['surface'] as String).length > 1) {
            word = token['surface'] as String;
            correctReading = _toHiragana(token['reading'] as String);
            break;
          }
        }

        if (word == null || correctReading == null) continue;
        final wm = await _vocabMeaning(word, vocabCache);

        List<String> mcOptions = [];
        if (multipleChoice) {
          final seen = <String>{correctReading};
          final wrong = <String>[];
          while (wrong.length < 3 && wrongIdx < wrongPool.length) {
            final r = wrongPool[wrongIdx++];
            if (!seen.contains(r)) { seen.add(r); wrong.add(r); }
          }
          for (var fi = 0; wrong.length < 3; fi++) {
            final f = _fallbackReadings[fi % _fallbackReadings.length];
            if (!seen.contains(f)) { wrong.add(f); seen.add(f); }
          }
          mcOptions = [correctReading, ...wrong]..shuffle();
        }

        questions.add(WordQuestion(
          kanjiId: id,
          character: char,
          meaning: meaning,
          word: word,
          correctReading: correctReading,
          sentenceContext: row['text_kanji'] as String,
          mcOptions: mcOptions,
          wordMeaning: wm,
        ));
      } on FormatException catch (e) {
        print('Error decoding word question JSON for row $row: $e');
        continue;
      }
    }

    return questions;
  }

  /// Build Mode 3: Sentence questions
  Future<List<SentenceQuestion>> buildSentenceQuestions({
    required List<int> jlptLevels,
    required List<String> tags,
    required int count,
    required int minDifficulty,
    required int maxDifficulty,
    required bool multipleChoice,
    bool targetOnly = false,
    bool reviewOnly = false,
  }) async {
    final levelPlaceholders = List.filled(jlptLevels.length, '?').join(',');
    final args = <dynamic>[...jlptLevels];
    String tagJoin = '';
    if (tags.isNotEmpty) {
      tagJoin = 'JOIN kanji_tags kt ON k.id = kt.kanji_id AND kt.tag IN (${List.filled(tags.length, '?').join(',')})';
      args.addAll(tags);
    }
    args.addAll([minDifficulty, maxDifficulty]);
    args.add(count);

    final query = '''
      SELECT DISTINCT
        k.id, k.character, k.meaning,
        s.text_kanji, s.text_structured, s.english_translation, s.valid_readings, s.difficulty
      FROM kanji k
      JOIN sentences s ON k.id = s.kanji_id
      JOIN user_progress p ON k.id = p.kanji_id
      $tagJoin
      WHERE k.jlpt_level IN ($levelPlaceholders)
        AND s.difficulty BETWEEN ? AND ?
        ${targetOnly ? "AND p.status = 'target'" : reviewOnly ? "AND p.status = 'learned'" : "AND p.status != 'learned'"}
      ORDER BY RANDOM()
      LIMIT ?
    ''';

    final rows = await db.query(query, args);
    final questions = <SentenceQuestion>[];

    for (final row in rows) {
      try {
        final id = row['id'] as int;
        final char = row['character'] as String;
        final meaning = (row['meaning'] as String).split(',')[0];
        final textStructured = jsonDecode(row['text_structured'] as String) as List;
        final validReadings = jsonDecode(row['valid_readings'] as String) as List;
        final translation = row['english_translation'] as String;
        final difficulty = row['difficulty'] as int;

        // Build token list with furigana hints for unlearned kanji
        final tokens = <QuestionToken>[];
        for (final t in textStructured) {
          final token = t as Map<String, dynamic>;
          final surface = token['surface'] as String;
          final reading = _toHiragana(token['reading'] as String);
          final isTarget = token['kanji_char'] == char;
          final hint = (!isTarget && _hasKanji(surface)) ? reading : null;

          tokens.add((surface: surface, reading: reading, isTarget: isTarget, hint: hint));
        }

        final correctReading = _toHiragana(validReadings[0] as String);
        var mcOptions = <String>[];
        if (multipleChoice) {
          mcOptions.addAll([correctReading, 'きれい', 'たのしい', 'さむい']);
          mcOptions.shuffle();
        }

        questions.add(SentenceQuestion(
          kanjiId: id,
          character: char,
          meaning: meaning,
          sentenceKanji: row['text_kanji'] as String,
          tokens: tokens,
          mcOptions: mcOptions,
          correctReading: correctReading,
          englishTranslation: translation,
          difficulty: difficulty,
        ));
      } on FormatException catch (e) {
        print('Error decoding sentence question JSON for row $row: $e');
        continue;
      }
    }

    return questions;
  }
}

final _dbService = dbService;
final sentenceRepo = SentenceRepository();
