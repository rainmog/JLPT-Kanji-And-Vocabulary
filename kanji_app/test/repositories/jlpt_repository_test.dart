import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/repositories/jlpt_repository.dart';

void main() {
  group('JlptQuestion model', () {
    test('fromMap parses all fields', () {
      final map = {
        'id': 1,
        'level': 5,
        'section': 'vocabulary',
        'question_type': 'fill_blank',
        'passage_id': null,
        'passage': null,
        'passage_title': null,
        'question_stem': 'テストです',
        'option_1': 'A',
        'option_2': 'B',
        'option_3': 'C',
        'option_4': 'D',
        'correct_option': 2,
      };
      final q = JlptQuestion.fromMap(map);
      expect(q.id, 1);
      expect(q.section, 'vocabulary');
      expect(q.correctOption, 2);
      expect(q.options[1], 'B');
      expect(q.passageId, isNull);
    });

    test('options list has exactly 4 elements', () {
      final map = {
        'id': 1, 'level': 5, 'section': 'grammar',
        'question_type': 'fill_blank', 'passage_id': null,
        'passage': null, 'passage_title': null,
        'question_stem': 'Q', 'option_1': 'A', 'option_2': 'B',
        'option_3': 'C', 'option_4': 'D', 'correct_option': 1,
      };
      expect(JlptQuestion.fromMap(map).options.length, 4);
    });
  });
}
