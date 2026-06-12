import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/quiz_controller.dart';
import '../models/quiz_models.dart';
import '../theme.dart';
import '../utils/romaji_converter.dart';
import '../utils/answer_validator.dart';
import 'session_summary_screen.dart';
import '../repositories/progress_repository.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../utils/app_route.dart';

final _learnedKanjiProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  return progressRepo.getLearnedKanjiCharacters();
});

class SessionScreen extends ConsumerStatefulWidget {
  final String mode;
  final List<int> jlptLevels;
  final List<String> tags;
  final int questionCount;
  final int minDifficulty;
  final int maxDifficulty;
  final bool multipleChoice;
  final bool targetOnly;
  final bool reviewOnly;
  final List<int>? fixedKanjiIds;

  const SessionScreen({
    super.key,
    required this.mode,
    required this.jlptLevels,
    required this.tags,
    this.questionCount = 20,
    this.minDifficulty = 1,
    this.maxDifficulty = 9,
    this.multipleChoice = true,
    this.targetOnly = false,
    this.reviewOnly = false,
    this.fixedKanjiIds,
  });

  bool get forceFurigana => jlptLevels.length == 1 && jlptLevels.first == 5;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  bool _initialized = false;
  late TextEditingController _answerController;
  String? _selectedMCOption;
  String? _selectedMeaningOption;
  bool _showingFeedback = false;
  bool? _lastAnswerCorrect;
  String _lastCorrectAnswer = '';
  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizControllerProvider);
    final quizController = ref.read(quizControllerProvider.notifier);

    if (!quizState.loading &&
        quizState.error == null &&
        !_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initialized = true;
        soundService.playTestStart();
        quizController.initializeSession(
          mode: widget.mode,
          jlptLevels: widget.jlptLevels,
          tags: widget.tags,
          questionCount: widget.questionCount,
          minDifficulty: widget.minDifficulty,
          maxDifficulty: widget.maxDifficulty,
          multipleChoice: widget.multipleChoice,
          targetOnly: widget.targetOnly,
          reviewOnly: widget.reviewOnly,
          fixedKanjiIds: widget.fixedKanjiIds,
        );
      });
    }

    if (quizState.loading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (quizState.error != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('Error: ${quizState.error}',
          style: TextStyle(color: AppColors.muted))),
      );
    }

    if (quizState.session.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('No questions',
          style: TextStyle(color: AppColors.muted))),
      );
    }

    final question = quizController.currentQuestion;
    if (question == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('No question loaded',
          style: TextStyle(color: AppColors.muted))),
      );
    }

    final progress = quizController.progress;
    final learnedAsync = ref.watch(_learnedKanjiProvider);
    final learnedKanji = learnedAsync.asData?.value ?? const <String>{};
    final isKeyboard = _isKeyboardMode(question);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Stop Practice Session?',
              style: TextStyle(color: AppColors.fg, fontSize: 17, fontWeight: FontWeight.w700)),
            content: Text(
              'Are you sure you want to stop? You will need to start from the beginning.',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Keep Practicing', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Stop', style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          _autoNextTimer?.cancel();
          soundService.playGoBack();
          ref.invalidate(quizControllerProvider);
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Stack(children: [
            Column(children: [
              // ── Header ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Column(children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.pillBg),
                          boxShadow: [BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.07),
                            blurRadius: 8, offset: const Offset(0, 2),
                          )],
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.fg),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => quizController.markAsKnown(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text('I know this',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.accent)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppColors.pillBg,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ]),
              ),
              // ── Question content ────────────────────────────────────────────
              Expanded(
                child: _buildQuestionContent(question, context, widget.multipleChoice, learnedKanji),
              ),
              // ── Keyboard submit footer ──────────────────────────────────────
              if (isKeyboard)
                _buildKeyboardFooter(question, quizController, quizState),
            ]),
            // Tap-to-advance early (silent)
            if (_showingFeedback)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _autoNextTimer?.cancel();
                    _handleNext(context,
                      ref.read(quizControllerProvider.notifier),
                      ref.read(quizControllerProvider));
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ── Question routing ─────────────────────────────────────────────────────────

  Widget _buildQuestionContent(QuizQuestion q, BuildContext context,
      bool multipleChoice, Set<String> learnedKanji) {
    if (q is KanjiQuestion) {
      return _buildKanjiQuestion(q);
    } else if (q is WordQuestion) {
      return _buildWordQuestion(q);
    } else if (q is SentenceQuestion) {
      return _buildSentenceQuestion(q, multipleChoice, learnedKanji);
    }
    return const SizedBox();
  }

  // ── Kanji question (on/kun + meaning dual grids) ──────────────────────────────

  Widget _buildKanjiQuestion(KanjiQuestion q) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(q.character,
            style: TextStyle(
              fontSize: 72, fontWeight: FontWeight.w600,
              color: AppColors.fg,
              fontFamily: AppFonts.japaneseFont,
              fontFamilyFallback: AppFonts.japaneseFallback,
            )),
          const SizedBox(height: 18),
          _sectionLabel('Reading'),
          const SizedBox(height: 8),
          Expanded(
            child: _optionsGrid(
              q.readingOptions,
              selected: _selectedMCOption,
              correctAnswer: q.correctReading,
              onSelect: (opt) {
                if (_showingFeedback) return;
                setState(() => _selectedMCOption = opt);
                if (_selectedMeaningOption != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _autoSubmit(q);
                  });
                }
              },
              fontSize: 15,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 12),
          _sectionLabel('Meaning'),
          const SizedBox(height: 8),
          Expanded(
            child: _optionsGrid(
              q.meaningOptions,
              selected: _selectedMeaningOption,
              correctAnswer: q.correctMeaning,
              onSelect: (opt) {
                if (_showingFeedback) return;
                setState(() => _selectedMeaningOption = opt);
                if (_selectedMCOption != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _autoSubmit(q);
                  });
                }
              },
              fontSize: 13,
              maxLines: 2,
            ),
          ),
          if (_showingFeedback) ...[
            const SizedBox(height: 8),
            Text(
              'Tap anywhere to continue',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label.toUpperCase(),
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.8, color: AppColors.muted,
        )),
    );
  }

  // ── Word/compound question ────────────────────────────────────────────────────

  Widget _buildWordQuestion(WordQuestion q) {
    final isMC = q.mcOptions.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(children: [
        Expanded(
          child: Center(
            child: Text(q.word,
              style: TextStyle(
                fontSize: 72, fontWeight: FontWeight.w600,
                color: AppColors.fg,
                fontFamily: AppFonts.japaneseFont,
                fontFamilyFallback: AppFonts.japaneseFallback,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (_showingFeedback) ...[
          _MeaningCard(meaning: q.wordMeaning, translation: ''),
          const SizedBox(height: 12),
        ],
        if (isMC)
          _mcButtonList(
            options: q.mcOptions,
            selected: _selectedMCOption,
            correctAnswer: q.correctReading,
            onSelect: (opt) {
              if (_showingFeedback) return;
              setState(() => _selectedMCOption = opt);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _autoSubmit(q);
              });
            },
          )
        else
          _buildTypeField(),
      ]),
    );
  }

  // ── Sentence question ─────────────────────────────────────────────────────────

  Widget _buildSentenceQuestion(SentenceQuestion q, bool multipleChoice, Set<String> learnedKanji) {
    final combined = q.tokens.where((t) => t.isTarget).map((t) => t.surface).join();
    final targetSurface = q.targetWord ?? (combined.isEmpty ? q.character : combined);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(children: [
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(targetSurface,
                style: TextStyle(
                  fontSize: 64, fontWeight: FontWeight.w600,
                  color: AppColors.fg,
                  fontFamily: AppFonts.japaneseFont,
                  fontFamilyFallback: AppFonts.japaneseFallback,
                )),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: q.tokens.map((t) => _buildSentenceToken(t, learnedKanji)).toList(),
                ),
              ),
            ]),
          ),
        ),
        if (_showingFeedback && q.englishTranslation.isNotEmpty) ...[
          _MeaningCard(meaning: '', translation: q.englishTranslation),
          const SizedBox(height: 12),
        ],
        if (multipleChoice)
          _mcButtonList(
            options: q.mcOptions,
            selected: _selectedMCOption,
            correctAnswer: q.correctReading,
            onSelect: (opt) {
              if (_showingFeedback) return;
              setState(() => _selectedMCOption = opt);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _autoSubmit(q);
              });
            },
          )
        else
          _buildTypeField(),
      ]),
    );
  }

  // ── Sentence token rendering ──────────────────────────────────────────────────

  Widget _buildSentenceToken(QuestionToken token, Set<String> learnedKanji) {
    const double furiganaSlotH = 15.0;
    final surfaceStyle = TextStyle(
      fontSize: 18, height: 1.2,
      color: token.isTarget ? AppColors.accent : AppColors.fg,
      fontWeight: token.isTarget ? FontWeight.bold : FontWeight.normal,
      fontFamily: AppFonts.japaneseFont,
      fontFamilyFallback: AppFonts.japaneseFallback,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: furiganaSlotH,
            child: (token.hint != null && token.hint!.isNotEmpty &&
                    (widget.forceFurigana || !learnedKanji.contains(token.surface)))
                ? Text(token.hint!,
                    style: TextStyle(
                      fontSize: 11, color: AppColors.accent, height: 1.0,
                      fontFamily: AppFonts.japaneseFont,
                      fontFamilyFallback: AppFonts.japaneseFallback,
                    ),
                    textAlign: TextAlign.center)
                : null,
          ),
          Text(token.surface, style: surfaceStyle),
        ],
      ),
    );
  }

  // ── MC button list (stacked, for Word/Sentence) ───────────────────────────────

  Widget _mcButtonList({
    required List<String> options,
    required String? selected,
    required String correctAnswer,
    required void Function(String) onSelect,
  }) {
    return Column(children: [
      ...options.map((opt) {
        final state = _mcState(opt, selected, correctAnswer);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MCButton(
            text: opt,
            state: state,
            onTap: () => onSelect(opt),
          ),
        );
      }),
      if (_showingFeedback)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Tap anywhere to continue',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
    ]);
  }

  // ── Options grid (2×2, for KanjiQuestion) ────────────────────────────────────

  Widget _optionsGrid(
    List<String> options, {
    required String? selected,
    required String correctAnswer,
    required void Function(String) onSelect,
    required double fontSize,
    required int maxLines,
  }) {
    Widget btn(String opt) {
      final state = _mcState(opt, selected, correctAnswer);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox.expand(
            child: _MCButton(
              text: opt,
              state: state,
              onTap: () => onSelect(opt),
              fontSize: fontSize,
              maxLines: maxLines,
              isJapanese: false,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: Row(children: [btn(options[0]), btn(options[1])])),
        Expanded(child: Row(children: [btn(options[2]), btn(options[3])])),
      ],
    );
  }

  // ── MC button state helper ────────────────────────────────────────────────────

  String _mcState(String opt, String? selected, String correctAnswer) {
    if (!_showingFeedback) return opt == selected ? 'selected' : 'idle';
    if (opt == correctAnswer) return 'correct';
    if (opt == selected) return 'wrong';
    return 'dim';
  }

  // ── Type input field ─────────────────────────────────────────────────────────

  Widget _buildTypeField() {
    final borderColor = _showingFeedback
        ? (_lastAnswerCorrect == true ? AppColors.correct : AppColors.incorrect)
        : AppColors.accent;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_showingFeedback) ...[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _lastAnswerCorrect == true ? 'Correct!' : 'Answer: $_lastCorrectAnswer',
            key: ValueKey(_lastAnswerCorrect),
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: _lastAnswerCorrect == true ? AppColors.correct : AppColors.incorrect,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
      ],
      Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.07),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: TextField(
          controller: _answerController,
          inputFormatters: [RomajiInputFormatter()],
          enabled: !_showingFeedback,
          autofocus: true,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.fg),
          decoration: InputDecoration(
            hintText: 'Type the reading…',
            hintStyle: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onSubmitted: (_) {
            final q = ref.read(quizControllerProvider.notifier).currentQuestion;
            if (q != null) _handleSubmit(context, q,
              ref.read(quizControllerProvider.notifier), ref.read(quizControllerProvider));
          },
        ),
      ),
    ]);
  }

  // ── Keyboard submit footer ────────────────────────────────────────────────────

  Widget _buildKeyboardFooter(QuizQuestion question, QuizController quizController, QuizState quizState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _showingFeedback
                ? AppColors.pillBg
                : AppColors.accent,
            foregroundColor: _showingFeedback ? AppColors.muted : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: _showingFeedback ? null :
            () => _handleSubmit(context, question, quizController, quizState),
          child: Text('Submit',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  // ── Auto-submit (KanjiQuestion both selected) ─────────────────────────────────

  void _autoSubmit(QuizQuestion q) {
    if (_showingFeedback) return;
    final controller = ref.read(quizControllerProvider.notifier);
    final state = ref.read(quizControllerProvider);
    _handleSubmit(context, q, controller, state);
  }

  bool _isKeyboardMode(QuizQuestion question) {
    if (question is WordQuestion) return question.mcOptions.isEmpty;
    if (question is SentenceQuestion) return !widget.multipleChoice;
    return false;
  }

  // ── Submit handler ────────────────────────────────────────────────────────────

  void _handleSubmit(
    BuildContext context,
    QuizQuestion question,
    QuizController controller,
    QuizState state,
  ) {
    String? userAnswer;
    bool isCorrect = false;

    if (question is WordQuestion) {
      if (question.mcOptions.isNotEmpty) {
        if (_selectedMCOption == null) return;
        isCorrect = _selectedMCOption == question.correctReading;
        controller.submitAnswer(_selectedMCOption!, isCorrect);
      } else {
        userAnswer = _answerController.text.trim();
        if (userAnswer.isEmpty) return;
        isCorrect = AnswerValidator.validate(userAnswer, [question.correctReading]);
        controller.submitAnswer(userAnswer, isCorrect);
      }
      setState(() {
        _showingFeedback = true;
        _lastAnswerCorrect = isCorrect;
        _lastCorrectAnswer = question.correctReading;
      });
    } else if (question is KanjiQuestion) {
      if (_selectedMCOption == null || _selectedMeaningOption == null) return;
      final readingCorrect = _selectedMCOption == question.correctReading;
      final meaningCorrect = _selectedMeaningOption == question.correctMeaning;
      isCorrect = readingCorrect && meaningCorrect;
      controller.submitAnswer('${_selectedMCOption}|${_selectedMeaningOption}', isCorrect);
      String correctMsg;
      if (!readingCorrect && !meaningCorrect) {
        correctMsg = '${question.correctReading} / ${question.correctMeaning}';
      } else if (!readingCorrect) {
        correctMsg = question.correctReading;
      } else {
        correctMsg = question.correctMeaning;
      }
      setState(() {
        _showingFeedback = true;
        _lastAnswerCorrect = isCorrect;
        _lastCorrectAnswer = correctMsg;
      });
    } else if (question is SentenceQuestion) {
      if (widget.multipleChoice) {
        if (_selectedMCOption == null) return;
        isCorrect = _selectedMCOption == question.correctReading;
        controller.submitAnswer(_selectedMCOption!, isCorrect);
      } else {
        userAnswer = _answerController.text.trim();
        if (userAnswer.isEmpty) return;
        isCorrect = AnswerValidator.validate(userAnswer, [question.correctReading]);
        controller.submitAnswer(userAnswer, isCorrect);
      }
      setState(() {
        _showingFeedback = true;
        _lastAnswerCorrect = isCorrect;
        _lastCorrectAnswer = question.correctReading;
      });
    }

    if (isCorrect) {
      soundService.playCorrect();
    } else {
      soundService.playWrong();
    }
  }

  // ── Next question / session end ───────────────────────────────────────────────

  Future<void> _handleNext(
    BuildContext context,
    QuizController controller,
    QuizState state,
  ) async {
    _autoNextTimer?.cancel();
    if (controller.isLastQuestion) {
      final session = state.session;

      // Prefetch practice counts for all questions in session
      final ids = session.questions.map((q) => q.kanjiId).toList();
      final counts = await progressRepo.getPracticeCountsForIds(ids);

      // Build display list sorted descending by count (de-duplicated by kanjiId)
      final seen = <int>{};
      final practiceCounts = <({String display, int count})>[];
      for (final q in session.questions) {
        if (seen.add(q.kanjiId)) {
          final cnt = counts[q.kanjiId] ?? 0;
          practiceCounts.add((display: q.character, count: cnt));
        }
      }
      practiceCounts.sort((a, b) => b.count.compareTo(a.count));

      progressRepo.logSession(
        mode: session.mode,
        kanjiIds: ids,
        score: session.score,
        questionCount: session.answers.length,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        this.context,
        AppRoute.to(SessionSummaryScreen(
          correct: session.score,
          total: session.answers.length,
          learnedChars: session.answers
              .where((a) => a.isCorrect)
              .map((a) => a.question.character)
              .toList(),
          practiceCounts: practiceCounts,
        )),
      );
      return;
    }

    controller.nextQuestion();
    setState(() {
      _showingFeedback = false;
      _lastAnswerCorrect = null;
      _lastCorrectAnswer = '';
      _answerController.clear();
      _selectedMCOption = null;
      _selectedMeaningOption = null;
    });
  }
}

// ── Shared MC button widget ───────────────────────────────────────────────────

class _MCButton extends StatelessWidget {
  final String text;
  final String state; // 'idle' | 'correct' | 'wrong' | 'dim'
  final VoidCallback onTap;
  final double fontSize;
  final int maxLines;
  final bool isJapanese;

  const _MCButton({
    required this.text,
    required this.state,
    required this.onTap,
    this.fontSize = 15.5,
    this.maxLines = 2,
    this.isJapanese = true,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, textColor, borderColor;
    List<BoxShadow> shadow = [];

    switch (state) {
      case 'correct':
        bg = AppColors.correct;
        textColor = Colors.white;
        borderColor = AppColors.correct;
        break;
      case 'wrong':
        bg = AppColors.incorrect;
        textColor = Colors.white;
        borderColor = AppColors.incorrect;
        break;
      case 'selected':
        bg = AppColors.accent.withValues(alpha: 0.12);
        textColor = AppColors.accent;
        borderColor = AppColors.accent;
        break;
      case 'dim':
        bg = AppColors.surface;
        textColor = AppColors.muted.withValues(alpha: 0.5);
        borderColor = AppColors.pillBg.withValues(alpha: 0.5);
        break;
      default: // idle
        bg = AppColors.surface;
        textColor = AppColors.fg;
        borderColor = AppColors.pillBg;
        shadow = [BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.07),
          blurRadius: 8, offset: const Offset(0, 2),
        )];
    }

    return GestureDetector(
      onTap: (state == 'idle' || state == 'selected') ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: shadow,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: textColor,
                fontFamily: isJapanese ? AppFonts.japaneseFont : null,
                fontFamilyFallback: isJapanese ? AppFonts.japaneseFallback : null,
              ),
              textAlign: TextAlign.center,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state == 'correct') ...[
            const SizedBox(width: 8),
            const Icon(Icons.check, size: 15, color: Colors.white),
          ],
        ]),
      ),
    );
  }
}

// ── Meaning/translation feedback card ────────────────────────────────────────

class _MeaningCard extends StatelessWidget {
  final String meaning;
  final String translation;
  const _MeaningCard({required this.meaning, required this.translation});

  @override
  Widget build(BuildContext context) {
    if (meaning.isEmpty && translation.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pillBg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (meaning.isNotEmpty)
            Text(
              meaning,
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.fg,
              ),
              textAlign: TextAlign.center,
            ),
          if (meaning.isNotEmpty && translation.isNotEmpty)
            const SizedBox(height: 4),
          if (translation.isNotEmpty)
            Text(
              translation,
              style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
