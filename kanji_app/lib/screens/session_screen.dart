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
  });

  bool get forceFurigana => jlptLevels.length == 1 && jlptLevels.first == 5;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen>
    with SingleTickerProviderStateMixin {
  bool _initialized = false;
  late TextEditingController _answerController;
  late final AnimationController _feedbackCtrl;
  late final Animation<double> _feedbackScale;
  String? _selectedMCOption;
  String? _selectedMeaningOption;
  bool _showingFeedback = false;
  bool? _lastAnswerCorrect;
  String _lastCorrectAnswer = '';
  String _lastEnglishTranslation = '';

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _feedbackScale = Tween<double>(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(parent: _feedbackCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizControllerProvider);
    final quizController = ref.read(quizControllerProvider.notifier);

    // Initialize once on first render
    if (quizState.session.questions.isEmpty &&
        !quizState.loading &&
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
        );
      });
    }

    if (quizState.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (quizState.error != null) {
      return Scaffold(
        body: Center(child: Text('Error: ${quizState.error}')),
      );
    }

    if (quizState.session.questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No questions')),
      );
    }

    final question = quizController.currentQuestion;
    if (question == null) {
      return const Scaffold(
        body: Center(child: Text('No question loaded')),
      );
    }

    final total = quizState.session.questions.length;
    final progress = quizController.progress;
    final learnedAsync = ref.watch(_learnedKanjiProvider);
    final learnedKanji = learnedAsync.asData?.value ?? const <String>{};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Stop Practice Session?'),
            content: const Text(
              'Are you sure you want to stop this practice session? '
              'You will need to start from the beginning again if you do.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep Practicing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Stop'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          soundService.playGoBack();
          ref.invalidate(quizControllerProvider);
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text('${quizState.currentIndex + 1} / $total'),
      ),
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => quizController.markAsKnown(),
                    child: Text(
                      'Already know this',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppColors.containerRadius),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.pillBg,
                          valueColor: AlwaysStoppedAnimation(AppColors.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${quizState.currentIndex + 1} / $total',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildQuestionContent(question, context, widget.multipleChoice, learnedKanji),
                ),
                SizedBox(
                  height: 110,
                  child: _showingFeedback
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(height: 8),
                        ScaleTransition(
                          scale: _feedbackScale,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: (_lastAnswerCorrect ?? false)
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppColors.containerRadius),
                              border: Border.all(
                                color: (_lastAnswerCorrect ?? false) ? Colors.green : Colors.red,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [
                                  Icon(
                                    (_lastAnswerCorrect ?? false) ? Icons.check_circle : Icons.cancel,
                                    color: (_lastAnswerCorrect ?? false) ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (_lastAnswerCorrect ?? false)
                                          ? 'Correct!'
                                          : 'Incorrect — $_lastCorrectAnswer',
                                      style: TextStyle(
                                        color: (_lastAnswerCorrect ?? false) ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ]),
                                if (_lastEnglishTranslation.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(_lastEnglishTranslation,
                                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Tap anywhere to continue',
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                            textAlign: TextAlign.center),
                      ])
                    : _isKeyboardMode(question)
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleSubmit(context, question, quizController, quizState),
                              child: const Text('Submit'),
                            ),
                          ),
                        ])
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (_showingFeedback)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tapToProceed,
            ),
          ),
      ]),
    )); // closes PopScope child + PopScope
  }

  Widget _buildQuestionContent(QuizQuestion q, BuildContext context, bool multipleChoice, Set<String> learnedKanji) {
    if (q is KanjiQuestion) {
      return _buildKanjiQuestion(q);
    } else if (q is WordQuestion) {
      return _buildWordQuestion(q);
    } else if (q is SentenceQuestion) {
      return _buildSentenceQuestion(q, multipleChoice, learnedKanji);
    }
    return Text('Unknown question type');
  }

  Widget _buildKanjiQuestion(KanjiQuestion q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(q.character, style: TextStyle(fontSize: 64, color: AppColors.kanjiColor)),
        const SizedBox(height: 18),
        Text('On/Kun Reading', style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 8),
        Expanded(
          child: _optionsGrid(
            q.readingOptions,
            selected: _selectedMCOption,
            onSelect: (opt) {
              setState(() => _selectedMCOption = opt);
              if (_selectedMeaningOption != null && !_showingFeedback) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _autoSubmit(q);
                });
              }
            },
            fontSize: 15,
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 18),
        Text('English Meaning', style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 8),
        Expanded(
          child: _optionsGrid(
            q.meaningOptions,
            selected: _selectedMeaningOption,
            onSelect: (opt) {
              setState(() => _selectedMeaningOption = opt);
              if (_selectedMCOption != null && !_showingFeedback) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _autoSubmit(q);
                });
              }
            },
            fontSize: 13,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  void _autoSubmit(QuizQuestion q) {
    if (_showingFeedback) return;
    final controller = ref.read(quizControllerProvider.notifier);
    final state = ref.read(quizControllerProvider);
    _handleSubmit(context, q, controller, state);
  }

  void _tapToProceed() {
    if (!_showingFeedback) return;
    _handleNext(context, ref.read(quizControllerProvider.notifier),
        ref.read(quizControllerProvider));
  }

  bool _isKeyboardMode(QuizQuestion question) {
    if (question is WordQuestion) return question.mcOptions.isEmpty;
    if (question is SentenceQuestion) return !widget.multipleChoice;
    return false;
  }

  Widget _optionsGrid(
    List<String> options, {
    required String? selected,
    required void Function(String) onSelect,
    required double fontSize,
    required int maxLines,
  }) {
    Widget btn(String opt) {
      final isSel = selected == opt;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox.expand(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSel ? AppColors.accent : AppColors.btnBg,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                ),
              ),
              onPressed: () => onSelect(opt),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: fontSize,
                  color: isSel ? AppColors.fg : AppColors.kanjiColor,
                ),
                textAlign: TextAlign.center,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
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

  Widget _buildSentenceToken(QuestionToken token, Set<String> learnedKanji) {
    const double furiganaSlotH = 15.0; // fixed slot — all tokens same height
    final surfaceStyle = TextStyle(
      fontSize: 18,
      color: token.isTarget ? AppColors.accent : AppColors.fg,
      fontWeight: token.isTarget ? FontWeight.bold : FontWeight.normal,
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
                ? Text(
                    token.hint!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.accentBright,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  )
                : null,
          ),
          Text(token.surface, style: surfaceStyle),
        ],
      ),
    );
  }

  Widget _buildWordQuestion(WordQuestion q) {
    final isMC = q.mcOptions.isNotEmpty;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          q.word,
          style: TextStyle(fontSize: 48, color: AppColors.kanjiColor),
        ),
        const SizedBox(height: 12),
        Divider(thickness: 1, color: AppColors.pillBg),
        const SizedBox(height: 8),
        if (isMC)
          ...q.mcOptions.map((option) {
            final isSelected = _selectedMCOption == option;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppColors.accent : AppColors.btnBg,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    if (_showingFeedback) return;
                    setState(() => _selectedMCOption = option);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _autoSubmit(q);
                    });
                  },
                  child: Text(option, style: TextStyle(fontSize: 16)),
                ),
              ),
            );
          })
        else ...[
          Text('Type the reading (hiragana or romaji):',
            style: TextStyle(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            inputFormatters: [RomajiInputFormatter()],
            decoration: InputDecoration(
              hintText: '...',
              hintStyle: TextStyle(color: AppColors.muted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.containerRadius)),
              filled: true,
              fillColor: AppColors.surface,
            ),
            style: TextStyle(color: AppColors.fg),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildSentenceQuestion(SentenceQuestion q, bool multipleChoice, Set<String> learnedKanji) {
    final combined = q.tokens
        .where((t) => t.isTarget)
        .map((t) => t.surface)
        .join();
    final targetSurface = combined.isEmpty ? q.character : combined;

    return Column(
      children: [
        // Centered question area
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    targetSurface,
                    style: TextStyle(fontSize: 56, color: AppColors.kanjiColor),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.pillBg,
                      borderRadius: BorderRadius.circular(AppColors.containerRadius),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: q.tokens.map((token) => _buildSentenceToken(token, learnedKanji)).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Options anchored at bottom
        Divider(thickness: 1, color: AppColors.pillBg),
        const SizedBox(height: 8),
        if (multipleChoice)
          ...q.mcOptions.map((option) {
            final isSelected = _selectedMCOption == option;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppColors.accent : AppColors.btnBg,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    setState(() => _selectedMCOption = option);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _autoSubmit(q);
                    });
                  },
                  child: Text(option,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? AppColors.fg : AppColors.kanjiColor,
                    )),
                ),
              ),
            );
          })
        else
          TextField(
            controller: _answerController,
            inputFormatters: [RomajiInputFormatter()],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '...',
              hintStyle: TextStyle(color: AppColors.muted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.containerRadius)),
              filled: true,
              fillColor: AppColors.surface,
            ),
            style: TextStyle(color: AppColors.fg),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

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
        if (_selectedMCOption == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select an option')),
          );
          return;
        }
        isCorrect = _selectedMCOption == question.correctReading;
        controller.submitAnswer(_selectedMCOption!, isCorrect);
      } else {
        userAnswer = _answerController.text.trim();
        if (userAnswer.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please enter a reading')),
          );
          return;
        }
        isCorrect = AnswerValidator.validate(userAnswer, [question.correctReading]);
        controller.submitAnswer(userAnswer, isCorrect);
      }
      setState(() {
        _showingFeedback = true;
        _lastAnswerCorrect = isCorrect;
        _lastCorrectAnswer = question.correctReading;
        _lastEnglishTranslation = question.wordMeaning;
      });
    } else if (question is KanjiQuestion) {
      if (_selectedMCOption == null || _selectedMeaningOption == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Select both a reading and a meaning')),
        );
        return;
      }
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
        if (_selectedMCOption == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select an option')),
          );
          return;
        }
        isCorrect = _selectedMCOption == question.correctReading;
        controller.submitAnswer(_selectedMCOption!, isCorrect);
      } else {
        userAnswer = _answerController.text.trim();
        if (userAnswer.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please enter a reading')),
          );
          return;
        }
        isCorrect = AnswerValidator.validate(userAnswer, [question.correctReading]);
        controller.submitAnswer(userAnswer, isCorrect);
      }
      setState(() {
        _showingFeedback = true;
        _lastAnswerCorrect = isCorrect;
        _lastCorrectAnswer = question.correctReading;
        _lastEnglishTranslation = question.englishTranslation;
      });
    }
    if (isCorrect) {
      soundService.playCorrect();
    } else {
      soundService.playWrong();
    }
    if (ref.read(settingsProvider).animationsEnabled) {
      _feedbackCtrl.forward(from: 0);
    } else {
      _feedbackCtrl.value = 1.0;
    }
  }

  void _handleNext(
    BuildContext context,
    QuizController controller,
    QuizState state,
  ) {
    if (controller.isLastQuestion) {
      final session = state.session;
      Navigator.pushReplacement(
        context,
        AppRoute.to(SessionSummaryScreen(
          correct: session.score,
          total: session.answers.length,
          learnedChars: session.answers
              .where((a) => a.isCorrect)
              .map((a) => a.question.character)
              .toList(),
        )),
      );
      return;
    }

    controller.nextQuestion();
    setState(() {
      _showingFeedback = false;
      _lastAnswerCorrect = null;
      _lastCorrectAnswer = '';
      _lastEnglishTranslation = '';
      _answerController.clear();
      _selectedMCOption = null;
      _selectedMeaningOption = null;
    });
  }
}
