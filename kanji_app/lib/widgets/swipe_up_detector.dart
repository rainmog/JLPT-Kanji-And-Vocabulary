import 'package:flutter/material.dart';

/// Feedback-overlay gesture: tap anywhere to continue, swipe up for examples.
class SwipeUpDetector extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onSwipeUp;
  const SwipeUpDetector({super.key, required this.onTap, this.onSwipeUp});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragEnd: onSwipeUp == null
          ? null
          : (d) {
              if ((d.primaryVelocity ?? 0) < -250) onSwipeUp!();
            },
      child: const SizedBox.expand(),
    );
  }
}

/// The hint line shown under a graded answer.
const String continueHint = 'Tap anywhere to continue, or swipe up for examples';
