import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/sound_service.dart';
import 'word_session_screen.dart';

class WordResultScreen extends StatefulWidget {
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
  State<WordResultScreen> createState() => _WordResultScreenState();
}

class _WordResultScreenState extends State<WordResultScreen> {
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Kanji
              Text(widget.question.kanji.character,
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
                widget.question.correctMeaning,
                style: TextStyle(fontSize: 15, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Show answers
              Container(
                decoration: BoxDecoration(
                  color: AppColors.pillBg,
                  borderRadius: BorderRadius.circular(AppColors.containerRadius),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reading
                    Text('Reading', style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
                              Text('Your answer:', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                              Text(widget.selectedReading,
                                style: TextStyle(fontSize: 14, color: AppColors.fg, fontWeight: FontWeight.bold)),
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
                                Text('Correct:', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                                Text(widget.question.correctReading,
                                  style: TextStyle(fontSize: 14, color: AppColors.correct, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 16),

                    // Meaning
                    Text('Meaning', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.selectedMeaning == widget.question.correctMeaning ? AppColors.correctBg : AppColors.incorrectBg,
                            borderRadius: BorderRadius.circular(AppColors.containerRadius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your answer:', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                              Text(widget.selectedMeaning,
                                style: TextStyle(fontSize: 12, color: AppColors.fg, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.selectedMeaning != widget.question.correctMeaning)
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
                                Text('Correct:', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                                Text(widget.question.correctMeaning,
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
              const Spacer(),

              // Next button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Next'),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.10),
            ],
          ),
        ),
      ),
    );
  }
}
