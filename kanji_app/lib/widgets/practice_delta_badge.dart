import 'package:flutter/material.dart';
import '../utils/learning_constants.dart';

/// Small, inconspicuous badge showing how one practice answer moved an item's
/// progress toward 'learned': the per-answer delta plus the new running total,
/// e.g. `+25% (25%)` for the first correct of the day, `+5%` for a repeat, or
/// `-5%` for a wrong answer. Colored to match the correct/incorrect feedback box.
class PracticeDeltaBadge extends StatelessWidget {
  final PracticeResult result;
  final Color color;

  const PracticeDeltaBadge({super.key, required this.result, required this.color});

  @override
  Widget build(BuildContext context) {
    final newPct = practicePointsPercent(result.points);
    final oldPct = practicePointsPercent(result.points - result.delta);
    final deltaPct = newPct - oldPct;
    final sign = deltaPct >= 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$sign$deltaPct% ($newPct%)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
