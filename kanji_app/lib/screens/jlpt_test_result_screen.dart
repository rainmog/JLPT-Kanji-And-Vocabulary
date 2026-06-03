import 'package:flutter/material.dart';
import '../repositories/history_repository.dart';
import '../repositories/jlpt_repository.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import 'home_screen.dart';

class JlptTestResultScreen extends StatefulWidget {
  final JlptTestSession session;
  final Map<int, int> answers;
  const JlptTestResultScreen({super.key, required this.session, required this.answers});

  @override
  State<JlptTestResultScreen> createState() => _JlptTestResultScreenState();
}

class _JlptTestResultScreenState extends State<JlptTestResultScreen> {
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

  @override
  Widget build(BuildContext context) {
    final vC = _correct(widget.session.vocabulary);
    final gC = _correct(widget.session.grammar);
    final rC = _correct(widget.session.reading);
    final totalCorrect = vC + gC + rC;
    final missed = widget.session.allQuestions
        .where((q) => widget.answers[q.id] != q.correctOption)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, automaticallyImplyLeading: false,
        title: Text('N${widget.session.level} Test Results', style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.containerRadius)),
          child: Column(children: [
            Text('$totalCorrect / ${widget.session.totalQuestions}',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.accentBright)),
            const SizedBox(height: 4),
            Text('Total Score', style: TextStyle(color: AppColors.muted)),
          ]),
        ),
        const SizedBox(height: 16),
        if (widget.session.vocabulary.isNotEmpty) ...[
          _SectionScore('Vocabulary', vC, widget.session.vocabulary.length),
          const SizedBox(height: 8),
        ],
        if (widget.session.grammar.isNotEmpty) ...[
          _SectionScore('Grammar', gC, widget.session.grammar.length),
          const SizedBox(height: 8),
        ],
        if (widget.session.reading.isNotEmpty) ...[
          _SectionScore('Reading', rC, widget.session.reading.length),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 24),
        if (missed.isNotEmpty) ...[
          Text('Missed Questions (${missed.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 12),
          for (final q in missed) ...[_MissedQuestion(q: q, yourAnswer: widget.answers[q.id]), const SizedBox(height: 12)],
          const SizedBox(height: 16),
        ],
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.buttonRadius))),
          onPressed: () => Navigator.pushAndRemoveUntil(context, AppRoute.to(const HomeScreen()), (_) => false),
          child: const Text('Done', style: TextStyle(fontSize: 16)),
        ),
      ]),
    );
  }
}

class _SectionScore extends StatelessWidget {
  final String label; final int correct, total;
  const _SectionScore(this.label, this.correct, this.total);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: AppColors.btnBg,
        borderRadius: BorderRadius.circular(AppColors.containerRadius)),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: AppColors.fg))),
      Text('$correct / $total', style: TextStyle(
          color: correct == total ? AppColors.correct : AppColors.fg, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _MissedQuestion extends StatelessWidget {
  final JlptQuestion q; final int? yourAnswer;
  const _MissedQuestion({required this.q, this.yourAnswer});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.containerRadius),
        border: Border.all(color: AppColors.incorrectBg)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (q.passage != null) ...[
        Text(q.passage!, style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
            maxLines: 4, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
      ],
      Text(q.questionStem, style: TextStyle(fontSize: 15, color: AppColors.fg)),
      const SizedBox(height: 8),
      if (yourAnswer != null)
        Text('Your answer: ${q.options[yourAnswer! - 1]}', style: TextStyle(color: AppColors.incorrect, fontSize: 13)),
      Text('Correct: ${q.correctAnswer}', style: TextStyle(color: AppColors.correct, fontSize: 13)),
    ]),
  );
}
