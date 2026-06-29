class SpeedReadQuestion {
  final String display;
  final String correct;
  final List<String> options; // 4 items, shuffled, includes correct
  final String? meaning;     // English meaning (vocab mode only; null for kana)

  const SpeedReadQuestion({
    required this.display,
    required this.correct,
    required this.options,
    this.meaning,
  });
}
