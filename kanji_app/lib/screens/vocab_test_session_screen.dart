import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/progress_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../widgets/quiz_header.dart';
import '../utils/app_route.dart';
import 'vocab_test_result_screen.dart';

sealed class VocabTestQuestion {
  final VocabWord word;
  const VocabTestQuestion(this.word);
}

class WordToMeaningQuestion extends VocabTestQuestion {
  final List<String> options;
  const WordToMeaningQuestion(super.word, this.options);
}

class MeaningToWordQuestion extends VocabTestQuestion {
  final List<String> options;
  const MeaningToWordQuestion(super.word, this.options);
}

class VocabTestSessionScreen extends ConsumerStatefulWidget {
  final List<VocabWord> allTargets;
  const VocabTestSessionScreen({super.key, required this.allTargets});

  @override
  ConsumerState<VocabTestSessionScreen> createState() => _VocabTestSessionScreenState();
}

class _VocabTestSessionScreenState extends ConsumerState<VocabTestSessionScreen> {
  List<VocabTestQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  String? _selectedOption;
  bool _showingFeedback = false;
  bool? _lastCorrect;
  Timer? _autoNextTimer;

  final Map<int, ({bool? wordToMeaning, bool? meaningToWord})> _scores = {};
  late List<VocabWord> _testedWords;
  Set<String> _learnedKanji = {};

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    super.dispose();
  }

  Future<void> _build() async {
    final shuffled = [...widget.allTargets]..shuffle();
    _testedWords = shuffled.take(25).toList();
    for (final w in _testedWords) {
      _scores[w.id] = (wordToMeaning: null, meaningToWord: null);
    }

    final learned = await progressRepo.getLearnedKanjiCharacters();

    final qs = <VocabTestQuestion>[];
    for (final word in _testedWords) {
      final meaningDistractors = await vocabRepo.getDistractors(
        jlptLevel: word.jlptLevel,
        count: 3,
        excludeIds: [word.id],
      );
      final meaningOpts = [word.meanings, ...meaningDistractors.map((d) => d.meanings)]..shuffle();
      qs.add(WordToMeaningQuestion(word, meaningOpts));

      final readingDistractors = await vocabRepo.getDistractors(
        jlptLevel: word.jlptLevel,
        count: 3,
        excludeIds: [word.id],
      );
      final readingOpts = [word.reading, ...readingDistractors.map((d) => d.reading)]..shuffle();
      qs.add(MeaningToWordQuestion(word, readingOpts));
    }
    qs.shuffle();

    if (!mounted) return;
    setState(() {
      _questions = qs;
      _learnedKanji = learned;
      _loading = false;
    });
    soundService.playTestStart();
  }

  String _displayWord(VocabWord word) {
    if (word.word == word.reading || word.isUsuallyKana) return word.reading;
    final kanjiChars = word.word.split('').where(_isKanji);
    if (kanjiChars.isEmpty) return word.reading;
    if (kanjiChars.every((c) => _learnedKanji.contains(c))) return word.word;
    return word.reading;
  }

  bool _isKanji(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) ||
           (code >= 0x3400 && code <= 0x4DBF) ||
           (code >= 0xF900 && code <= 0xFAFF);
  }

  void _handleSelect(String option) {
    if (_showingFeedback) return;
    final q = _questions[_currentIndex];
    final bool isCorrect;
    final bool isWordToMeaning;

    switch (q) {
      case WordToMeaningQuestion():
        isCorrect = option == q.word.meanings;
        isWordToMeaning = true;
      case MeaningToWordQuestion():
        isCorrect = option == q.word.reading;
        isWordToMeaning = false;
    }

    final prev = _scores[q.word.id] ?? (wordToMeaning: null, meaningToWord: null);
    if (!isCorrect) {
      _scores[q.word.id] = (wordToMeaning: false, meaningToWord: false);
    } else if (isWordToMeaning) {
      _scores[q.word.id] = (
        wordToMeaning: true,
        meaningToWord: prev.meaningToWord == false ? false : prev.meaningToWord,
      );
    } else {
      _scores[q.word.id] = (
        wordToMeaning: prev.wordToMeaning == false ? false : prev.wordToMeaning,
        meaningToWord: true,
      );
    }

    setState(() {
      _selectedOption = option;
      _showingFeedback = true;
      _lastCorrect = isCorrect;
    });

    if (isCorrect) {
      soundService.playCorrect();
      _autoNextTimer = Timer(const Duration(seconds: 1), _next);
    } else {
      soundService.playWrong();
    }
  }

  void _next() {
    _autoNextTimer?.cancel();
    if (!mounted) return;
    if (_currentIndex >= _questions.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _showingFeedback = false;
      _lastCorrect = null;
    });
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      AppRoute.to(VocabTestResultScreen(
        testedWords: _testedWords,
        scores: Map.from(_scores),
      )),
    );
  }

  Future<void> _showCancelDialog() async {
    _autoNextTimer?.cancel();
    final colors = ref.read(themeColorsProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.fg),
        contentTextStyle: TextStyle(fontSize: 14, color: colors.muted),
        title: const Text('Cancel Test?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Test'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context);
    } else if (_showingFeedback && _lastCorrect == true) {
      _autoNextTimer = Timer(const Duration(seconds: 1), _next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final q = _questions[_currentIndex];
    final progress = '${_currentIndex + 1} / ${_questions.length}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showCancelDialog();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Stack(children: [
          SafeArea(
            child: Column(children: [
              QuizHeader(
                progress: progress,
                onBack: _showCancelDialog,
                current: _currentIndex + 1,
                total: _questions.length,
              ),
              Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          switch (q) {
                            WordToMeaningQuestion() => _displayWord(q.word),
                            MeaningToWordQuestion() => q.word.meanings,
                          },
                          style: TextStyle(
                            fontSize: switch (q) {
                              WordToMeaningQuestion() => 56.0,
                              MeaningToWordQuestion() => 22.0,
                            },
                            color: AppColors.kanjiColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          switch (q) {
                            WordToMeaningQuestion() => 'What does this mean?',
                            MeaningToWordQuestion() => 'Which word?',
                          },
                          style: TextStyle(fontSize: 14, color: colors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    ),
                  ),
                ),
                Divider(thickness: 1, color: colors.pillBg),
                const SizedBox(height: 8),
                ...List.generate((switch (q) {
                  WordToMeaningQuestion() => q.options,
                  MeaningToWordQuestion() => q.options,
                }).length, (i) {
                  final opts = switch (q) {
                    WordToMeaningQuestion() => q.options,
                    MeaningToWordQuestion() => q.options,
                  };
                  final opt = opts[i];
                  final isCorrectOpt = switch (q) {
                    WordToMeaningQuestion() => opt == q.word.meanings,
                    MeaningToWordQuestion() => opt == q.word.reading,
                  };
                  final state = !_showingFeedback
                      ? _VocabOptionState.idle
                      : isCorrectOpt
                          ? _VocabOptionState.correct
                          : (_selectedOption == opt)
                              ? _VocabOptionState.wrong
                              : _VocabOptionState.idle;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _VocabOptionButton(
                      label: '${i + 1}',
                      text: opt,
                      state: state,
                      onTap: () => _handleSelect(opt),
                    ),
                  );
                }),
                SizedBox(
                  height: 36,
                  child: _showingFeedback
                      ? Center(
                          child: Text('Tap anywhere to continue',
                              style: TextStyle(fontSize: 13, color: colors.muted)),
                        )
                      : null,
                ),
              ]),
            )),
          ]),
          ),
          if (_showingFeedback)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _autoNextTimer?.cancel();
                  _next();
                },
              ),
            ),
        ]),
      ),
    );
  }
}

enum _VocabOptionState { idle, correct, wrong }

class _VocabOptionButton extends StatelessWidget {
  final String label;
  final String text;
  final _VocabOptionState state;
  final VoidCallback onTap;
  const _VocabOptionButton({required this.label, required this.text,
      required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = switch (state) {
      _VocabOptionState.correct => AppColors.correctBg,
      _VocabOptionState.wrong => AppColors.incorrectBg,
      _VocabOptionState.idle => AppColors.btnBg,
    };
    final fg = switch (state) {
      _VocabOptionState.correct => AppColors.correct,
      _VocabOptionState.wrong => AppColors.incorrect,
      _VocabOptionState.idle => AppColors.fg,
    };
    return GestureDetector(
      onTap: state == _VocabOptionState.idle ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          border: Border.all(
            color: state == _VocabOptionState.idle ? Colors.transparent : fg.withValues(alpha: 0.4),
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$label. ', style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
          Flexible(child: Text(text, style: TextStyle(color: fg, fontSize: 16), textAlign: TextAlign.center)),
        ]),
      ),
    );
  }
}
