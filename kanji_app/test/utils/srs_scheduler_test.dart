import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/utils/srs_scheduler.dart';

void main() {
  group('applySrsReview', () {
    test('first-ever correct review moves box 0 -> 1, due +1 day', () {
      final r = applySrsReview(box: 0, lastReview: null, today: '2026-10-21', isCorrect: true);
      expect(r.box, 1);
      expect(r.due, '2026-10-22');
      expect(r.learned, false);
      expect(r.changed, true);
    });

    test('correct advances box and extends due by the new box interval', () {
      // box 3 -> 4, interval for box 4 is 9 days
      final r = applySrsReview(box: 3, lastReview: '2026-10-20', today: '2026-10-21', isCorrect: true);
      expect(r.box, 4);
      expect(r.due, '2026-10-30');
      expect(r.learned, false);
    });

    test('correct in top box graduates to learned', () {
      final r = applySrsReview(box: 5, lastReview: '2026-10-20', today: '2026-10-21', isCorrect: true);
      expect(r.learned, true);
      expect(r.changed, true);
    });

    test('wrong resets to box 1 due tomorrow, even from top box', () {
      final r = applySrsReview(box: 5, lastReview: '2026-10-20', today: '2026-10-21', isCorrect: false);
      expect(r.box, 1);
      expect(r.due, '2026-10-22');
      expect(r.learned, false);
    });

    test('second same-day answer is a no-op (box/due unchanged)', () {
      final r = applySrsReview(box: 3, lastReview: '2026-10-21', today: '2026-10-21', isCorrect: true);
      expect(r.changed, false);
      expect(r.box, 3);
      expect(r.due, isNull); // caller keeps existing due when changed == false
    });

    test('a new day after a same-day review counts again', () {
      final r = applySrsReview(box: 3, lastReview: '2026-10-21', today: '2026-10-22', isCorrect: true);
      expect(r.changed, true);
      expect(r.box, 4);
    });
  });
}
