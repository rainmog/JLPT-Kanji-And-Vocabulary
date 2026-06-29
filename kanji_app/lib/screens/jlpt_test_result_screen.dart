import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/history_repository.dart';
import '../repositories/jlpt_repository.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import 'home_screen.dart' show allProgressProvider, jlptTestDataProvider;
import 'main_shell.dart';

class JlptTestResultScreen extends ConsumerStatefulWidget {
  final JlptTestSession session;
  final Map<int, int> answers;
  const JlptTestResultScreen({super.key, required this.session, required this.answers});

  @override
  ConsumerState<JlptTestResultScreen> createState() => _JlptTestResultScreenState();
}

class _JlptTestResultScreenState extends ConsumerState<JlptTestResultScreen> {
  bool _historySaved = false;

  @override
  void initState() {
    super.initState();
    soundService.playTestComplete();
    _saveHistory();
  }

  Future<void> _saveHistory() async {
    if (_historySaved) return;
    _historySaved = true;
    final vC = _correct(widget.session.vocabulary);
    final gC = _correct(widget.session.grammar);
    final rC = _correct(widget.session.reading);
    final vT = widget.session.vocabulary.length;
    final gT = widget.session.grammar.length;
    final rT = widget.session.reading.length;
    final detail = (vT > 0 && gT > 0 && rT > 0)
        ? {'vocabulary': [vC, vT], 'grammar': [gC, gT], 'reading': [rC, rT]}
        : null;
    await historyRepo.logResult(
      testType: 'jlpt',
      level: widget.session.level,
      section: widget.session.vocabulary.isNotEmpty &&
              widget.session.grammar.isEmpty &&
              widget.session.reading.isEmpty
          ? 'vocabulary'
          : widget.session.grammar.isNotEmpty &&
                  widget.session.vocabulary.isEmpty &&
                  widget.session.reading.isEmpty
              ? 'grammar'
              : widget.session.reading.isNotEmpty &&
                      widget.session.vocabulary.isEmpty &&
                      widget.session.grammar.isEmpty
                  ? 'reading'
                  : null,
      score: vC + gC + rC,
      total: vT + gT + rT,
      detail: detail,
    );
  }

  int _correct(List<JlptQuestion> qs) =>
      qs.where((q) => widget.answers[q.id] == q.correctOption).length;

  void _invalidateAndPop(BuildContext context) {
    ref.invalidate(allProgressProvider);
    ref.invalidate(jlptTestDataProvider(widget.session.level));
    Navigator.pushAndRemoveUntil(context, AppRoute.to(const MainShell()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final vC = _correct(widget.session.vocabulary);
    final gC = _correct(widget.session.grammar);
    final rC = _correct(widget.session.reading);
    final totalCorrect = vC + gC + rC;
    final totalQuestions = widget.session.totalQuestions;
    final pct = totalQuestions > 0 ? (totalCorrect / totalQuestions * 100).round() : 0;
    final missed = widget.session.allQuestions
        .where((q) => widget.answers[q.id] != q.correctOption)
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _invalidateAndPop(context);
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            KBackHeader(title: 'N${widget.session.level} Test Results', colors: colors),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Total score card
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.pillBg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$totalCorrect',
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                ),
                              ),
                              TextSpan(
                                text: ' / $totalQuestions',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.muted.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Total Score',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: totalQuestions > 0 ? totalCorrect / totalQuestions : 0,
                            minHeight: 10,
                            backgroundColor: AppColors.pillBg,
                            valueColor: AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$pct% — ${pct >= 60 ? 'Pass' : 'Needs improvement'}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: pct >= 60 ? AppColors.correct : AppColors.incorrect,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Section scores label
                  const SizedBox(height: 22),
                  Text(
                    'SECTION SCORES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.muted.withValues(alpha: 0.6),
                    ),
                  ),

                  // Section cards
                  if (widget.session.vocabulary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SectionCard(
                        label: 'Vocabulary',
                        correct: vC,
                        total: widget.session.vocabulary.length),
                  ],
                  if (widget.session.grammar.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SectionCard(
                        label: 'Grammar',
                        correct: gC,
                        total: widget.session.grammar.length),
                  ],
                  if (widget.session.reading.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SectionCard(
                        label: 'Reading',
                        correct: rC,
                        total: widget.session.reading.length),
                  ],

                  // Missed questions header
                  const SizedBox(height: 26),
                  Text(
                    'Missed Questions (${missed.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.fg,
                    ),
                  ),

                  // Missed question cards
                  const SizedBox(height: 12),
                  for (final q in missed) ...[
                    _MissedQuestionCard(q: q, yourAnswer: widget.answers[q.id]),
                    const SizedBox(height: 12),
                  ],

                  // Done button
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      onPressed: () => _invalidateAndPop(context),
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String label;
  final int correct, total;
  const _SectionCard({required this.label, required this.correct, required this.total});

  @override
  Widget build(BuildContext context) {
    final secPct = total > 0 ? (correct / total * 100).round() : 0;
    final barColor = secPct >= 50 ? AppColors.correct : AppColors.incorrect;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(width: 4, color: barColor),
          right: BorderSide(color: AppColors.pillBg),
          top: BorderSide(color: AppColors.pillBg),
          bottom: BorderSide(color: AppColors.pillBg),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg,
                  ),
                ),
              ),
              Text(
                '$correct/$total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total > 0 ? correct / total : 0,
              minHeight: 6,
              backgroundColor: AppColors.pillBg,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedQuestionCard extends StatelessWidget {
  final JlptQuestion q;
  final int? yourAnswer;
  const _MissedQuestionCard({required this.q, this.yourAnswer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(width: 4, color: AppColors.pillBg),
          right: BorderSide(color: AppColors.pillBg),
          top: BorderSide(color: AppColors.pillBg),
          bottom: BorderSide(color: AppColors.pillBg),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q.passage != null) ...[
            Text(
              q.passage!,
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            q.questionStem,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.fg,
              height: 1.9,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (yourAnswer != null)
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your answer: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.incorrect,
                        ),
                      ),
                      TextSpan(
                        text: q.options[yourAnswer! - 1],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.incorrect,
                        ),
                      ),
                    ],
                  ),
                ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Correct: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.correct,
                      ),
                    ),
                    TextSpan(
                      text: q.correctAnswer,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.correct,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
