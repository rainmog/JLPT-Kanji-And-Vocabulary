import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kana_repository.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../utils/learning_constants.dart';
import '../utils/spaced_shuffle.dart';
import '../utils/app_route.dart';
import '../widgets/scale_on_press.dart';
import '../widgets/practice_delta_badge.dart';

enum KanaQuizType {
  kanaToRomajiMC,
  romajiToKanaMC,
  kanaToRomajiType,
  wordToRomajiType,
  hiraToKataMC,
  kataToHiraMC,
}

class _KanaQuestion {
  final KanaCharacter? char;   // null for word questions
  final KanaWord? word;        // null for char questions
  final KanaQuizType type;

  const _KanaQuestion({this.char, this.word, required this.type});
}

class KanaPracticeScreen extends ConsumerStatefulWidget {
  final List<KanaCharacter> chars;
  final List<KanaCharacter> allChars;
  final List<KanaWord> words;
  final KanaQuizType quizType;
  final int count;
  final bool testMode;

  const KanaPracticeScreen({
    super.key,
    required this.chars,
    required this.allChars,
    required this.words,
    required this.quizType,
    required this.count,
    required this.testMode,
  });

  @override
  ConsumerState<KanaPracticeScreen> createState() => _KanaPracticeScreenState();
}

class _KanaPracticeScreenState extends ConsumerState<KanaPracticeScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  List<_KanaQuestion> _queue = [];
  int _currentIndex = 0;
  int _correct = 0;

  List<String> _options = [];
  String? _selectedOption;
  // Practice-mode learning results keyed by char id (latest wins).
  final Map<int, PracticeResult> _practiceResults = {};
  Future<void>? _lastRecord;
  PracticeResult? _lastPractice; // points change for current answer's badge
  bool? _lastCorrect;            // correctness of current answer (badge color)
  final _controller = TextEditingController();
  bool _showingFeedback = false;
  Timer? _autoNextTimer;

  late final AnimationController _promptCtrl;
  late final Animation<double> _promptScale;
  late final Animation<double> _promptOpacity;

  @override
  void initState() {
    super.initState();
    _promptCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _promptScale = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _promptCtrl, curve: Curves.easeOutBack));
    _promptOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _promptCtrl, curve: Curves.easeOut));
    _promptCtrl.forward();
    _buildQueue();
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _controller.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _buildQueue() {
    List<_KanaQuestion> pool;

    if (widget.testMode) {
      // Fixed format: 1 kana→romaji MC + 1 romaji→kana MC per targeted char
      pool = [];
      for (final ch in widget.chars) {
        pool.add(_KanaQuestion(char: ch, type: KanaQuizType.kanaToRomajiMC));
        pool.add(_KanaQuestion(char: ch, type: KanaQuizType.romajiToKanaMC));
      }
      // Space the two copies of each char so the same one is never back-to-back.
      pool = spacedShuffle(pool, _questionKey, minGap: 3, rng: _rng);
    } else {
      final qt = widget.quizType;
      final isWord = qt == KanaQuizType.wordToRomajiType;
      final isHiraKata =
          qt == KanaQuizType.hiraToKataMC || qt == KanaQuizType.kataToHiraMC;

      if (isWord) {
        pool = widget.words.map((w) => _KanaQuestion(word: w, type: qt)).toList();
      } else if (isHiraKata) {
        final source = widget.allChars
            .where((c) => c.type == 'hiragana' && c.counterpart != null)
            .toList();
        pool = source
            .map((c) => _KanaQuestion(
                  char: c,
                  type: _rng.nextBool()
                      ? KanaQuizType.hiraToKataMC
                      : KanaQuizType.kataToHiraMC,
                ))
            .toList();
      } else {
        pool =
            widget.chars.map((c) => _KanaQuestion(char: c, type: qt)).toList();
      }

      pool.shuffle(_rng);
      pool = pool.take(widget.count).toList();
    }

    _queue = pool;
    if (_queue.isEmpty) return;
    _prepareQuestion();
    setState(() {});
  }

  Object _questionKey(_KanaQuestion q) =>
      q.char?.id ?? (q.word != null ? 'w${q.word!.id}' : identityHashCode(q));

  _KanaQuestion get _current => _queue[_currentIndex];

  void _prepareQuestion() {
    final q = _current;
    if (_isMC(q.type)) _buildOptions(q);
  }

  bool _isMC(KanaQuizType t) =>
      t == KanaQuizType.kanaToRomajiMC ||
      t == KanaQuizType.romajiToKanaMC ||
      t == KanaQuizType.hiraToKataMC ||
      t == KanaQuizType.kataToHiraMC;

  void _buildOptions(_KanaQuestion q) {
    final correct = _correctAnswer(q);
    final pool = _distractorPool(q);
    pool.shuffle(_rng);
    final distractors = pool.where((d) => d != correct).take(3).toList();
    final opts = [correct, ...distractors]..shuffle(_rng);
    setState(() => _options = opts);
  }

  String _correctAnswer(_KanaQuestion q) {
    switch (q.type) {
      case KanaQuizType.kanaToRomajiMC:
      case KanaQuizType.kanaToRomajiType:
      case KanaQuizType.wordToRomajiType:
        return q.char?.romaji ?? q.word?.romaji ?? '';
      case KanaQuizType.romajiToKanaMC:
        return q.char!.character;
      case KanaQuizType.hiraToKataMC:
        return q.char!.counterpart!; // show hiragana → pick katakana
      case KanaQuizType.kataToHiraMC:
        return q.char!.character; // show katakana counterpart → pick hiragana
    }
  }

  List<String> _distractorPool(_KanaQuestion q) {
    switch (q.type) {
      case KanaQuizType.kanaToRomajiMC:
        // Prefer same row, else all
        final sameRow = widget.allChars
            .where((c) =>
                c.type == q.char!.type &&
                c.id != q.char!.id &&
                c.row == q.char!.row)
            .map((c) => c.romaji)
            .toList();
        if (sameRow.length >= 3) return sameRow;
        return widget.allChars
            .where((c) => c.type == q.char!.type && c.id != q.char!.id)
            .map((c) => c.romaji)
            .toSet()
            .toList();
      case KanaQuizType.romajiToKanaMC:
        final sameRow = widget.allChars
            .where((c) =>
                c.type == q.char!.type &&
                c.id != q.char!.id &&
                c.row == q.char!.row)
            .map((c) => c.character)
            .toList();
        if (sameRow.length >= 3) return sameRow;
        return widget.allChars
            .where((c) => c.type == q.char!.type && c.id != q.char!.id)
            .map((c) => c.character)
            .toList();
      case KanaQuizType.hiraToKataMC:
        // Show hiragana → pick correct katakana; distractors = other katakana
        return widget.allChars
            .where((c) =>
                c.type == 'katakana' &&
                c.counterpart != q.char!.character &&
                c.counterpart != null)
            .map((c) => c.character)
            .toList();
      case KanaQuizType.kataToHiraMC:
        // Show katakana → pick correct hiragana; distractors = other hiragana
        return widget.allChars
            .where((c) => c.type == 'hiragana' && c.id != q.char!.id)
            .map((c) => c.character)
            .toList();
      default:
        return [];
    }
  }

  String _prompt(_KanaQuestion q) {
    switch (q.type) {
      case KanaQuizType.kanaToRomajiMC:
      case KanaQuizType.kanaToRomajiType:
        return q.char!.character;
      case KanaQuizType.romajiToKanaMC:
        return q.char!.romaji;
      case KanaQuizType.wordToRomajiType:
        return q.word!.word;
      case KanaQuizType.hiraToKataMC:
        return q.char!.character; // show hiragana
      case KanaQuizType.kataToHiraMC:
        return q.char!.counterpart!; // show katakana
    }
  }

  String _promptLabel(_KanaQuestion q) {
    switch (q.type) {
      case KanaQuizType.kanaToRomajiMC:
        return 'Select the romaji';
      case KanaQuizType.romajiToKanaMC:
        return 'Select the ${q.char!.type}';
      case KanaQuizType.kanaToRomajiType:
        return 'Type the romaji';
      case KanaQuizType.wordToRomajiType:
        return 'Type the romaji reading';
      case KanaQuizType.hiraToKataMC:
        return 'Select the katakana';
      case KanaQuizType.kataToHiraMC:
        return 'Select the hiragana';
    }
  }

  bool _checkTyped(String input) {
    final q = _current;
    final norm = input.trim().toLowerCase();
    final acceptable =
        q.char?.acceptableRomaji ?? q.word?.acceptableRomaji ?? [];
    return acceptable.any((a) => a.toLowerCase() == norm);
  }

  bool _checkMC(String option) => option == _correctAnswer(_current);

  void _handleMcSelect(String option) {
    if (_showingFeedback) return;
    final correct = _checkMC(option);
    setState(() {
      _selectedOption = option;
      _showingFeedback = true;
    });
    _onResult(correct);
  }

  void _handleTypeSubmit() {
    if (_showingFeedback) return;
    final correct = _checkTyped(_controller.text);
    setState(() {
      _showingFeedback = true;
    });
    _onResult(correct);
  }

  void _onResult(bool correct) {
    _lastCorrect = correct;
    _lastPractice = null;
    if (correct) {
      soundService.playCorrect();
      _correct++;
    } else {
      soundService.playWrong();
    }
    if (widget.testMode && _current.char != null) {
      kanaRepo.recordResult(_current.char!.id, correct);
    }
    if (!widget.testMode && correct && _current.char != null) {
      kanaRepo.incrementPracticeCount(_current.char!.id); // fire-and-forget
    }
    if (!widget.testMode &&
        _current.char != null &&
        ref.read(settingsProvider).learnedVia == 'practice') {
      final id = _current.char!.id;
      _lastRecord = kanaRepo
          .recordPracticeProgress(id, isCorrect: correct)
          .then((r) {
        _practiceResults[id] = r;
        if (mounted) setState(() => _lastPractice = r);
      });
    }
  }

  void _next() {
    _autoNextTimer?.cancel();
    if (_currentIndex >= _queue.length - 1) {
      if (mounted) _showResults();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _showingFeedback = false;
      _lastPractice = null;
      _lastCorrect = null;
      _controller.clear();
    });
    _prepareQuestion();
    _promptCtrl.forward(from: 0);
  }

  Future<void> _showResults() async {
    final total = _queue.length;

    // Collect unique char IDs from queue
    final seen = <int>{};
    final charItems = <({String display, int id})>[];
    for (final q in _queue) {
      if (q.char != null && seen.add(q.char!.id)) {
        charItems.add((display: q.char!.character, id: q.char!.id));
      }
    }

    await _lastRecord;

    List<({String display, int count})> practiceCounts = const [];
    if (!widget.testMode && charItems.isNotEmpty) {
      final ids = charItems.map((c) => c.id).toList();
      final counts = await kanaRepo.getPracticeCountsForIds(ids);
      final list = charItems.map((c) => (display: c.display, count: counts[c.id] ?? 0)).toList();
      list.sort((a, b) => b.count.compareTo(a.count));
      practiceCounts = list;
    }

    List<({String display, bool learned, int percent})> practiceProgress = const [];
    if (!widget.testMode && _practiceResults.isNotEmpty) {
      final list = <({String display, bool learned, int percent})>[];
      for (final c in charItems) {
        final r = _practiceResults[c.id];
        if (r == null) continue;
        list.add((
          display: c.display,
          learned: r.learned,
          percent: practicePointsPercent(r.points),
        ));
      }
      list.sort((a, b) => (b.learned ? 100 : b.percent).compareTo(a.learned ? 100 : a.percent));
      practiceProgress = list;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      AppRoute.to(_KanaResultScreen(
        correct: _correct,
        total: total,
        testMode: widget.testMode,
        practiceCounts: practiceCounts,
        practiceProgress: practiceProgress,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(children: [
            _QuizHeader(
              progress: '0 / 0',
              onBack: () => Navigator.pop(context),
              current: 0,
              total: 1,
            ),
            Expanded(
              child: Center(
                child: Text('Nothing to practice.',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ),
          ]),
        ),
      );
    }

    final q = _current;
    final isMC = _isMC(q.type);
    final promptText = _prompt(q);
    final promptLabel = _promptLabel(q);
    final correctAnswer = _correctAnswer(q);
    final isLargePrompt = q.type != KanaQuizType.romajiToKanaMC &&
        q.type != KanaQuizType.wordToRomajiType;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _QuizHeader(
              progress: '${_currentIndex + 1} / ${_queue.length}',
              onBack: () => Navigator.pop(context),
              current: _currentIndex + 1,
              total: _queue.length,
            ),
            // Prompt label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                promptLabel,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ),
            // Big prompt with entrance animation
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _promptOpacity,
                  child: ScaleTransition(
                    scale: _promptScale,
                    child: Text(
                      promptText,
                      key: ValueKey(_currentIndex),
                      style: TextStyle(
                        fontSize: isLargePrompt ? 96 : 38,
                        fontWeight: FontWeight.w600,
                        color: AppColors.fg,
                        fontFamily: isLargePrompt ? 'NotoSerifCJKjp' : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            // Options or type input
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: isMC
                  ? _buildMcOptions(correctAnswer)
                  : _buildTypeInput(),
            ),
          ]),
          // Practice-mode progress delta badge (top-right, inconspicuous)
          if (_showingFeedback && _lastCorrect != null && _lastPractice != null)
            Positioned(
              top: 60, right: 20,
              child: PracticeDeltaBadge(
                result: _lastPractice!,
                color: _lastCorrect! ? AppColors.correct : AppColors.incorrect,
              ),
            ),
          // Tap-to-advance overlay (invisible, early-advance mechanism)
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

  Widget _buildMcOptions(String correctAnswer) {
    if (_options.isEmpty) return const SizedBox(height: 200);
    final isKanaOpt = _current.type == KanaQuizType.romajiToKanaMC ||
        _current.type == KanaQuizType.hiraToKataMC ||
        _current.type == KanaQuizType.kataToHiraMC;
    return Column(
      children: _options.map((opt) {
        String state;
        if (!_showingFeedback) {
          state = 'idle';
        } else if (opt == correctAnswer) {
          state = 'correct';
        } else if (opt == _selectedOption) {
          state = 'wrong';
        } else {
          state = 'dim';
        }

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
          case 'dim':
            bg = AppColors.surface;
            textColor = AppColors.muted.withValues(alpha: 0.5);
            borderColor = AppColors.pillBg.withValues(alpha: 0.5);
            break;
          default: // idle
            bg = AppColors.surface;
            textColor = AppColors.fg;
            borderColor = AppColors.pillBg;
            shadow = [
              BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ];
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: _showingFeedback ? null : () => _handleMcSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: shadow,
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      opt,
                      style: TextStyle(
                        fontSize: isKanaOpt ? 20 : 15.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        fontFamily: isKanaOpt ? 'NotoSerifCJKjp' : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (state == 'correct') ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check, size: 15, color: Colors.white),
                    ],
                  ]),
            ),
          ),
        );
      }).toList()
        ..add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AnimatedOpacity(
              opacity: _showingFeedback ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Text(
                'Tap anywhere to continue',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildTypeInput() {
    return Column(children: [
      TextField(
        controller: _controller,
        enabled: !_showingFeedback,
        autofocus: true,
        textCapitalization: TextCapitalization.none,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'Type romaji...',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.accent, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.accent, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.accent, width: 2),
          ),
        ),
        style: TextStyle(
            color: AppColors.fg,
            fontSize: 18),
        onSubmitted: (_) => _handleTypeSubmit(),
      ),
      const SizedBox(height: 12),
      ScaleOnPress(
        child: GestureDetector(
          onTap: _showingFeedback ? null : _handleTypeSubmit,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Submit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _QuizHeader extends StatelessWidget {
  final String progress; // "X / Y"
  final VoidCallback onBack;
  final int current;
  final int total;

  const _QuizHeader({
    required this.progress,
    required this.onBack,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.pillBg),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back_ios_new,
                  size: 18, color: AppColors.fg),
            ),
          ),
          const Spacer(),
          Text(progress,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: total > 0 ? current / total.toDouble() : 0,
            minHeight: 5,
            backgroundColor: AppColors.pillBg,
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
      ]),
    );
  }
}

