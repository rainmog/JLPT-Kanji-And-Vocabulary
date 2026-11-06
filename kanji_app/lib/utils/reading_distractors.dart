import 'dart:math';

import '../services/database_service.dart';

/// A dictionary word paired with its hiragana reading — the raw material for
/// wrong answer options in reading questions.
typedef WordReading = ({String word, String reading});

bool _isHiragana(int c) => c >= 0x3041 && c <= 0x3096;
bool _isKanji(int c) => (c >= 0x4E00 && c <= 0x9FFF) || c == 0x3005;
bool _isKana(int c) =>
    (c >= 0x3041 && c <= 0x3096) || (c >= 0x30A1 && c <= 0x30FC);

String toHiragana(String s) => String.fromCharCodes(
    s.runes.map((c) => (c >= 0x30A1 && c <= 0x30F6) ? c - 0x60 : c));

bool _hasKanji(String s) => s.runes.any(_isKanji);

/// True for a katakana-only reading (loanwords: テレビ, コーヒー).
bool isAllKatakana(String s) =>
    s.isNotEmpty && s.runes.every((c) => (c >= 0x30A1 && c <= 0x30FC));

String toKatakana(String s) => String.fromCharCodes(
    s.runes.map((c) => (c >= 0x3041 && c <= 0x3096) ? c + 0x60 : c));

/// True when every character is kana (a usable reading, no stray punctuation
/// or latin letters).
bool isKanaReading(String s) => s.isNotEmpty && s.runes.every(_isKana);

/// The okurigana of [word]: the hiragana it ends in that is also the tail of
/// [reading] (喜び / よろこび → び, 難しい / むずかしい → しい). Empty when the
/// word ends in a kanji or katakana, or has no kanji at all.
String trailingKana(String word, String reading) {
  if (!_hasKanji(word)) return '';
  final w = word.runes.toList();
  final r = reading.runes.toList();
  var n = 0;
  while (n < w.length && n < r.length) {
    final c = w[w.length - 1 - n];
    if (!_isHiragana(c) || c != r[r.length - 1 - n]) break;
    n++;
  }
  return String.fromCharCodes(w.sublist(w.length - n));
}

/// Picks [count] wrong readings for [word] / [reading].
///
/// A word that ends in hiragana gives its answer away if the wrong options end
/// differently — the player can match the visible okurigana without knowing
/// the word. So every distractor shares the correct reading's trailing kana
/// (よろこび → たび, おび, おわび). Symmetrically, a word that ends in a kanji
/// gets distractors that don't end in okurigana, so the shape of an option
/// never narrows the answer either.
///
/// Draws a fresh random sample on every call; never reuses a shared pool
/// cursor, so long sessions can't run dry. Prefers distractors of a similar
/// length, and only if the pool has too few suffix matches does it build
/// look-alikes by swapping another word's ending for the right one.
List<String> pickReadingDistractors({
  required String word,
  required String reading,
  required Iterable<WordReading> pool,
  required Random rng,
  int count = 3,
}) {
  final correct = toHiragana(reading);
  final suffix = trailingKana(word, correct);

  final seen = <String>{correct};
  final candidates = <WordReading>[];
  for (final e in pool) {
    final r = toHiragana(e.reading);
    if (!isKanaReading(r) || !seen.add(r)) continue;
    candidates.add((word: e.word, reading: r));
  }
  candidates.shuffle(rng);
  // Similar-length options first (stable sort keeps the shuffle within a band).
  int band(WordReading e) => (e.reading.runes.length - correct.runes.length).abs() <= 2 ? 0 : 1;
  candidates.sort((a, b) => band(a).compareTo(band(b)));

  bool shapeMatches(WordReading e, String tail) {
    final own = trailingKana(e.word, e.reading);
    if (tail.isEmpty) return own.isEmpty && _hasKanji(e.word);
    return e.reading.endsWith(tail) && _hasKanji(e.word);
  }

  final out = <String>[];
  void fill(bool Function(WordReading) ok) {
    for (final e in candidates) {
      if (out.length >= count) return;
      if (!out.contains(e.reading) && ok(e)) out.add(e.reading);
    }
  }

  fill((e) => shapeMatches(e, suffix));

  if (out.length < count && suffix.isNotEmpty) {
    // Too few real words with this ending (inflected tails like …ている or
    // …わせた): graft the right ending onto other words' stems. Stems that
    // look like the right one — verbs/adjectives with a stem of similar length —
    // come first so the result reads like a plausible form.
    final correctStem = correct.runes.length - suffix.runes.length;
    final stems = <String>[];
    for (final e in candidates) {
      final own = trailingKana(e.word, e.reading);
      var stem = e.reading.substring(0, e.reading.length - own.length);
      if (stem.isEmpty) stem = e.reading.substring(0, max(1, e.reading.length - 1));
      stems.add(own.isEmpty ? '~$stem' : stem); // '~' marks "no okurigana": sorted last
    }
    stems.sort((a, b) {
      int rank(String s) =>
          (s.startsWith('~') ? 100 : 0) + (s.replaceAll('~', '').runes.length - correctStem).abs();
      return rank(a).compareTo(rank(b));
    });
    for (final raw in stems) {
      if (out.length >= count) break;
      final grafted = raw.replaceAll('~', '') + suffix;
      if (grafted != correct && !out.contains(grafted)) out.add(grafted);
    }
  }

  if (out.length < count) {
    // Last resort (tiny pool): anything not already used.
    fill((_) => true);
  }
  return out;
}

List<WordReading>? _poolCache;

/// Every kanji-bearing vocabulary word with its hiragana reading. Loaded once
/// per app run — a 7k-row read, shared by all question builders.
Future<List<WordReading>> loadWordReadingPool(DatabaseService db) async {
  final cached = _poolCache;
  if (cached != null) return cached;
  final rows = await db.query('SELECT word, reading FROM vocabulary');
  final pool = <WordReading>[];
  for (final r in rows) {
    final word = (r['word'] as String?) ?? '';
    final reading = toHiragana((r['reading'] as String?) ?? '');
    if (_hasKanji(word) && isKanaReading(reading)) {
      pool.add((word: word, reading: reading));
    }
  }
  return _poolCache = pool;
}

/// Test seam: forget the cached pool (tests swap in different databases).
void resetWordReadingPoolForTest() => _poolCache = null;
