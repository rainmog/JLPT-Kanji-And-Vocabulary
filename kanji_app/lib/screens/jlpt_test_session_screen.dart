import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/jlpt_repository.dart';
import '../repositories/kanji_repository.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../widgets/ruby_text.dart';
import 'jlpt_test_result_screen.dart';

Future<Map<String, dynamic>?> loadJlptProgress(int level, {String? section}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _progressKey(level, section);
  final raw = prefs.getString(key);
  if (raw == null) return null;
  return jsonDecode(raw) as Map<String, dynamic>;
}

String _progressKey(int level, String? section) =>
    section == null ? 'jlpt_progress_n$level' : 'jlpt_progress_n${level}_$section';

class JlptTestSessionScreen extends ConsumerStatefulWidget {
  final int level;
  final String? section;
  final int? resumeIndex;
  final Map<int, int>? resumeAnswers;
  final List<int>? resumeVocabIds;
  final List<int>? resumeGrammarIds;
  final List<int>? resumeReadingIds;
  const JlptTestSessionScreen({
    super.key,
    required this.level,
    this.section,
    this.resumeIndex,
    this.resumeAnswers,
    this.resumeVocabIds,
    this.resumeGrammarIds,
    this.resumeReadingIds,
  });

  @override
  ConsumerState<JlptTestSessionScreen> createState() => _JlptTestSessionScreenState();
}

class _JlptTestSessionScreenState extends ConsumerState<JlptTestSessionScreen> {
  JlptTestSession? _session;
  int _currentIndex = 0;
  final Map<int, int> _answers = {};
  bool _loading = true;
  Timer? _autoNextTimer;
  Set<String> _suppressedKanji = {};

