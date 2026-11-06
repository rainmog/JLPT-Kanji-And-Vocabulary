import 'dart:math';

import '../services/database_service.dart';

/// One kanji's quiz-facing strings, used to draw wrong answers for other kanji.
typedef KanjiChoice = ({int id, int level, String readingLabel, String meaning});

/// "オン・くん" label for a kanji — first on reading, first kun stem (okurigana
/// stripped). Mirrors what the correct answer shows.
String kanjiReadingLabel(String? on, String? kun) {
  final onStr = (on ?? '').split('・')[0].trim();
  final kunStr = (kun ?? '').split('・')[0].split('.')[0].trim();
  if (onStr.isNotEmpty && kunStr.isNotEmpty) return '$onStr・$kunStr';
  if (onStr.isNotEmpty) return onStr;
  if (kunStr.isNotEmpty) return kunStr;
  return '';
}

String firstMeaning(String? meaning) => ((meaning ?? '').split(',')[0]).trim();

Set<String> _parts(String label) =>
    label.split('・').where((p) => p.isNotEmpty).toSet();

/// Wrong reading labels for a kanji whose correct label is [correct].
///
/// Drawn fresh from the whole kanji deck on every call (no shared cursor, no
/// fixed fallback list), so a 40-question session never runs out of options and
/// never has to resort to unrelated words. Any label sharing an on or kun part
/// with the correct one is excluded — otherwise two options could both look
/// right to someone who knows half the answer. Same-JLPT-level kanji are
/// preferred so the options look like they belong.
List<String> pickKanjiReadingDistractors({
  required String correct,
  required int level,
  required Iterable<KanjiChoice> pool,
  required Random rng,
  int count = 3,
}) {
  final avoid = _parts(correct);
  final seen = <String>{correct};
  final cands = <KanjiChoice>[];
  for (final k in pool) {
    final label = k.readingLabel;
    if (label.isEmpty || seen.contains(label)) continue;
    if (_parts(label).any(avoid.contains)) continue;
    seen.add(label);
    cands.add(k);
  }
  cands.shuffle(rng);
  cands.sort((a, b) =>
      (a.level == level ? 0 : 1).compareTo(b.level == level ? 0 : 1));
  return cands.take(count).map((k) => k.readingLabel).toList();
}

/// Wrong meanings for a kanji whose correct (first) meaning is [correct].
List<String> pickKanjiMeaningDistractors({
  required String correct,
  required int level,
  required Iterable<KanjiChoice> pool,
  required Random rng,
  int count = 3,
}) {
  final seen = <String>{correct.toLowerCase()};
  final cands = <KanjiChoice>[];
  for (final k in pool) {
    final m = k.meaning;
    if (m.isEmpty || !seen.add(m.toLowerCase())) continue;
    cands.add(k);
  }
  cands.shuffle(rng);
  cands.sort((a, b) =>
      (a.level == level ? 0 : 1).compareTo(b.level == level ? 0 : 1));
  return cands.take(count).map((k) => k.meaning).toList();
}

List<KanjiChoice>? _poolCache;

/// The whole kanji deck as [KanjiChoice]s. Loaded once per app run.
Future<List<KanjiChoice>> loadKanjiChoicePool(DatabaseService db) async {
  final cached = _poolCache;
  if (cached != null) return cached;
  final rows = await db
      .query('SELECT id, jlpt_level, on_reading, kun_reading, meaning FROM kanji');
  return _poolCache = [
    for (final r in rows)
      (
        id: r['id'] as int,
        level: (r['jlpt_level'] as int?) ?? 0,
        readingLabel: kanjiReadingLabel(
            r['on_reading'] as String?, r['kun_reading'] as String?),
        meaning: firstMeaning(r['meaning'] as String?),
      ),
  ];
}

/// Test seam: forget the cached pool.
void resetKanjiChoicePoolForTest() => _poolCache = null;
