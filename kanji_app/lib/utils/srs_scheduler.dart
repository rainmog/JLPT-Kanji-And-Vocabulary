/// Leitner spaced-repetition scheduler (pure, no I/O).
///
/// Items move up a fixed box ladder on a correct answer and reset to box 1
/// on a wrong one. The due date is computed from the box interval. Only the
/// FIRST review of an item on a given day changes its schedule; extra same-day
/// answers are practice-only ([SrsUpdate.changed] == false).
library;

import '../utils/learning_constants.dart' show practiceDayKey;

/// Days until next due after a correct answer, indexed by (box - 1).
const List<int> kSrsIntervals = [1, 2, 4, 9, 21];

/// Number of boxes. A correct answer in the top box graduates the item.
const int kSrsBoxCount = 5;

/// Result of applying one review.
/// [box] / [due] are the new values to persist WHEN [changed] is true.
/// When [changed] is false (same-day repeat), the caller keeps the stored
/// box/due and [due] is null.
/// [learned] is true only on the answer that graduates the item.
typedef SrsUpdate = ({int box, String? due, bool learned, bool changed});

/// Result of recording one review at the repository layer.
typedef SrsReviewResult = ({int box, bool learned, bool graduated});

/// Due day (local 'YYYY-MM-DD') for an item that just entered [box] (1-indexed)
/// as of [today].
String srsDueAfter(int box, String today) {
  final interval = kSrsIntervals[(box - 1).clamp(0, kSrsBoxCount - 1)];
  final d = DateTime.parse(today);
  final due = DateTime(d.year, d.month, d.day + interval);
  return practiceDayKey(due);
}

SrsUpdate applySrsReview({
  required int box,
  required String? lastReview,
  required String today,
  required bool isCorrect,
}) {
  // Same-day repeat: practice only, no schedule change.
  if (lastReview == today) {
    return (box: box, due: null, learned: false, changed: false);
  }

  if (!isCorrect) {
    return (box: 1, due: srsDueAfter(1, today), learned: false, changed: true);
  }

  // Correct in the top box → graduate.
  if (box >= kSrsBoxCount) {
    return (box: kSrsBoxCount, due: null, learned: true, changed: true);
  }

  final newBox = box + 1; // box 0 (new) -> 1 handled here too
  return (box: newBox, due: srsDueAfter(newBox, today), learned: false, changed: true);
}
