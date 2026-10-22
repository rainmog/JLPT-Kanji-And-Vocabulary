/// Sanity check for a compound word's reading taken from sentence data.
///
/// Every kanji contributes at least one kana to a word's reading, so a reading
/// shorter than the word's kanji count can't cover the whole word — it's a
/// fragment (e.g. 会議 stored as "ぎ", the reading of 議 alone). Such a reading
/// must never be used as a quiz answer.
bool isPlausibleWordReading(String surface, String reading) {
  if (reading.isEmpty) return false;
  final kanjiCount = surface.runes.where(_isKanji).length;
  return reading.runes.length >= kanjiCount;
}

bool _isKanji(int code) =>
    (code >= 0x4E00 && code <= 0x9FFF) || code == 0x3005; // 々
