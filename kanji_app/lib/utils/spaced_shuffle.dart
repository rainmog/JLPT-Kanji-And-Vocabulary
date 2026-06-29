import 'dart:math';

/// Shuffles [items] while guaranteeing the same key does not reappear within
/// [minGap] positions of its previous placement. Useful for quiz queues so the
/// same kanji/kana/vocab is never shown back-to-back (and ideally not until a
/// few other questions have passed).
///
/// [keyOf] extracts the identity used for spacing (e.g. an id or character).
/// When the gap constraint cannot be satisfied (small pools), it relaxes
/// gracefully: it always avoids an immediate repeat when possible, and only
/// falls back to placing a repeat when no other candidate exists.
List<T> spacedShuffle<T>(List<T> items, Object Function(T) keyOf, {int minGap = 3, Random? rng}) {
  if (items.length <= 1) return List.of(items);
  final r = rng ?? Random();
  final remaining = List.of(items)..shuffle(r);
  final result = <T>[];
  // Position in `result` at which each key was last placed (-inf initially).
  final lastPos = <Object, int>{};

  while (remaining.isNotEmpty) {
    final pos = result.length;
    int chosen = -1;
    int fallback = -1; // best (largest-gap) candidate if none satisfies minGap

    for (var i = 0; i < remaining.length; i++) {
      final key = keyOf(remaining[i]);
      final last = lastPos[key];
      final gap = last == null ? 1 << 30 : pos - last;
      if (gap >= minGap) {
        chosen = i;
        break;
      }
      // Track the candidate with the largest gap as a fallback.
      if (fallback == -1 ||
          gap > (pos - (lastPos[keyOf(remaining[fallback])] ?? -(1 << 30)))) {
        fallback = i;
      }
    }

    final pick = chosen != -1 ? chosen : fallback;
    final item = remaining.removeAt(pick);
    lastPos[keyOf(item)] = pos;
    result.add(item);
  }
  return result;
}
