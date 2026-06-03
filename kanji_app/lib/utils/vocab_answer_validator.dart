class VocabAnswerValidator {
  static bool validate(String input, List<String> acceptableAnswers) {
    final normalised = input.trim().toLowerCase();
    if (normalised.isEmpty) return false;
    if (acceptableAnswers.isEmpty) return false;
    return acceptableAnswers.any((a) => a.trim().toLowerCase() == normalised);
  }
}
