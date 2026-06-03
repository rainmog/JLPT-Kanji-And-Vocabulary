import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz_models.dart';
import '../repositories/sentence_repository.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/database_service.dart' show DatabaseService, dbService;

/// Riverpod provider for DatabaseService singleton
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return dbService;
});

/// Provider to fetch all available tags from the database
final allTagsProvider = FutureProvider<List<String>>((ref) async {
  final repo = KanjiRepository();
  return repo.getAllTags();
});

/// Unified state for any quiz mode (kanji, word, or sentence)
class QuizState {
  final QuizSession session;
  final int currentIndex;
  final bool loading;
  final String? error;

  QuizState({
    required this.session,
    this.currentIndex = 0,
    this.loading = false,
    this.error,
  });

  QuizState copyWith({
    QuizSession? session,
    int? currentIndex,
    bool? loading,
    String? error,
  }) =>
      QuizState(
        session: session ?? this.session,
        currentIndex: currentIndex ?? this.currentIndex,
        loading: loading ?? this.loading,
        error: error ?? this.error,
      );
}

/// Unified controller for all three practice modes
class QuizController extends Notifier<QuizState> {
  late DatabaseService _dbService;
  late SentenceRepository _sentenceRepo;

  @override
  QuizState build() {
    _dbService = ref.watch(databaseServiceProvider);
    _sentenceRepo = SentenceRepository(dbService: _dbService);
    return QuizState(
      session: QuizSession(
        mode: 'sentence',
        jlptLevels: [],
        tags: [],
        questionCount: 20,
        minDifficulty: 1,
        maxDifficulty: 9,
        questions: [],
      ),
    );
  }

  /// Initialize quiz session (call after user selects config)
  Future<void> initializeSession({
    required String mode,
    required List<int> jlptLevels,
    required List<String> tags,
    required int questionCount,
    required int minDifficulty,
    required int maxDifficulty,
    bool multipleChoice = true,
    bool targetOnly = false,
    bool reviewOnly = false,
  }) async {
    state = state.copyWith(loading: true, error: null);

    try {
      List<QuizQuestion> questions = [];

      if (mode == 'kanji' || mode == 'wordpractice') {
        questions = await _sentenceRepo.buildKanjiQuestions(
          jlptLevels: jlptLevels,
          tags: tags,
          count: questionCount,
          targetOnly: targetOnly,
          reviewOnly: reviewOnly,
        );
      } else if (mode == 'word') {
        questions = await _sentenceRepo.buildWordQuestions(
          jlptLevels: jlptLevels,
          tags: tags,
          count: questionCount,
          minDifficulty: minDifficulty,
          maxDifficulty: maxDifficulty,
          multipleChoice: multipleChoice,
          targetOnly: targetOnly,
          reviewOnly: reviewOnly,
        );
      } else if (mode == 'sentence') {
        questions = await _sentenceRepo.buildSentenceQuestions(
          jlptLevels: jlptLevels,
          tags: tags,
          count: questionCount,
          minDifficulty: minDifficulty,
          maxDifficulty: maxDifficulty,
          multipleChoice: multipleChoice,
          targetOnly: targetOnly,
          reviewOnly: reviewOnly,
        );
      }

      state = state.copyWith(
        session: QuizSession(
          mode: mode,
          jlptLevels: jlptLevels,
          tags: tags,
          questionCount: questionCount,
          minDifficulty: minDifficulty,
          maxDifficulty: maxDifficulty,
          questions: questions,
        ),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  /// Submit answer and record it (does not move to next question).
  /// Fire-and-forgets DB persistence; state update is immediate.
  void submitAnswer(String userAnswer, bool isCorrect) {
    if (state.session.questions.isEmpty) return;

    final q = state.session.questions[state.currentIndex];
    _persistAnswer(q.kanjiId, isCorrect); // fire-and-forget

    final updatedSession = state.session.copyWith(
      answers: [...state.session.answers, QuizAnswer(
        question: q, userAnswer: userAnswer, isCorrect: isCorrect)],
    );
    state = state.copyWith(session: updatedSession);
  }

  Future<void> _persistAnswer(int kanjiId, bool isCorrect) async {
    if (isCorrect) {
      await progressRepo.recordCorrect(kanjiId);
    } else {
      await progressRepo.recordIncorrect(kanjiId);
    }
  }

  /// Move to next question
  void nextQuestion() {
    if (state.currentIndex < state.session.questions.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  /// Mark current question as known: immediately persists learned status.
  void markAsKnown() {
    if (state.session.questions.isEmpty) return;
    final kanjiId = state.session.questions[state.currentIndex].kanjiId;
    progressRepo.markLearned(kanjiId);   // fire-and-forget
    progressRepo.recordCorrect(kanjiId); // fire-and-forget
    submitAnswer('', true);
    nextQuestion();
  }

  /// Get current question (nullable if list empty or index out of bounds)
  QuizQuestion? get currentQuestion {
    if (state.session.questions.isEmpty ||
        state.currentIndex >= state.session.questions.length) {
      return null;
    }
    return state.session.questions[state.currentIndex];
  }

  /// Check if this is the last question
  bool get isLastQuestion =>
      state.currentIndex >= state.session.questions.length - 1;

  /// Get progress as percentage
  double get progress =>
      (state.currentIndex + 1) / state.session.questions.length;
}

/// Riverpod provider for quiz controller
final quizControllerProvider = NotifierProvider<QuizController, QuizState>(
  QuizController.new,
);
