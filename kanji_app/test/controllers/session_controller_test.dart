import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/controllers/session_controller.dart';

SessionQuestion _q(int kanjiId, int sentenceId) => SessionQuestion(
  kanjiId: kanjiId, sentenceId: sentenceId,
  character: '食', onReading: 'ショク', kunReading: 'た.べる',
  meaning: 'eat', tokens: [], englishTranslation: '', validReadings: ['たべる'],
);

void main() {
  group('SessionController', () {
    test('starts with correct queue length', () {
      final ctrl = SessionController(
        questions: List.generate(60, (i) => _q(i ~/ 3, i)),
        mode: SessionMode.practice,
        threshold: 5,
      );
      expect(ctrl.remaining, 60);
    });

    test('correct increments streak', () {
      final ctrl = SessionController(
        questions: [_q(1, 1), _q(1, 2), _q(1, 3)],
        mode: SessionMode.practice,
        threshold: 5,
      );
      ctrl.recordAnswer(correct: true);
      expect(ctrl.streaks[1], 1);
    });

    test('incorrect resets streak', () {
      final ctrl = SessionController(
        questions: [_q(1, 1), _q(1, 2)],
        mode: SessionMode.practice,
        threshold: 5,
      );
      ctrl.recordAnswer(correct: true);
      ctrl.recordAnswer(correct: false);
      expect(ctrl.streaks[1], 0);
    });

    test('threshold reached marks learned', () {
      final ctrl = SessionController(
        questions: List.generate(5, (i) => _q(1, i)),
        mode: SessionMode.practice,
        threshold: 3,
      );
      ctrl.recordAnswer(correct: true);
      ctrl.recordAnswer(correct: true);
      expect(ctrl.learnedThisSession.contains(1), false);
      ctrl.recordAnswer(correct: true);
      expect(ctrl.learnedThisSession.contains(1), true);
    });
  });
}
