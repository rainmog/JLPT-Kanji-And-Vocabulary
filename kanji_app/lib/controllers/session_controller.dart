import '../repositories/sentence_repository.dart';

enum SessionMode { practice, review }
enum FilterMode { practice, review }

class SessionQuestion {
  final int kanjiId;
  final int sentenceId;
  final String character;
  final String onReading;
  final String kunReading;
  final String meaning;
  final List<SentenceToken> tokens;
  final String englishTranslation;
  final List<String> validReadings;

  const SessionQuestion({
    required this.kanjiId, required this.sentenceId, required this.character,
    required this.onReading, required this.kunReading, required this.meaning,
    required this.tokens, required this.englishTranslation, required this.validReadings,
  });
}

class SessionController {
  final SessionMode mode;
  final int threshold;
  final List<SessionQuestion> _queue;
  final Map<int, int> streaks = {};
  final Set<int> learnedThisSession = {};
  final Set<int> forgottenThisSession = {};
  int _answered = 0;
  int _correct = 0;

  SessionController({
    required List<SessionQuestion> questions,
    required this.mode,
    required this.threshold,
  }) : _queue = List.from(questions)..shuffle();

  int get remaining => _queue.length;
  int get answered => _answered;
  int get correct => _correct;
  SessionQuestion? get current => _queue.isEmpty ? null : _queue.first;

  int? recordAnswer({required bool correct}) {
    if (_queue.isEmpty) return null;
    final q = _queue.removeAt(0);
    _answered++;
    if (correct) {
      _correct++;
      streaks[q.kanjiId] = (streaks[q.kanjiId] ?? 0) + 1;
      if (mode == SessionMode.practice && streaks[q.kanjiId]! >= threshold) {
        _removeKanjiFromQueue(q.kanjiId);
        learnedThisSession.add(q.kanjiId);
        return q.kanjiId;
      }
    } else {
      streaks[q.kanjiId] = 0;
    }
    return null;
  }

  void removeCurrentKanji() {
    if (_queue.isEmpty) return;
    final kanjiId = _queue.first.kanjiId;
    if (mode == SessionMode.practice) {
      learnedThisSession.add(kanjiId);
    } else {
      forgottenThisSession.add(kanjiId);
    }
    _removeKanjiFromQueue(kanjiId);
  }

  void _removeKanjiFromQueue(int kanjiId) {
    _queue.removeWhere((q) => q.kanjiId == kanjiId);
  }

  void addReplacementQuestions(List<SessionQuestion> questions) {
    _queue.addAll(questions..shuffle());
  }

  bool get isComplete => _queue.isEmpty;
  double get score => _answered == 0 ? 0 : _correct / _answered;
}
