import 'package:flutter/material.dart';
import '../controllers/session_controller.dart';
import '../repositories/progress_repository.dart';
import '../utils/answer_validator.dart';
import '../widgets/structured_sentence.dart';
import '../widgets/furigana_widget.dart';
import '../theme.dart';
import '../services/sound_service.dart';

class ResultScreen extends StatefulWidget {
  final SessionQuestion question;
  final String userInput;
  final SessionMode mode;
  final Set<String> knownChars;

  const ResultScreen({
    super.key,
    required this.question,
    required this.userInput,
    required this.mode,
    required this.knownChars,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final bool _correct;

  @override
  void initState() {
    super.initState();
    _correct = AnswerValidator.validate(widget.userInput, widget.question.validReadings);
    _persist();
    if (_correct) {
      soundService.playCorrect();
    } else {
      soundService.playWrong();
    }
  }

  Future<void> _persist() async {
    if (_correct) {
      await progressRepo.recordCorrect(widget.question.kanjiId);
    } else {
      await progressRepo.recordIncorrect(widget.question.kanjiId);
    }
  }

  Future<void> _moveBack() async {
    await progressRepo.markUnlearned(widget.question.kanjiId);
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final targetTokens = q.tokens.where((t) => t.kanjiChar == q.character).toList();
    final kanjiForm = targetTokens.isNotEmpty
        ? targetTokens.map((t) => t.surface).join()
        : q.character;
    final furigana = q.validReadings.isNotEmpty ? q.validReadings.first : '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _correct ? AppColors.correctBg : AppColors.incorrectBg,
                borderRadius: BorderRadius.circular(AppColors.containerRadius),
                border: Border.all(color: _correct ? const Color(0xFF1a5535) : const Color(0xFF5a2020)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _correct ? '✓  CORRECT' : '✗  INCORRECT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1,
                  color: _correct ? AppColors.correct : AppColors.incorrect,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(q.character,
              style: TextStyle(fontSize: 48, color: AppColors.kanjiColor)),
            const SizedBox(height: 10),
            FuriganaWidget(
              meaning: q.meaning,
              onReading: q.onReading,
              kunReading: q.kunReading,
              furigana: furigana,
              kanjiForm: kanjiForm,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: AppColors.pillBg, borderRadius: BorderRadius.circular(AppColors.containerRadius)),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StructuredSentence(
                  tokens: q.tokens,
                  targetKanjiChar: q.character,
                  knownChars: widget.knownChars,
                  showTargetHighlight: true,
                ),
                const SizedBox(height: 8),
                Text('"${q.englishTranslation}"',
                  style: TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic)),
              ]),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _correct ? const Color(0xFF0d3322) : AppColors.btnBg,
                  foregroundColor: _correct ? AppColors.correct : AppColors.kanjiColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.containerRadius)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(context, _correct),
                child: Text('Next →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            if (!_correct && widget.mode == SessionMode.review) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _moveBack,
                child: Text('↩  Move back to unlearned',
                  style: TextStyle(fontSize: 10, color: Color(0xFF664444))),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
