enum MatchCardType {
  compoundKanji,
  reading,
  meaning,
  japanese,
  english,
  kana,
  romaji,
}

class MatchCard {
  final int groupId;
  final String displayText;
  final String? subText;
  final MatchCardType type;

  const MatchCard({
    required this.groupId,
    required this.displayText,
    this.subText,
    required this.type,
  });
}
