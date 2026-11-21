/// How long until something is due, short enough for the top of a card:
/// "Due in 49m", "Due in 5hrs 49m", "Due in 1d 14hrs", "Due in 3d", and
/// "Overdue 7hrs" once it has passed. Rounded down, so it never says more time
/// is left than there is.
class Countdown {
  static String of(DateTime due, DateTime now) {
    final left = due.difference(now);
    if (left.isNegative) return 'Overdue ${_coarse(-left)}';
    final days = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    if (days >= 2) return 'Due in ${days}d';
    if (days == 1) return 'Due in 1d ${_hrs(hours)}';
    if (hours > 0) return 'Due in ${_hrs(hours)} ${minutes}m';
    return 'Due in ${minutes}m';
  }

  /// "1hr", "3hrs" (and "0hrs").
  static String _hrs(int hours) => hours == 1 ? '1hr' : '${hours}hrs';

  /// One unit only: past due, the exact minutes matter less.
  static String _coarse(Duration late) {
    if (late.inDays > 0) return '${late.inDays}d';
    if (late.inHours > 0) return _hrs(late.inHours);
    return '${late.inMinutes}m';
  }
}
