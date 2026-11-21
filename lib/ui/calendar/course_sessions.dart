import '../../features/calendar/calendar_event.dart';
import '../../features/calendar/calendar_event_kind.dart';

/// A weekly slot a course meets in: a weekday and local start and end times.
class WeeklySlot {
  /// [DateTime.monday] to [DateTime.sunday].
  final int weekday;
  final int startMinute;
  final int endMinute;

  /// How many sessions fall in this slot.
  final int count;

  const WeeklySlot(this.weekday, this.startMinute, this.endMinute, this.count);

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _hm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  /// "Tue 09:00–12:15", or "Tue 09:00" for a moment.
  String get label => startMinute == endMinute
      ? '${_days[weekday - 1]} ${_hm(startMinute)}'
      : '${_days[weekday - 1]} ${_hm(startMinute)}–${_hm(endMinute)}';
}

/// Every lecture and exam of one course, from the cached calendar events,
/// and the weekly pattern its lectures follow.
class CourseSessions {
  final String course;

  /// Soonest first.
  final List<CalendarEvent> sessions;

  CourseSessions._(this.course, this.sessions);

  /// The sessions of [course] (compared without case) among [events]. Other
  /// events and courses are left out.
  factory CourseSessions.of(String course, Iterable<CalendarEvent> events) {
    final key = course.trim().toLowerCase();
    final list =
        events
            .where(
              (e) =>
                  e.kind != CalendarEventKind.event &&
                  e.courseName.trim().toLowerCase() == key,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return CourseSessions._(course, list);
  }

  List<CalendarEvent> get lectures =>
      sessions.where((e) => e.kind == CalendarEventKind.lecture).toList();

  List<CalendarEvent> get exams =>
      sessions.where((e) => e.kind == CalendarEventKind.exam).toList();

  /// The first session that has not ended yet, or null when all are past.
  CalendarEvent? next(DateTime now) {
    for (final e in sessions) {
      if (!e.isPast(now)) return e;
    }
    return null;
  }

  /// The slots at least two lectures share, most used first (then by
  /// weekday and time). Lectures that fit no repeating slot are left out:
  /// [irregular] counts them.
  List<WeeklySlot> get weekly {
    final counts = <(int, int, int), int>{};
    for (final e in lectures) {
      final s = e.start.toLocal();
      final t = e.end.toLocal();
      final slot = (s.weekday, s.hour * 60 + s.minute, t.hour * 60 + t.minute);
      counts[slot] = (counts[slot] ?? 0) + 1;
    }
    final slots = [
      for (final MapEntry(key: (d, from, to), value: n) in counts.entries)
        if (n >= 2) WeeklySlot(d, from, to, n),
    ];
    slots.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      final byDay = a.weekday.compareTo(b.weekday);
      return byDay != 0 ? byDay : a.startMinute.compareTo(b.startMinute);
    });
    return slots;
  }

  /// Lectures outside every weekly slot.
  int get irregular =>
      lectures.length - weekly.fold(0, (sum, s) => sum + s.count);
}
