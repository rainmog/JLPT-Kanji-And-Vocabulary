import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz_models.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/sentence_repository.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import 'test_result_screen.dart';
import '../utils/app_route.dart';

class TestSessionScreen extends ConsumerStatefulWidget {
  final List<Kanji> allTargets;
  final bool forceFurigana;
  const TestSessionScreen({super.key, required this.allTargets, this.forceFurigana = false});

  @override
  ConsumerState<TestSessionScreen> createState() => _TestSessionScreenState();
}

class _TestSessionScreenState extends ConsumerState<TestSessionScreen> {
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  String? _selectedOption;
  bool _showingFeedback = false;
  bool? _lastCorrect;
  String _lastCorrectAnswer = '';
  String _lastEnglishMeaning = '';

  // Per-kanji tracking: character → (correct, total)
  final Map<String, (int, int)> _kanjiScores = {};
  // The 10 kanji actually being tested (≤10 randomly selected from allTargets)
  late List<Kanji> _testedKanji;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final targets = [...widget.allTargets]..shuffle();
    _testedKanji = targets.take(10).toList();

    for (final k in _testedKanji) {
      _kanjiScores[k.character] = (0, 0);
    }

    final repo = SentenceRepository(dbService: dbService);
    final questions = await repo.buildMixedTestQuestions(targetKanji: _testedKanji);

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _loading = false;
    });
    soundService.playTestStart();
  }

  QuizQuestion get _current => _questions[_currentIndex];

  String _correctReading(QuizQuestion q) {
    if (q is KanjiQuestion) return q.correctReading;
    if (q is WordQuestion) return q.correctReading;
    return '';
  }

  List<String> _mcOptions(QuizQuestion q) {
    if (q is KanjiQuestion) return q.readingOptions;
    if (q is WordQuestion) return q.mcOptions;
    return [];
  }

  void _handleSelect(String option) {
    if (_showingFeedback) return;
    final q = _current;
    final isCorrect = option == _correctReading(q);
    final char = q.character;
    final (correct, total) = _kanjiScores[char] ?? (0, 0);
    _kanjiScores[char] = (correct + (isCorrect ? 1 : 0), total + 1);

    setState(() {
      _selectedOption = option;
      _showingFeedback = true;
      _lastCorrect = isCorrect;
      _lastCorrectAnswer = _correctReading(q);
      _lastEnglishMeaning = q.meaning;
    });

    if (isCorrect) {
      soundService.playCorrect();
    } else {
      soundService.playWrong();
    }
  }

  void _handleNext() {
    if (_currentIndex >= _questions.length - 1) {
      Navigator.pushReplacement(context, AppRoute.to(TestResultScreen(
        testedKanji: _testedKanji,
        kanjiScores: _kanjiScores,
      )));
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _showingFeedback = false;
      _lastCorrect = null;
      _lastCorrectAnswer = '';
      _lastEnglishMeaning = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test')),
        body: const Center(child: Text('Not enough questions found for selected kanji.')),
      );
    }

    final q = _current;
    final total = _questions.length;
    final progress = (_currentIndex + 1) / total;
    final options = _mcOptions(q);

    return Scaffold(
      appBar: AppBar(title: Text('${_currentIndex + 1} / $total')),
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.containerRadius),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.pillBg,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: _buildQuestionCard(q),
                    ),
                  ),
                ),
                Divider(thickness: 1, color: AppColors.pillBg),
                const SizedBox(height: 8),
                for (int i = 0; i < options.length; i++) ...[
                  _TestOptionButton(
                    label: '${i + 1}',
                    text: options[i],
                    state: !_showingFeedback
                        ? _TestOptionState.idle
                        : (options[i] == _correctReading(q))
                            ? _TestOptionState.correct
                            : (_selectedOption == options[i])
                                ? _TestOptionState.wrong
                                : _TestOptionState.idle,
                    onTap: () => _handleSelect(options[i]),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_showingFeedback) ...[
                  Text(
                    _lastEnglishMeaning,
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text('Tap anywhere to continue',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (_showingFeedback)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleNext,
            ),
          ),
      ]),
    );
  }

  Widget _buildQuestionCard(QuizQuestion q) {
    if (q is KanjiQuestion) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(q.character, style: TextStyle(fontSize: 72, color: AppColors.kanjiColor), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('On/Kun Reading', style: TextStyle(fontSize: 13, color: AppColors.muted), textAlign: TextAlign.center),
        ],
      );
    } else if (q is WordQuestion) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(q.word, style: TextStyle(fontSize: 56, color: AppColors.kanjiColor), textAlign: TextAlign.center),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

enum _TestOptionState { idle, correct, wrong }

class _TestOptionButton extends StatelessWidget {
  final String label;
  final String text;
  final _TestOptionState state;
  final VoidCallback onTap;
  const _TestOptionButton({required this.label, required this.text,
      required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = switch (state) {
      _TestOptionState.correct => AppColors.correctBg,
      _TestOptionState.wrong => AppColors.incorrectBg,
      _TestOptionState.idle => AppColors.btnBg,
    };
    final fg = switch (state) {
      _TestOptionState.correct => AppColors.correct,
      _TestOptionState.wrong => AppColors.incorrect,
      _TestOptionState.idle => AppColors.fg,
    };
    return GestureDetector(
      onTap: state == _TestOptionState.idle ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          border: Border.all(
            color: state == _TestOptionState.idle ? Colors.transparent : fg.withValues(alpha: 0.4),
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
