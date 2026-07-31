import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/progress_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../utils/romaji_converter.dart';
import '../utils/learning_constants.dart';
import '../utils/spaced_shuffle.dart';
import '../utils/vocab_answer_validator.dart';
import 'session_summary_screen.dart';
import '../widgets/ruby_text.dart';

// ── Private header widget ──────────────────────────────────────────────────────

class _QuizHeader extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback onBack;

  const _QuizHeader({
    required this.current,
    required this.total,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final progress = current / total.clamp(1, total);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.fg),
              onPressed: onBack,
              splashRadius: 22,
            ),
            const Spacer(),
            Text(
              '$current / $total',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.pillBg,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          minHeight: 3,
        ),
      ],
    );
  }
}

// ── Main screen ────────────────────────────────────────────────────────────────

class VocabPracticeScreen extends ConsumerStatefulWidget {
  final List<VocabWord> words;
  final bool multipleChoice;
  final bool suppressFurigana;
  final bool reverseMode;

  const VocabPracticeScreen({
    super.key,
    required this.words,
    required this.multipleChoice,
    this.suppressFurigana = false,
    this.reverseMode = false,
  });

  @override
  ConsumerState<VocabPracticeScreen> createState() => _VocabPracticeScreenState();
}

class _VocabPracticeScreenState extends ConsumerState<VocabPracticeScreen>
    with SingleTickerProviderStateMixin {
  List<VocabWord> _queue = [];
  int _currentIndex = 0;
  bool _loading = true;
  Set<String> _learnedKanji = {};

  // MC state
  List<String> _options = [];
  String? _selectedOption;

  // Keyboard state
  final _controller = TextEditingController();
  bool _showingFeedback = false;
  bool? _lastCorrect;
  Timer? _autoNextTimer;

  int _correctCount = 0;

  // Practice-mode learning results, keyed by word id (latest wins).
  final Map<int, PracticeResult> _practiceResults = {};
  Future<void>? _lastRecord;

  // Animation
  late AnimationController _promptCtrl;
  late Animation<double> _promptScale;
  late Animation<double> _promptOpacity;

  @override
  void initState() {
    super.initState();
    _promptCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _promptScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _promptCtrl, curve: Curves.easeOutBack),
    );
    _promptOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _promptCtrl, curve: Curves.easeOut),
    );
    _promptCtrl.forward();
    _load();
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _controller.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final learned = await progressRepo.getLearnedKanjiCharacters();
    if (!mounted) return;
    setState(() {
      // Show each word twice; space repeats so the same word is never
      // back-to-back (gap of 3 other questions where the pool allows).
      _queue = spacedShuffle([...widget.words, ...widget.words], (w) => w.id, minGap: 3);
      _learnedKanji = learned;
      _loading = false;
    });
    if (widget.multipleChoice && _queue.isNotEmpty) _buildOptions();
  }

  VocabWord get _current => _queue[_currentIndex];

  Future<void> _buildOptions() async {
    if (widget.reverseMode) {
      final distractors = await vocabRepo.getDistractors(
        jlptLevel: _current.jlptLevel,
        count: 3,
        excludeIds: [_current.id],
      );
      if (!mounted) return;
      final opts = [_current.reading, ...distractors.map((d) => d.reading)]..shuffle();
      setState(() => _options = opts);
    } else {
      final distractors = await vocabRepo.getDistractors(
        jlptLevel: _current.jlptLevel,
        count: 3,
        excludeIds: [_current.id],
      );
      if (!mounted) return;
      final opts = [_current.meanings, ...distractors.map((d) => d.meanings)]..shuffle();
      setState(() => _options = opts);
    }
  }

  bool _isCorrect(String input) {
    if (widget.reverseMode) {
      final converted = RomajiConverter.convert(input.trim().toLowerCase());
      return converted == _current.reading || input.trim() == _current.reading;
    }
    return VocabAnswerValidator.validate(input, _current.acceptableAnswers);
  }

  bool _isOptionCorrect(String option) {
    if (widget.reverseMode) return option == _current.reading;
    return option == _current.meanings;
  }

  void _recordPractice(bool correct) {
    if (ref.read(settingsProvider).learnedVia != 'practice') return;
    final id = _current.id;
    _lastRecord = vocabRepo
        .recordPracticeProgress(id, isCorrect: correct)
        .then((r) => _practiceResults[id] = r);
  }

  void _handleMcSelect(String option) {
    if (_showingFeedback) return;
    final correct = _isOptionCorrect(option);
    if (correct) {
      vocabRepo.incrementPracticeCount(_current.id); // fire-and-forget
      _correctCount++;
    }
    _recordPractice(correct);
    setState(() {
      _selectedOption = option;
      _showingFeedback = true;
      _lastCorrect = correct;
    });
    if (correct) {
      soundService.playCorrect();
    } else {
      soundService.playWrong();
    }
  }

  void _handleKeyboardSubmit() {
    if (_showingFeedback) return;
    final input = _controller.text;
    final correct = _isCorrect(input);
    if (correct) {
      vocabRepo.incrementPracticeCount(_current.id); // fire-and-forget
      _correctCount++;
    }
    _recordPractice(correct);
    setState(() {
      _showingFeedback = true;
      _lastCorrect = correct;
    });
    if (correct) {
      soundService.playCorrect();
    } else {
      soundService.playWrong();
    }
  }

  Future<void> _next() async {
    _autoNextTimer?.cancel();
    if (_currentIndex >= _queue.length - 1) {
      await _lastRecord;
      if (!mounted) return;
      final ids = _queue.map((w) => w.id).toList();
      final counts = await vocabRepo.getPracticeCountsForIds(ids);
      final seen = <int>{};
      final practiceCounts = <({String display, int count})>[];
      final practiceProgress = <({String display, bool learned, int remaining})>[];
      for (final w in _queue) {
        if (seen.add(w.id)) {
          practiceCounts.add((display: w.word, count: counts[w.id] ?? 0));
          final r = _practiceResults[w.id];
          if (r != null) {
            practiceProgress.add((
              display: w.word,
              learned: r.learned,
              remaining: (kPracticePointsToLearn - r.points).clamp(0, kPracticePointsToLearn),
            ));
          }
        }
      }
      practiceCounts.sort((a, b) => b.count.compareTo(a.count));
      practiceProgress.sort((a, b) => (a.learned ? 0 : a.remaining).compareTo(b.learned ? 0 : b.remaining));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        AppRoute.to(SessionSummaryScreen(
          correct: _correctCount,
          total: _queue.length,
          learnedChars: const [],
          practiceCounts: practiceCounts,
          practiceProgress: practiceProgress,
        )),
      );
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _showingFeedback = false;
      _lastCorrect = null;
      _controller.clear();
    });
    _promptCtrl.forward(from: 0);
    if (widget.multipleChoice) _buildOptions();
  }

  Widget _buildPrompt(VocabWord word) {
    if (widget.reverseMode) {
      return Text(
        word.meanings,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AppColors.fg,
        ),
        textAlign: TextAlign.center,
      );
    } else {
      if (word.word == word.reading || word.isUsuallyKana) {
        // Kana-only or usually-written-in-kana word
        return Text(
          word.reading,
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w600,
            color: AppColors.fg,
            fontFamily: AppFonts.japaneseFont,
            fontFamilyFallback: AppFonts.japaneseFallback,
          ),
          textAlign: TextAlign.center,
        );
      } else {
        // Has kanji — when toggle OFF: full reading above, no inline furigana.
        // When toggle ON: no reading above, inline furigana only for unlearned chars.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.suppressFurigana)
              Text(
                word.reading,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  fontFamily: AppFonts.japaneseFont,
                  fontFamilyFallback: AppFonts.japaneseFallback,
                ),
              ),
            RubyText(
              '{${word.word}|${word.reading}}',
              fontSize: 80,
              color: AppColors.fg,
              showFurigana: widget.suppressFurigana,
              suppressedKanji: widget.suppressFurigana ? _learnedKanji : null,
              centered: true,
            ),
          ],
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vocabulary Practice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vocabulary Practice')),
        body: Center(
          child: Text(
            'No words to practice.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    final word = _current;
    final hintText = widget.reverseMode
        ? 'Type Japanese reading...'
        : 'Type English meaning...';
    final correctAnswer = widget.reverseMode ? word.reading : word.meanings;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _QuizHeader(
              current: _currentIndex + 1,
              total: _queue.length,
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 4),
            // Prompt area
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FadeTransition(
                    opacity: _promptOpacity,
                    child: ScaleTransition(
                      scale: _promptScale,
                      child: _buildPrompt(word),
                    ),
                  ),
                ),
              ),
            ),
            // Feedback banner
            if (_showingFeedback && _lastCorrect != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _lastCorrect!
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppColors.containerRadius),
                      border: Border.all(
                        color: _lastCorrect! ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        _lastCorrect! ? Icons.check_circle : Icons.cancel,
                        color: _lastCorrect! ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastCorrect!
                              ? 'Correct!'
                              : 'Incorrect — $correctAnswer',
                          style: TextStyle(
                            color: _lastCorrect! ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap anywhere to continue',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ]),
              ),
            // Options / keyboard
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: widget.multipleChoice
                  ? _buildMcOptions()
                  : _buildKeyboard(hintText),
            ),
          ]),
          // Early-advance overlay (no text)
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

  Widget _buildMcOptions() {
    if (_options.isEmpty) return const CircularProgressIndicator();
    return Column(
      children: _options.map((opt) {
        final isSelected = _selectedOption == opt;
        final isCorrectOpt = _isOptionCorrect(opt);

        // Determine button state
        Color bgColor;
        Color textColor;
        Color borderColor;
        double textOpacity;
        Widget? trailingIcon;
        List<BoxShadow> shadows;

        if (_showingFeedback) {
          if (isSelected && isCorrectOpt) {
            bgColor = AppColors.correctBg;
            textColor = Colors.white;
            borderColor = Colors.transparent;
            textOpacity = 1.0;
            trailingIcon = const Icon(Icons.check, color: Colors.white, size: 18);
            shadows = [];
          } else if (isSelected && !isCorrectOpt) {
            bgColor = AppColors.incorrectBg;
            textColor = Colors.white;
            borderColor = Colors.transparent;
            textOpacity = 1.0;
            trailingIcon = null;
            shadows = [];
          } else {
            // Dim non-selected options
            bgColor = AppColors.surface;
            textColor = AppColors.fg;
            borderColor = AppColors.pillBg;
            textOpacity = 0.5;
            trailingIcon = null;
            shadows = [];
          }
        } else {
          // Idle state
          bgColor = AppColors.surface;
          textColor = AppColors.fg;
          borderColor = AppColors.pillBg;
          textOpacity = 1.0;
          trailingIcon = null;
          shadows = [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ];
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: _showingFeedback ? null : () => _handleMcSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: shadows,
              ),
              child: Row(children: [
                Expanded(
                  child: Opacity(
                    opacity: textOpacity,
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  trailingIcon,
                ],
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyboard(String hintText) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.accent, width: 2),
    );
    return Column(children: [
      SizedBox(
        height: 56,
        child: TextField(
          controller: _controller,
          enabled: !_showingFeedback,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          textAlign: TextAlign.center,
          inputFormatters: widget.reverseMode ? [RomajiInputFormatter()] : null,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            disabledBorder: border,
          ),
          style: TextStyle(color: AppColors.fg, fontSize: 18),
          onSubmitted: (_) => _handleKeyboardSubmit(),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _showingFeedback ? null : _handleKeyboardSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.zero,
          ),
          child: const Text(
            'Submit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ]);
  }
}
