import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/utils/vocab_answer_validator.dart';

void main() {
  group('VocabAnswerValidator.validate', () {
    test('exact match', () {
      expect(VocabAnswerValidator.validate('cat', ['cat']), true);
    });
    test('case insensitive', () {
      expect(VocabAnswerValidator.validate('Cat', ['cat']), true);
      expect(VocabAnswerValidator.validate('CAT', ['cat']), true);
    });
    test('trims whitespace', () {
      expect(VocabAnswerValidator.validate('  cat  ', ['cat']), true);
    });
    test('matches any acceptable answer', () {
      expect(VocabAnswerValidator.validate('hot', ['hot', 'thick']), true);
      expect(VocabAnswerValidator.validate('thick', ['hot', 'thick']), true);
    });
    test('wrong answer fails', () {
      expect(VocabAnswerValidator.validate('dog', ['cat']), false);
    });
    test('empty input fails', () {
      expect(VocabAnswerValidator.validate('', ['cat']), false);
    });
    test('empty answers list fails', () {
      expect(VocabAnswerValidator.validate('cat', []), false);
    });
  });
}
