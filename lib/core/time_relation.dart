/// How much two time blocks on the same day overlap, as one plain line
/// for the calendar's clash notice. Pure logic.
///
/// A is the one that starts first (on the same start, the longer one); B
/// starts while A is still on. Only A's end and B's start are used:
///   on B: "Starts 15m before A ends"
///   on A: "Ends 15m after B starts"
class TimeRelation {
  /// "1h", "30m", "1h 30m".
  static String span(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// The line shown on block [start]-[end] about [other]
  /// ([otherStart]-[otherEnd]), or null when they do not overlap.
  static String? of(
    DateTime start,
    DateTime end,
    DateTime otherStart,
    DateTime otherEnd,
    String other,
  ) {
    if (!start.isBefore(otherEnd) || !end.isAfter(otherStart)) return null;
    final first =
        start.isBefore(otherStart) ||
        (start == otherStart && end.isAfter(otherEnd));
    return first
        ? 'Ends ${span(end.difference(otherStart))} after $other starts'
        : 'Starts ${span(otherEnd.difference(start))} before $other ends';
  }
}
