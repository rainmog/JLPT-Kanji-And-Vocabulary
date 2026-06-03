class SpeedReadQuestion {
  final String display;
  final String correct;
  final List<String> options; // 4 items, shuffled, includes correct

  const SpeedReadQuestion({
    required this.display,
    required this.correct,
    required this.options,
  });
}