  @override
  void initState() {
    super.initState();
    if (widget.resumeAnswers != null) _answers.addAll(widget.resumeAnswers!);
    if (widget.resumeIndex != null) _currentIndex = widget.resumeIndex!;
    _load();
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final sessionFuture = (widget.resumeVocabIds != null)
        ? jlptRepo.buildSessionFromIds(
            widget.level,
            vocabIds: widget.resumeVocabIds!,
            grammarIds: widget.resumeGrammarIds ?? [],
            readingIds: widget.resumeReadingIds ?? [],
          )
        : jlptRepo.buildSession(widget.level, section: widget.section);

    final results = await Future.wait([
      sessionFuture,
      kanjiRepo.getKanjiCharsAtOrBelowLevel(widget.level),
    ]);
    if (mounted) {
      setState(() {
        _session = results[0] as JlptTestSession;
        _suppressedKanji = results[1] as Set<String>;
        _loading = false;
      });
      soundService.playTestStart();
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final session = _session;
    await prefs.setString(_progressKey(widget.level, widget.section), jsonEncode({
      'index': _currentIndex,
      'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
      if (session != null) ...{
        'vocabIds': session.vocabulary.map((q) => q.id).toList(),
        'grammarIds': session.grammar.map((q) => q.id).toList(),
        'readingIds': session.reading.map((q) => q.id).toList(),
      },
    }));
  }

  Future<void> _clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey(widget.level, widget.section));
  }

  List<JlptQuestion> get _questions => _session?.allQuestions ?? [];
  JlptQuestion get _current => _questions[_currentIndex];
  bool get _isLast => _currentIndex >= _questions.length - 1;
  bool get _answered => _answers.containsKey(_current.id);

  String _sectionLabel(String section) => switch (section) {
    'vocabulary' => 'Vocabulary',
    'grammar' => 'Grammar',
    'reading' => 'Reading',
    _ => section,
  };

  void _answer(int option) {
    if (_answered) return;
    setState(() => _answers[_current.id] = option);
    if (option == _current.correctOption) {
      soundService.playCorrect();
      final delay = ref.read(settingsProvider).autoNextDelaySeconds;
      _autoNextTimer?.cancel();
      _autoNextTimer = Timer(Duration(seconds: delay), () {
        if (mounted) _next();
      });
    } else {
      soundService.playWrong();
    }
  }

  void _handleScreenTap() {
    if (!_answered) return;
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
    _next();
  }

  void _next() {
    if (_isLast) {
      _clearProgress();
      Navigator.pushReplacement(
        context,
        AppRoute.to(JlptTestResultScreen(session: _session!, answers: _answers)),
      );
      return;
    }
    setState(() => _currentIndex++);
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Exit test?', style: TextStyle(color: AppColors.fg)),
        content: Text('Save your progress to resume later?',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Cancel', style: TextStyle(color: AppColors.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text('Save & Exit', style: TextStyle(color: AppColors.accent))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'exit'),
              child: Text('Exit', style: TextStyle(color: AppColors.incorrect))),
        ],
      ),
    );
    if (result == 'save') {
      await _saveProgress();
      return true;
    }
    if (result == 'exit') {
      await _clearProgress();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final q = _current;
    final section = _session!.vocabulary.contains(q) ? 'vocabulary'
        : _session!.grammar.contains(q) ? 'grammar' : 'reading';
    final sectionList = switch (section) {
      'vocabulary' => _session!.vocabulary,
      'grammar' => _session!.grammar,
      _ => _session!.reading,
    };
    final sectionQ = sectionList.indexOf(q) + 1;
    final sectionTotal = sectionList.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final should = await _onWillPop();
          if (should && context.mounted) {
            soundService.playGoBack();
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          title: Text(
            '${_sectionLabel(section)} · $sectionQ / $sectionTotal',
            style: TextStyle(color: AppColors.fg, fontSize: 16),
          ),
          iconTheme: IconThemeData(color: AppColors.fg),
        ),
        body: Stack(children: [
          SafeArea(
            child: Column(children: [
              Expanded(
                child: q.passage != null
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppColors.containerRadius),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (q.passageTitle != null) ...[
                                    Text(q.displayPassageTitle,
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                                            color: AppColors.muted)),
                                    const SizedBox(height: 8),
                                  ],
                                  RubyText(q.displayPassage, fontSize: 17, height: 1.7,
                                      suppressedKanji: _suppressedKanji),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.btnBg,
                                borderRadius: BorderRadius.circular(AppColors.containerRadius),
                              ),
                              child: RubyText(
                                q.displayQuestionStem,
                                fontSize: 20,
                                height: 1.6,
                                showFurigana: q.questionType != 'kanji_reading',
                                suppressedKanji: _suppressedKanji,
                                centered: false,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.btnBg,
                                  borderRadius: BorderRadius.circular(AppColors.containerRadius),
                                ),
                                child: RubyText(
                                  q.displayQuestionStem,
                                  fontSize: 18,
                                  height: 1.6,
                                  showFurigana: q.questionType != 'kanji_reading',
                                  suppressedKanji: _suppressedKanji,
                                  centered: true,
                                ),
                              ),
                              if (q.questionType == 'sentence_reorder' ||
                                  q.questionType == 'paragraph_reorder') ...[
                                const SizedBox(height: 16),
                                _SentenceReorderWidget(
                                  key: ValueKey(q.id),
                                  q: q,
                                  onAnswer: _answer,
                                  answered: _answered,
                                  givenAnswer: _answers[q.id],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
              if (q.questionType != 'sentence_reorder' && q.questionType != 'paragraph_reorder') ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < 4; i++) ...[
                        _OptionButton(
                          label: '${i + 1}',
                          text: q.displayOption(i),
                          state: !_answered
                              ? _OptionState.idle
                              : (i + 1 == q.correctOption)
                                  ? _OptionState.correct
                                  : (_answers[q.id] == i + 1)
                                      ? _OptionState.wrong
                                      : _OptionState.idle,
                          onTap: () => _answer(i + 1),
                          showFurigana: q.questionType != 'kanji_reading',
                          suppressedKanji: _suppressedKanji,
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        height: 36,
                        child: _answered
                            ? Center(
                                child: Text('Tap anywhere to continue',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ]),
          ),
          if (_answered)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleScreenTap,
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Sentence Reorder Widget ────────────────────────────────────────────────────

class _SentenceReorderWidget extends StatefulWidget {
  final JlptQuestion q;
  final void Function(int option) onAnswer;
  final bool answered;
  final int? givenAnswer;

  const _SentenceReorderWidget({
    super.key,
    required this.q,
    required this.onAnswer,
    required this.answered,
    this.givenAnswer,
  });

  @override
  State<_SentenceReorderWidget> createState() => _SentenceReorderWidgetState();
}

class _SentenceReorderWidgetState extends State<_SentenceReorderWidget> {
  late List<int?> _slots;

  int get _slotCount => widget.q.correctSlots.length.clamp(4, 5);

  @override
  void initState() {
    super.initState();
    if (widget.answered) {
      _slots = widget.q.correctSlots;
    } else {
      _slots = List.filled(_slotCount, null);
    }
  }

  List<int> get _usedOptions =>
      _slots.whereType<int>().toList();

  bool get _allFilled => _slots.every((s) => s != null);

  void _tapChip(int option) {
    final emptyIndex = _slots.indexWhere((s) => s == null);
    if (emptyIndex == -1) return;
    setState(() => _slots[emptyIndex] = option);
  }

  void _tapSlot(int slotIndex) {
    if (_slots[slotIndex] == null) return;
    setState(() => _slots[slotIndex] = null);
  }

  void _check() {
    final starIdx = widget.q.starSlotIndex;
    final optionAtStar = _slots[starIdx];
    if (optionAtStar == null) return;
    widget.onAnswer(optionAtStar);
    setState(() {}); // trigger rebuild to show result
  }

  @override
  Widget build(BuildContext context) {
    final starIdx = widget.q.starSlotIndex;
    final slots = widget.answered ? widget.q.correctSlots : _slots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Slot row
        Row(children: [
          for (int i = 0; i < _slotCount; i++) ...[
            Expanded(
              child: GestureDetector(
                onTap: !widget.answered ? () => _tapSlot(i) : null,
                child: _SlotBox(
                  slotIndex: i,
                  text: slots[i] != null
                      ? widget.q.options[slots[i]! - 1]
                      : null,
                  isStar: i == starIdx,
                  isCorrect: widget.answered &&
                      i == starIdx &&
                      slots[i] == widget.q.correctOption,
                  isWrong: widget.answered &&
                      i == starIdx &&
                      slots[i] != widget.q.correctOption,
                ),
              ),
            ),
            if (i < _slotCount - 1) const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 14),
        // Chip pool — hidden once answered
        if (!widget.answered) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 1; i <= widget.q.options.length; i++)
                if (!_usedOptions.contains(i))
                  _Chip(
                    text: widget.q.options[i - 1],
                    onTap: () => _tapChip(i),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          if (_allFilled)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                ),
              ),
              onPressed: _check,
              child: const Text('Check', style: TextStyle(fontSize: 18)),
            ),
        ],
        // Post-answer: show correct arrangement label + tap hint
        if (widget.answered) ...[
          const SizedBox(height: 8),
          Text(
            'Correct order shown above',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap anywhere to continue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _SlotBox extends StatelessWidget {
  final int slotIndex;
  final String? text;
  final bool isStar;
  final bool isCorrect;
  final bool isWrong;
  const _SlotBox({
    required this.slotIndex,
    this.text,
    required this.isStar,
    required this.isCorrect,
    required this.isWrong,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isCorrect
        ? AppColors.correctBg
        : isWrong
            ? AppColors.incorrectBg
            : AppColors.btnBg;
    final borderColor = isCorrect
        ? AppColors.correct.withValues(alpha: 0.5)
        : isWrong
            ? AppColors.incorrect.withValues(alpha: 0.5)
            : isStar
                ? AppColors.accent
                : Colors.transparent;
    final textColor = isCorrect
        ? AppColors.correct
        : isWrong
            ? AppColors.incorrect
            : AppColors.fg;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        border: Border.all(color: borderColor, width: isStar ? 2 : 1),
      ),
      child: Center(
        child: text != null
            ? Text(text!,
                style: TextStyle(fontSize: 15, color: textColor,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center)
            : Text(
                isStar ? '★' : '${slotIndex + 1}',
                style: TextStyle(
                    fontSize: isStar ? 20 : 16,
                    color: isStar ? AppColors.accent : AppColors.muted),
              ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Chip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 16, color: AppColors.fg,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ── Standard option button ─────────────────────────────────────────────────────

enum _OptionState { idle, correct, wrong }

class _OptionButton extends StatelessWidget {
  final String label;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;
  final bool showFurigana;
  final Set<String>? suppressedKanji;
  const _OptionButton({required this.label, required this.text,
      required this.state, required this.onTap, this.showFurigana = true,
      this.suppressedKanji});

  @override
  Widget build(BuildContext context) {
    final bg = switch (state) {
      _OptionState.correct => AppColors.correctBg,
      _OptionState.wrong => AppColors.incorrectBg,
      _OptionState.idle => AppColors.btnBg,
    };
    final fg = switch (state) {
      _OptionState.correct => AppColors.correct,
      _OptionState.wrong => AppColors.incorrect,
      _OptionState.idle => AppColors.fg,
    };
    return GestureDetector(
      onTap: state == _OptionState.idle ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          border: Border.all(
            color: state == _OptionState.idle
                ? Colors.transparent
                : fg.withValues(alpha: 0.4),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('$label. ', style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
          Expanded(child: RubyText(text, fontSize: 18, color: fg,
              showFurigana: showFurigana, suppressedKanji: suppressedKanji)),
        ]),
      ),
    );
  }
}
