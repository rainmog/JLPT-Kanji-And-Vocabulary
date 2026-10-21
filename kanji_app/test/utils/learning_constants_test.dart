import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/utils/learning_constants.dart';

void main() {
  group('practiceDayKey', () {
    test('formats a given date as YYYY-MM-DD', () {
      expect(practiceDayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(practiceDayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('pads single-digit month and day', () {
      expect(practiceDayKey(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('defaults to the current local date when no argument is given', () {
      final now = DateTime.now();
      final expected = practiceDayKey(now);
      expect(practiceDayKey(), expected);
    });
  });
}
