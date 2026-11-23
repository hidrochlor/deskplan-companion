import 'calendar_event.dart';
import 'calendar_event_kind.dart';

/// The dates a timetable feed lists for each course's exam, and which one
/// the user registered for. The feed is the group's, not the student's: it
/// lists every sitting of an exam (the first date and the retakes) and does
/// not say which one someone registered for, so the user marks it on the
/// phone. Pure logic.
///
/// Each exam date is numbered by time among its course's dates ("Date 2
/// of 3"). Once one is marked, the course's other dates are passed over:
/// shown dimmed, with no clash and no reminder.
class ExamDates {
  /// Event id → (its number, how many dates its course has).
  final Map<String, (int, int)> _numbers;

  /// Course key → the id of the date registered for (only ids still in
  /// the feed).
  final Map<String, String> _chosen;

  const ExamDates._(this._numbers, this._chosen);

  /// No exams, nothing marked.
  static const none = ExamDates._({}, {});

  /// [chosen] is what the user marked: course key → event id. A mark whose
  /// date is no longer in the feed is ignored.
  factory ExamDates.of(
    Iterable<CalendarEvent> events,
    Map<String, String> chosen,
  ) {
    final byCourse = <String, List<CalendarEvent>>{};
    for (final e in events) {
      if (e.kind == CalendarEventKind.exam) {
        (byCourse[keyOf(e)] ??= []).add(e);
      }
    }
    final numbers = <String, (int, int)>{};
    final valid = <String, String>{};
    for (final MapEntry(key: course, value: dates) in byCourse.entries) {
      dates.sort((a, b) => a.start.compareTo(b.start));
      for (var i = 0; i < dates.length; i++) {
        numbers[dates[i].id] = (i + 1, dates.length);
      }
      final pick = chosen[course];
      if (pick != null && dates.any((d) => d.id == pick)) valid[course] = pick;
    }
    return ExamDates._(numbers, valid);
  }

  /// The course an exam belongs to, as the marks are kept.
  static String keyOf(CalendarEvent e) =>
      CalendarEvent.courseKeyOf(e.courseName);

  /// (n, of) for an exam date, or null for anything else.
  (int, int)? numberOf(CalendarEvent e) => _numbers[e.id];

  /// "Date 2 of 3", or null for an exam with one date (or not an exam).
  String? labelOf(CalendarEvent e) {
    final n = numberOf(e);
    return n == null || n.$2 < 2 ? null : 'Date ${n.$1} of ${n.$2}';
  }

  /// The user registered for this date.
  bool isRegistered(CalendarEvent e) => _chosen[keyOf(e)] == e.id;

  /// Another date of this exam is the one registered for.
  bool isPassedOver(CalendarEvent e) {
    if (e.kind != CalendarEventKind.exam) return false;
    final pick = _chosen[keyOf(e)];
    return pick != null && pick != e.id;
  }
}
