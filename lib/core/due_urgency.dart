/// How urgent a due time is. Same bands as DeskPlan (docs/DESIGN.md).
enum DueUrgency {
  overdue,
  within24Hours,
  withinWeek,
  later;

  /// [due] and [now] are compared as instants, so time zones don't matter.
  static DueUrgency of(DateTime due, DateTime now) {
    final left = due.difference(now);
    if (left.isNegative) return overdue;
    if (left <= const Duration(hours: 24)) return within24Hours;
    if (left <= const Duration(days: 7)) return withinWeek;
    return later;
  }
}
