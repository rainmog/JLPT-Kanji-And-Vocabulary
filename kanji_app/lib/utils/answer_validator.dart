import 'romaji_converter.dart';

class AnswerValidator {
  static bool validate(String input, List<String> validReadings) {
    final normalised = _normalise(input);
    if (normalised.isEmpty) return false;
    return validReadings.any((r) => normalised == _normalise(r));
  }

  static String _normalise(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    // Pure romaji: adjust trailing 'n' → 'nn' so it converts to ん
    if (RegExp(r'^[a-z]+$').hasMatch(lower)) {
      final adjusted = (lower.endsWith('n') && !lower.endsWith('nn'))
          ? '${lower.substring(0, lower.length - 1)}nn'
          : lower;
      return RomajiConverter.convert(adjusted);
    }
    // Kana with trailing unconverted 'n' left by live formatter
    if (trimmed.endsWith('n') || trimmed.endsWith('N')) {
      return '${trimmed.substring(0, trimmed.length - 1)}ん';
    }
    return trimmed;
  }
}
