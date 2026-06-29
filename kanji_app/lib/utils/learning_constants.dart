/// Practice-based learning constants.
///
/// In 'practice' learning mode an item is promoted to 'learned' once its
/// `practice_progress` counter reaches this threshold. Each correct answer
/// adds 1; each wrong answer subtracts 1 (floored at 0).
const int kPracticeLearnThreshold = 4;

/// Outcome of recording one practice answer.
/// [progress] is the current practice_progress counter (0..threshold).
/// [learned] is true if the item is now in 'learned' status.
/// [promoted] is true only on the answer that crossed the threshold.
typedef PracticeResult = ({bool promoted, bool learned, int progress});
