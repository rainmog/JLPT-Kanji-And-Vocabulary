/// Token record in a sentence (surface form, reading, target indicator, optional hint)
typedef QuestionToken = ({String surface, String reading, bool isTarget, String? hint});

/// Base class for all quiz questions
abstract class QuizQuestion {
  final int kanjiId;
  final String character;
  final String meaning;

  QuizQuestion({
    required this.kanjiId,
    required this.character,
    required this.meaning,
  });
}

/// Mode 1: Kanji alone (reading + meaning multiple choice)
class KanjiQuestion extends QuizQuestion {
  final List<String> readingOptions;    // 4 on/kun readings
  final List<String> meaningOptions;    // 4 meanings
  final String correctReading;
  final String correctMeaning;

  KanjiQuestion({
    required super.kanjiId,
    required super.character,
    required super.meaning,
    required this.readingOptions,
    required this.meaningOptions,
    required this.correctReading,
    required this.correctMeaning,
  });
}

/// Mode 2: Kanji compounds (full word reading via typing or MC)
class WordQuestion extends QuizQuestion {
  final String word;                    // Surface form (e.g., "食べます")
  final String correctReading;          // Hiragana reading
  final String sentenceContext;         // Example sentence
  final List<String> mcOptions;         // Empty when keyboard mode
  final String englishTranslation;      // Sentence English translation for feedback
  final String wordMeaning;             // Vocabulary meaning of the compound (e.g. "medicine")

  WordQuestion({
    required super.kanjiId,
    required super.character,
    required super.meaning,
    required this.word,
    required this.correctReading,
    required this.sentenceContext,
    this.mcOptions = const [],
    this.englishTranslation = '',
    this.wordMeaning = '',
  });
}

/// Mode 3: Sentence with kanji highlighted, multiple choice or type
class SentenceQuestion extends QuizQuestion {
  final String sentenceKanji;
  final List<QuestionToken> tokens;

  final List<String> mcOptions;         // Multiple choice readings
  final String correctReading;
  final String englishTranslation;
  final int difficulty;                 // 1-9
  final String? targetWord;            // overrides token-surface join when tokenizer over-merged

  SentenceQuestion({
    required super.kanjiId,
    required super.character,
    required super.meaning,
    required this.sentenceKanji,
    required this.tokens,
    required this.mcOptions,
    required this.correctReading,
    required this.englishTranslation,
    required this.difficulty,
    this.targetWord,
  }) {
    assert(difficulty >= 1 && difficulty <= 9, 'difficulty must be 1-9, got $difficulty');
  }
}

/// Answer submission
class QuizAnswer {
  final QuizQuestion question;
  final String userAnswer;
  final bool isCorrect;

  QuizAnswer({
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
  });
}

/// Session metadata
class QuizSession {
  final String mode;                    // 'kanji', 'word', 'sentence'
  final List<int> jlptLevels;
  final List<String> tags;
  final int questionCount;
  final int minDifficulty;
  final int maxDifficulty;
  final List<QuizQuestion> questions;
  final List<QuizAnswer> answers;

  QuizSession({
    required this.mode,
    required this.jlptLevels,
    required this.tags,
    required this.questionCount,
    required this.minDifficulty,
    required this.maxDifficulty,
    required this.questions,
    this.answers = const [],
  });

  int get score => answers.where((a) => a.isCorrect).length;

  /// Create a copy with optionally replaced fields
  QuizSession copyWith({
    String? mode,
    List<int>? jlptLevels,
    List<String>? tags,
    int? questionCount,
    int? minDifficulty,
    int? maxDifficulty,
    List<QuizQuestion>? questions,
    List<QuizAnswer>? answers,
  }) =>
      QuizSession(
        mode: mode ?? this.mode,
        jlptLevels: jlptLevels ?? this.jlptLevels,
        tags: tags ?? this.tags,
        questionCount: questionCount ?? this.questionCount,
        minDifficulty: minDifficulty ?? this.minDifficulty,
        maxDifficulty: maxDifficulty ?? this.maxDifficulty,
        questions: questions ?? this.questions,
        answers: answers ?? this.answers,
      );
}
