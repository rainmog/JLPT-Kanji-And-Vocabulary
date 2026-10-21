import 'package:flutter/material.dart';
import '../utils/srs_scheduler.dart';

/// Small, inconspicuous badge shown next to the answer feedback.
///
/// Displays the item's current Leitner box progress, e.g. `Box 2/5`.
/// Colored to match the correct/incorrect feedback box.
class PracticeDeltaBadge extends StatelessWidget {
  final int box;
  final Color color;

  const PracticeDeltaBadge.box({super.key, required this.box, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = 'Box $box/$kSrsBoxCount';
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
