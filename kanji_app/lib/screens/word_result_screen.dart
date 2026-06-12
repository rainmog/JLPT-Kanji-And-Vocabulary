import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../services/sound_service.dart';
import '../models/quiz_models.dart';
import '../widgets/k_setup.dart';

class WordResultScreen extends ConsumerStatefulWidget {
  final WordQuestion question;
  final String selectedReading;
  final String selectedMeaning;
  final bool correct;

  const WordResultScreen({
    super.key,
    required this.question,
    required this.selectedReading,
    required this.selectedMeaning,
    required this.correct,
  });

  @override
  ConsumerState<WordResultScreen> createState() => _WordResultScreenState();
}

class _WordResultScreenState extends ConsumerState<WordResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.correct) {
      soundService.playCorrect();
    } else {
      soundService.playWrong();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Kanji
                      Text(widget.question.character,
                        style: TextStyle(fontSize: 72, color: AppColors.kanjiColor)),
                      const SizedBox(height: 20),

                      // Result message
                      Text(
                        widget.correct ? 'Correct!' : 'Incorrect',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.correct ? AppColors.correct : AppColors.incorrect,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.question.wordMeaning,
                        style: TextStyle(fontSize: 15, color: colors.muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Show answers
                      Container(
                        decoration: BoxDecoration(
                          color: colors.pillBg,
                          borderRadius: BorderRadius.circular(AppColors.containerRadius),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reading
                            Text('Reading', style: TextStyle(color: colors.muted, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: widget.selectedReading == widget.question.correctReading ? AppColors.correctBg : AppColors.incorrectBg,
                                    borderRadius: BorderRadius.circular(AppColors.containerRadius),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Your answer:', style: TextStyle(fontSize: 10, color: colors.muted)),
                                      Text(widget.selectedReading,
                                        style: TextStyle(fontSize: 14, color: colors.fg, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (widget.selectedReading != widget.question.correctReading)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.correctBg,
                                      borderRadius: BorderRadius.circular(AppColors.containerRadius),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Correct:', style: TextStyle(fontSize: 10, color: colors.muted)),
                                        Text(widget.question.correctReading,
                                          style: TextStyle(fontSize: 14, color: AppColors.correct, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 16),

                            // Meaning
                            Text('Meaning', style: TextStyle(color: colors.muted, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: widget.selectedMeaning == widget.question.wordMeaning ? AppColors.correctBg : AppColors.incorrectBg,
                                    borderRadius: BorderRadius.circular(AppColors.containerRadius),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Your answer:', style: TextStyle(fontSize: 10, color: colors.muted)),
                                      Text(widget.selectedMeaning,
                                        style: TextStyle(fontSize: 12, color: colors.fg, fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (widget.selectedMeaning != widget.question.wordMeaning)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.correctBg,
                                      borderRadius: BorderRadius.circular(AppColors.containerRadius),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Correct:', style: TextStyle(fontSize: 10, color: colors.muted)),
                                        Text(widget.question.wordMeaning,
                                          style: TextStyle(fontSize: 12, color: AppColors.correct, fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            KStickyFooter(
              colors: colors,
              child: KStartButton(
                label: 'Next',
                colors: colors,
                onTap: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
