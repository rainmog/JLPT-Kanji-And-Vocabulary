import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/jlpt_repository.dart';
import '../repositories/kanji_repository.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/quiz_header.dart';
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
  Set<String> _suppressedKanji = {};
  JlptQuestion? _reviewingPassage; // non-null → show passage review interstitial

  @override
  void initState() {
    super.initState();
    if (widget.resumeAnswers != null) _answers.addAll(widget.resumeAnswers!);
    if (widget.resumeIndex != null) _currentIndex = widget.resumeIndex!;
    _load();
  }

  @override
  void dispose() {
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
    } else {
      soundService.playWrong();
    }
  }

  void _handleScreenTap() {
    if (!_answered) return;
    final q = _current;
    if (_isLastPassageQuestion(q) && q.passageTranslation != null) {
      setState(() => _reviewingPassage = q);
      return;
    }
    _next();
  }

  // Renders questionTranslation with **bold** markers as actual bold spans.
  Widget _translationText(String text, TextStyle base, {int? maxLines, TextOverflow? overflow}) {
    final parts = text.split(RegExp(r'\*\*'));
    if (parts.length == 1) return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : base,
      ));
    }
    return Text.rich(TextSpan(children: spans), maxLines: maxLines, overflow: overflow);
  }

  bool _isLastPassageQuestion(JlptQuestion q) {
    if (q.passageId == null) return false;
    final idx = _questions.indexOf(q);
    if (idx == _questions.length - 1) return true;
    return _questions[idx + 1].passageId != q.passageId;
  }

  List<JlptQuestion> _passageQuestions(JlptQuestion q) =>
      _questions.where((x) => x.passageId == q.passageId).toList();

  void _showPassageTranslation(JlptQuestion q) {
    final colors = ref.read(themeColorsProvider);
    final passageQs = _passageQuestions(q);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: KDesign.line(colors),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (q.passageTitle != null) ...[
                Text(q.passageTitle!, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: colors.muted)),
                const SizedBox(height: 6),
              ],
              Text('Passage Translation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: KDesign.ink(colors))),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppColors.containerRadius),
                ),
                child: Text(q.passageTranslation ?? '',
                    style: TextStyle(fontSize: 14, height: 1.6,
                        color: KDesign.ink(colors))),
              ),
              const SizedBox(height: 20),
              Text('Correct Answers',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: KDesign.ink(colors))),
              const SizedBox(height: 10),
              for (final pq in passageQs) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppColors.containerRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pq.questionTranslation != null)
                        _translationText(pq.questionTranslation!,
                            TextStyle(fontSize: 13, color: colors.muted)),
                      if (pq.questionTranslation != null) const SizedBox(height: 6),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.correct.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${pq.correctOption}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                  color: colors.correct)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(pq.correctAnswer,
                              style: TextStyle(fontSize: 14, color: KDesign.ink(colors))),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
    final colors = ref.read(themeColorsProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Exit test?', style: TextStyle(color: colors.fg)),
        content: Text('Save your progress to resume later?',
            style: TextStyle(color: colors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Cancel', style: TextStyle(color: colors.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text('Save & Exit', style: TextStyle(color: colors.accent))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'exit'),
              child: Text('Exit', style: TextStyle(color: colors.incorrect))),
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
    final colors = ref.watch(themeColorsProvider);
    if (_loading) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Passage review interstitial — shown after last question of a passage.
    if (_reviewingPassage != null) {
      final rq = _reviewingPassage!;
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
          backgroundColor: colors.bg,
          body: SafeArea(
            child: Column(children: [
              QuizHeader(
                progress: '${_currentIndex + 1} / ${_questions.length}',
                onBack: () async {
                  final should = await _onWillPop();
                  if (should && context.mounted) {
                    soundService.playGoBack();
                    Navigator.pop(context);
                  }
                },
                current: _currentIndex + 1,
                total: _questions.length,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 52,
                        color: colors.correct),
                    const SizedBox(height: 14),
                    Text(
                      rq.passageTitle != null
                          ? 'Passage Complete'
                          : 'Passage Complete',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: KDesign.ink(colors)),
                    ),
                    const SizedBox(height: 36),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: GestureDetector(
                        onTap: () => _showPassageTranslation(rq),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: KDesign.line(colors)),
                            boxShadow: KDesign.shadowSm(colors),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.translate_rounded, size: 18,
                                  color: colors.accent),
                              const SizedBox(width: 10),
                              Text('View translation & answers',
                                  style: TextStyle(color: colors.accent,
                                      fontSize: 15, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: colors.bg,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppColors.buttonRadius),
                            ),
                          ),
                          onPressed: () {
                            setState(() => _reviewingPassage = null);
                            _next();
                          },
                          child: const Text('Continue',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
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
        backgroundColor: colors.bg,
        body: Stack(children: [
          SafeArea(
            child: Column(children: [
              QuizHeader(
                progress: '${_sectionLabel(section)} · $sectionQ / $sectionTotal',
                onBack: () async {
                  final should = await _onWillPop();
                  if (should && context.mounted) {
                    soundService.playGoBack();
                    Navigator.pop(context);
                  }
                },
                current: sectionQ,
                total: sectionTotal,
              ),
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
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(AppColors.containerRadius),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (q.passageTitle != null) ...[
                                    Text(q.displayPassageTitle,
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                                            color: colors.muted)),
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
                              if (q.questionType == 'sentence_reorder') ...[
                                const SizedBox(height: 16),
                                _SentenceReorderWidget(
                                  key: ValueKey(q.id),
                                  q: q,
                                  onAnswer: _answer,
                                  answered: _answered,
                                  givenAnswer: _answers[q.id],
                                ),
                                if (_answered && q.questionTranslation != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(AppColors.containerRadius),
                                      border: Border.all(color: KDesign.line(colors)),
                                    ),
                                    child: _translationText(
                                      q.questionTranslation!,
                                      TextStyle(fontSize: 13, height: 1.5, color: KDesign.ink(colors)),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
              if (q.questionType != 'sentence_reorder') ...[
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
                      // Reserved-height translation area — never displaces buttons.
                      SizedBox(
                        height: 72,
                        child: _answered && q.passage == null &&
                                q.questionTranslation != null
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(
                                      AppColors.containerRadius),
                                  border: Border.all(color: KDesign.line(colors)),
                                ),
                                child: _translationText(
                                  q.questionTranslation!,
                                  TextStyle(fontSize: 13, height: 1.5, color: KDesign.ink(colors)),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(
                        height: 36,
                        child: _answered
                            ? Center(
                                child: Text('Tap anywhere to continue',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: colors.muted)),
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

// Drag payload: which option (1-based) and optionally which slot it came from.
class _DragData {
  final int option;
  final int? fromSlot;
  const _DragData(this.option, {this.fromSlot});
}

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
  List<int?>? _userSlots; // saved on Check; null if never checked this session

  int get _slotCount => widget.q.correctSlots.length.clamp(4, 5);

  @override
  void initState() {
    super.initState();
    _slots = List.filled(_slotCount, null);
  }

  List<int> get _usedOptions => _slots.whereType<int>().toList();
  bool get _allFilled => _slots.every((s) => s != null);

  void _placeInSlot(int slotIndex, _DragData drag) {
    setState(() {
      // Clear source slot if drag started from one
      if (drag.fromSlot != null && drag.fromSlot != slotIndex) {
        final displaced = _slots[slotIndex];
        _slots[drag.fromSlot!] = displaced; // swap displaced back to source
        _slots[slotIndex] = drag.option;
      } else {
        _slots[slotIndex] = drag.option;
      }
    });
  }

  void _returnToPool(_DragData drag) {
    if (drag.fromSlot == null) return;
    setState(() => _slots[drag.fromSlot!] = null);
  }

  void _tapSlot(int slotIndex) {
    if (_slots[slotIndex] == null) return;
    setState(() => _slots[slotIndex] = null);
  }

  void _check() {
    final starIdx = widget.q.starSlotIndex;
    final optionAtStar = _slots[starIdx];
    if (optionAtStar == null) return;
    _userSlots = List.from(_slots);
    widget.onAnswer(optionAtStar);
    setState(() {});
  }

  Widget _buildSlotRow(List<int?> slots, {
    required bool highlightStar,
    bool? starCorrect, // null = no highlight
  }) {
    final starIdx = widget.q.starSlotIndex;
    return Row(children: [
      for (int i = 0; i < _slotCount; i++) ...[
        Expanded(
          child: _SlotBox(
            slotIndex: i,
            text: slots[i] != null ? widget.q.options[slots[i]! - 1] : null,
            isStar: i == starIdx && highlightStar,
            isCorrect: i == starIdx && starCorrect == true,
            isWrong: i == starIdx && starCorrect == false,
          ),
        ),
        if (i < _slotCount - 1) const SizedBox(width: 6),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final starIdx = widget.q.starSlotIndex;

    if (widget.answered) {
      final userSlots = _userSlots;
      final correctSlots = widget.q.correctSlots;
      final isCorrect = widget.givenAnswer == widget.q.correctOption;

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // User's answer (only if we have it from this session)
        if (userSlots != null) ...[
          Text('Your answer',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          _buildSlotRow(userSlots,
            highlightStar: true,
            starCorrect: isCorrect,
          ),
          const SizedBox(height: 12),
        ],
        if (!isCorrect || userSlots != null) ...[
          Text('Correct answer',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.correct),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          _buildSlotRow(correctSlots, highlightStar: false),
          const SizedBox(height: 10),
        ],
        Text('Tap anywhere to continue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      ]);
    }

    // ── Active (not yet answered) ──────────────────────────────────────────────
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Slot row with DragTargets
      Row(children: [
        for (int i = 0; i < _slotCount; i++) ...[
          Expanded(
            child: DragTarget<_DragData>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) => _placeInSlot(i, details.data),
              builder: (ctx, candidates, _) {
                final isHovered = candidates.isNotEmpty;
                final option = _slots[i];
                final text = option != null ? widget.q.options[option - 1] : null;
                return GestureDetector(
                  onTap: () => _tapSlot(i),
                  child: option != null
                      ? Draggable<_DragData>(
                          data: _DragData(option, fromSlot: i),
                          feedback: Material(
                            color: Colors.transparent,
                            child: _SlotBox(
                              slotIndex: i, text: text,
                              isStar: i == starIdx, isCorrect: false, isWrong: false,
                              scale: 1.05,
                            ),
                          ),
                          childWhenDragging: _SlotBox(
                            slotIndex: i, text: null,
                            isStar: i == starIdx, isCorrect: false, isWrong: false,
                            dimmed: true,
                          ),
                          child: _SlotBox(
                            slotIndex: i, text: text,
                            isStar: i == starIdx, isCorrect: false, isWrong: false,
                            hovered: isHovered,
                          ),
                        )
                      : _SlotBox(
                          slotIndex: i, text: null,
                          isStar: i == starIdx, isCorrect: false, isWrong: false,
                          hovered: isHovered,
                        ),
                );
              },
            ),
          ),
          if (i < _slotCount - 1) const SizedBox(width: 6),
        ],
      ]),
      const SizedBox(height: 14),
      // Chip pool — also a DragTarget to receive chips dragged back from slots
      DragTarget<_DragData>(
        onWillAcceptWithDetails: (details) => details.data.fromSlot != null,
        onAcceptWithDetails: (details) => _returnToPool(details.data),
        builder: (ctx, candidates, _) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 1; i <= widget.q.options.length; i++)
              if (!_usedOptions.contains(i))
                Draggable<_DragData>(
                  data: _DragData(i),
                  feedback: Material(
                    color: Colors.transparent,
                    child: _ChipWidget(
                        text: widget.q.options[i - 1], dragging: false),
                  ),
                  childWhenDragging:
                      _ChipWidget(text: widget.q.options[i - 1], dragging: true),
                  child: _ChipWidget(
                      text: widget.q.options[i - 1], dragging: false),
                ),
          ],
        ),
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
    ]);
  }
}

class _SlotBox extends StatelessWidget {
  final int slotIndex;
  final String? text;
  final bool isStar;
  final bool isCorrect;
  final bool isWrong;
  final bool hovered;
  final bool dimmed;
  final double scale;

  const _SlotBox({
    required this.slotIndex,
    this.text,
    required this.isStar,
    required this.isCorrect,
    required this.isWrong,
    this.hovered = false,
    this.dimmed = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isCorrect
        ? AppColors.correctBg
        : isWrong
            ? AppColors.incorrectBg
            : hovered
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.btnBg;
    final borderColor = isCorrect
        ? AppColors.correct.withValues(alpha: 0.5)
        : isWrong
            ? AppColors.incorrect.withValues(alpha: 0.5)
            : isStar
                ? AppColors.accent
                : hovered
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : Colors.transparent;
    final textColor = isCorrect
        ? AppColors.correct
        : isWrong
            ? AppColors.incorrect
            : dimmed
                ? AppColors.muted
                : AppColors.fg;

    return Transform.scale(
      scale: scale,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: bg.withValues(alpha: dimmed ? 0.4 : 1.0),
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          border: Border.all(color: borderColor, width: isStar ? 2 : 1),
        ),
        child: Center(
          child: text != null
              ? Text(text!,
                  style: TextStyle(
                      fontSize: 15, color: textColor, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center)
              : Text(
                  isStar ? '★' : '${slotIndex + 1}',
                  style: TextStyle(
                      fontSize: isStar ? 20 : 16,
                      color: isStar
                          ? AppColors.accent.withValues(alpha: dimmed ? 0.3 : 1.0)
                          : AppColors.muted),
                ),
        ),
      ),
    );
  }
}

class _ChipWidget extends StatelessWidget {
  final String text;
  final bool dragging;
  const _ChipWidget({required this.text, required this.dragging});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dragging
            ? AppColors.surface.withValues(alpha: 0.4)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: dragging ? 0.15 : 0.4),
        ),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 16,
              color: dragging
                  ? AppColors.muted.withValues(alpha: 0.4)
                  : AppColors.fg,
              fontWeight: FontWeight.w500)),
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
