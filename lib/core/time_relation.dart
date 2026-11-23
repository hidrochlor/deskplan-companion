/// How one time block (B) sits against another (A) on the same day, as
/// plain time differences. Pure logic, for the calendar's clash lines.
///
/// Clash (they overlap), B against A:
///   EPE 13:30-17:45, HS1 16:00-17:00 →
///   "Starts 2h 30m after EPE starts (1h 45m before it ends),
///    ends 45m before EPE ends"
///   A 1-8, B 7-9 → "Starts 6h after A starts (1h before it ends),
///    ends 1h after A ends"
///
/// Arrow (no overlap, B starts up to 30m after A ends), on B only:
///   "Starts 30m after A ends"
class TimeRelation {
  final String text;

  /// True when the two run at the same time (a clash); false for the arrow.
  final bool overlaps;

  const TimeRelation(this.text, this.overlaps);

  /// How close after A's end B may start to get the arrow.
  static const near = Duration(minutes: 30);

  /// "1h", "30m", "1h 30m".
  static String span(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// "30m after A starts", "1h before A ends", "with A's start".
  static String _diff(DateTime t, DateTime ref, String refName) {
    if (t == ref) return 'at the same time as $refName';
    final d = t.difference(ref);
    return d.isNegative
        ? '${span(-d)} before $refName'
        : '${span(d)} after $refName';
  }

  /// How block [bStart]-[bEnd] (named nothing: it is the one the line is
  /// shown on) relates to [a] ([aStart]-[aEnd]), or null when they do not
  /// overlap and B does not start within [near] after A ends.
  static TimeRelation? of(
    DateTime bStart,
    DateTime bEnd,
    DateTime aStart,
    DateTime aEnd,
    String a,
  ) {
    final overlap = bStart.isBefore(aEnd) && bEnd.isAfter(aStart);
    if (!overlap) {
      final gap = bStart.difference(aEnd);
      if (gap.isNegative || gap > near) return null;
      return TimeRelation(
        gap == Duration.zero
            ? 'Starts right when $a ends'
            : 'Starts ${span(gap)} after $a ends',
        false,
      );
    }
    final startInside = bStart.isAfter(aStart) && bStart.isBefore(aEnd);
    final endInside = bEnd.isAfter(aStart) && bEnd.isBefore(aEnd);

    // The start, against A's start; while A is on, also against its end.
    var start = 'Starts ${_diff(bStart, aStart, '$a starts')}';
    if (startInside) {
      start += ' (${span(aEnd.difference(bStart))} before it ends)';
    }

    // The end, against A's end; when B started before A, also against
    // A's start (that is where the clash begins).
    var end = 'ends ${_diff(bEnd, aEnd, '$a ends')}';
    if (endInside && bStart.isBefore(aStart)) {
      end += ' (${span(bEnd.difference(aStart))} after it starts)';
    }
    return TimeRelation('$start, $end', true);
  }
}
