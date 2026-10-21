import 'package:flutter/material.dart';
import '../utils/learning_constants.dart';
import '../utils/srs_scheduler.dart';

/// Small, inconspicuous badge shown next to the answer feedback.
///
/// Two modes:
///  - Points mode (default constructor, kana/vocab practice): shows the
///    per-answer delta plus the new running total, e.g. `+25% (25%)`.
///  - SRS box mode ([PracticeDeltaBadge.box], kanji practice): shows the item's
///    current Leitner box progress, e.g. `Box 2/5`.
/// Colored to match the correct/incorrect feedback box.
class PracticeDeltaBadge extends StatelessWidget {
  final PracticeResult? result;
  final int? box;
  final Color color;

  const PracticeDeltaBadge({super.key, required PracticeResult this.result, required this.color})
      : box = null;

  /// Kanji SRS track: display the item's current box as `Box N/5`.
  const PracticeDeltaBadge.box({super.key, required int this.box, required this.color})
      : result = null;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (box != null) {
      label = 'Box $box/$kSrsBoxCount';
    } else {
      final newPct = practicePointsPercent(result!.points);
      final oldPct = practicePointsPercent(result!.points - result!.delta);
      final deltaPct = newPct - oldPct;
      final sign = deltaPct >= 0 ? '+' : '';
      label = '$sign$deltaPct% ($newPct%)';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
