import 'package:flutter/material.dart';
import '../theme.dart';

/// Standardized question-screen header: back button · spacer · "X / Y" · progress bar.
/// Used by kana, kanji, vocab and JLPT test screens.
class QuizHeader extends StatelessWidget {
  final String progress; // displayed on right, e.g. "3 / 15" or "Grammar · 2/8"
  final VoidCallback onBack;
  final int current;
  final int total;

  const QuizHeader({
    super.key,
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
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.fg),
            ),
          ),
          const Spacer(),
          Text(
            progress,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
            ),
          ),
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
