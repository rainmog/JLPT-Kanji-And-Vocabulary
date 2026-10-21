/// Local calendar-day key ('YYYY-MM-DD'). Used by the Leitner SRS scheduler
/// to decide whether a review is the first one of the day for an item.
String practiceDayKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
