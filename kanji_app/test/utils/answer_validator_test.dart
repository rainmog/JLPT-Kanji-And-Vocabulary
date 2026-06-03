import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/utils/answer_validator.dart';

void main() {
  group('AnswerValidator.validate', () {
    test('exact hiragana match', () {
      expect(AnswerValidator.validate('たべる', ['たべる']), true);
    });
    test('romaji input matches', () {
      expect(AnswerValidator.validate('taberu', ['たべる']), true);
    });
    test('wrong answer', () {
      expect(AnswerValidator.validate('のむ', ['たべる']), false);
    });
    test('multiple valid readings', () {
      expect(AnswerValidator.validate('みる', ['みる', 'けんぶつする']), true);
    });
    test('trims whitespace', () {
      expect(AnswerValidator.validate('  たべる  ', ['たべる']), true);
    });
    test('empty input fails', () {
      expect(AnswerValidator.validate('', ['たべる']), false);
    });
  });
}
