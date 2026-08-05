/// Practice-based learning constants (spaced, points-based).
///
/// In 'practice' learning mode an item accumulates `practice_points` and is
/// promoted to 'learned' once it reaches [kPracticePointsToLearn]. Points scale
/// so that the *first* correct answer of each day is worth more than repeats,
/// and the per-day appearance cap forces the item to be recalled across several
/// days before it is learned (better retention).
///
///   first correct answer of the day   → +[kPracticeFirstCorrectPoints]
///   each further correct answer today  → +[kPracticeRepeatCorrectPoints]
///   any wrong answer                   → −[kPracticeWrongPenalty] (floored at 0)
///
/// With the daily cap of [kPracticeDailyCap] appearances, the best case is:
///   day 1: 5 + 1 + 1 + 1 = 8
///   day 2: +8            = 16
///   day 3: +5 (first)    = 21 ≥ 20  → learned
/// so an item takes a **minimum of 3 days**, 4 if answers are missed.
const int kPracticePointsToLearn = 20;
const int kPracticeFirstCorrectPoints = 5;
const int kPracticeRepeatCorrectPoints = 1;
const int kPracticeWrongPenalty = 1;

/// Max times an unlearned item may appear in practice modes per calendar day.
const int kPracticeDailyCap = 4;

/// Outcome of recording one practice answer.
/// [points] is the current practice_points counter (0..[kPracticePointsToLearn]).
/// [learned] is true if the item is now in 'learned' status.
/// [promoted] is true only on the answer that crossed the threshold.
/// [seenToday] is how many times the item has appeared today (0..cap), used to
/// enforce the daily appearance cap.
/// [delta] is the change in practice_points this answer caused (+5 first correct
/// of the day / +1 repeat / −1 wrong, after clamping). Used to show a per-answer
/// +/-% indicator alongside the feedback.
typedef PracticeResult = ({bool promoted, bool learned, int points, int seenToday, int delta});

/// Progress toward 'learned' as a percentage (0..100) for a given points count.
int practicePointsPercent(int points) =>
    (points / kPracticePointsToLearn * 100).round().clamp(0, 100);

/// Local calendar-day key ('YYYY-MM-DD'). The daily bonus and appearance cap
/// both reset on this boundary (local midnight).
String practiceDayKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Pure points math for one practice answer, shared by every progress repo.
/// Callers pass the item's stored counters plus [today]; the result is written
/// back verbatim (points, seenToday, correctToday) along with `practice_day`.
({int points, int seenToday, int correctToday, bool firstCorrectOfDay})
    applyPracticeAnswer({
  required int points,
  required String? day,
  required int seenToday,
  required int correctToday,
  required String today,
  required bool isCorrect,
}) {
  // New day → reset the per-day counters (points persist across days).
  if (day != today) {
    seenToday = 0;
    correctToday = 0;
  }
  int delta;
  var firstCorrect = false;
  if (isCorrect) {
    firstCorrect = correctToday == 0;
    delta = firstCorrect ? kPracticeFirstCorrectPoints : kPracticeRepeatCorrectPoints;
    correctToday += 1;
  } else {
    delta = -kPracticeWrongPenalty;
  }
  seenToday += 1;
  final newPoints = (points + delta).clamp(0, kPracticePointsToLearn);
  return (
    points: newPoints,
    seenToday: seenToday,
    correctToday: correctToday,
    firstCorrectOfDay: firstCorrect,
  );
}