class _KanaResultScreen extends StatelessWidget {
  final int correct;
  final int total;
  final bool testMode;
  final List<({String display, int count})> practiceCounts;
  final List<({String display, bool learned, int percent})> practiceProgress;

  const _KanaResultScreen({
    required this.correct,
    required this.total,
    required this.testMode,
    this.practiceCounts = const [],
    this.practiceProgress = const [],
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (correct / total * 100).round() : 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 68,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'correct',
                        style: TextStyle(fontSize: 18, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$correct / $total correct',
                        style:
                            TextStyle(fontSize: 16, color: AppColors.muted),
                      ),
                      if (testMode) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Characters answered correctly 3× in a row are now marked learned.',
                          style:
                              TextStyle(fontSize: 13, color: AppColors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (practiceProgress.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Builder(builder: (_) {
                          final newlyLearned =
                              practiceProgress.where((p) => p.learned).length;
                          return Text(
                            newlyLearned > 0
                                ? '$newlyLearned reached Learned!'
                                : 'Learning progress',
                            style: TextStyle(
                              color: newlyLearned > 0 ? AppColors.correct : AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: AppColors.pillBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: practiceProgress.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item.display, style: TextStyle(
                                      fontSize: 20, color: AppColors.kanjiColor,
                                      fontFamily: AppFonts.japaneseFont,
                                      fontFamilyFallback: AppFonts.japaneseFallback,
                                    )),
                                    if (item.learned)
                                      Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.check_circle, size: 16, color: AppColors.correct),
                                        const SizedBox(width: 4),
                                        Text('Learned', style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.correct,
                                        )),
                                      ])
                                    else
                                      Text('${item.percent}%', style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted,
                                      )),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ],
                      if (practiceCounts.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Practice Identifications',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: AppColors.pillBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: practiceCounts.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item.display, style: TextStyle(
                                      fontSize: 20, color: AppColors.kanjiColor,
                                      fontFamily: AppFonts.japaneseFont,
                                      fontFamilyFallback: AppFonts.japaneseFallback,
                                    )),
                                    Text('${item.count}×', style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted,
                                    )),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ],
                    ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
