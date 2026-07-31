import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/utils/learning_constants.dart';

/// Simulates practicing one item across days, up to [perDay] correct answers
/// each day (capped by kPracticeDailyCap), and returns the day on which it
/// reaches kPracticePointsToLearn. Mirrors how recordPracticeProgress applies
/// applyPracticeAnswer with the day rolling over.
int daysToLearn({required int perDay, bool allCorrect = true}) {
  var points = 0;
  String? day;
  var seen = 0;
  var correct = 0;
  for (var d = 1; d <= 30; d++) {
    final today = '2026-01-${d.toString().padLeft(2, '0')}';
    // The pool selection enforces the cap, so the item is shown at most
    // kPracticeDailyCap times/day regardless of how many are requested.
    final attempts = perDay < kPracticeDailyCap ? perDay : kPracticeDailyCap;
    for (var i = 0; i < attempts; i++) {
      final r = applyPracticeAnswer(
        points: points,
        day: day,
        seenToday: seen,
        correctToday: correct,
        today: today,
        isCorrect: allCorrect,
      );
      points = r.points;
      seen = r.seenToday;
      correct = r.correctToday;
      day = today;
      if (points >= kPracticePointsToLearn) return d;
    }
  }
  return -1;
}

void main() {
  group('applyPracticeAnswer scoring', () {
    const today = '2026-01-01';

    test('first correct of the day awards the bonus', () {
      final r = applyPracticeAnswer(
        points: 0, day: null, seenToday: 0, correctToday: 0,
        today: today, isCorrect: true,
      );
      expect(r.points, kPracticeFirstCorrectPoints); // 5
      expect(r.firstCorrectOfDay, isTrue);
      expect(r.seenToday, 1);
      expect(r.correctToday, 1);
    });

    test('subsequent correct answers award the repeat value', () {
      final r = applyPracticeAnswer(
        points: 5, day: today, seenToday: 1, correctToday: 1,
        today: today, isCorrect: true,
      );
      expect(r.points, 5 + kPracticeRepeatCorrectPoints); // 6
      expect(r.firstCorrectOfDay, isFalse);
    });

    test('a new day resets the per-day counters and re-awards the bonus', () {
      final r = applyPracticeAnswer(
        points: 8, day: today, seenToday: 4, correctToday: 4,
        today: '2026-01-02', isCorrect: true,
      );
      expect(r.points, 8 + kPracticeFirstCorrectPoints); // 13
      expect(r.firstCorrectOfDay, isTrue);
      expect(r.seenToday, 1);
    });

    test('wrong answers subtract and floor at zero', () {
      final r = applyPracticeAnswer(
        points: 0, day: today, seenToday: 1, correctToday: 0,
        today: today, isCorrect: false,
      );
      expect(r.points, 0);
      expect(r.seenToday, 2); // wrong answer still burns a slot
    });

    test('points never exceed the learn threshold', () {
      final r = applyPracticeAnswer(
        points: kPracticePointsToLearn - 1, day: today, seenToday: 0, correctToday: 0,
        today: today, isCorrect: true,
      );
      expect(r.points, kPracticePointsToLearn);
    });
  });

  group('retention guarantee', () {
    test('all-correct at full daily cap takes a minimum of 3 days', () {
      expect(daysToLearn(perDay: kPracticeDailyCap), 3);
    });

    test('cannot be learned in a single day even if answered many times', () {
      // Even trying 10x/day, the cap limits points to 8/day → not learned day 1.
      expect(daysToLearn(perDay: 10) >= 3, isTrue);
    });
  });
}
