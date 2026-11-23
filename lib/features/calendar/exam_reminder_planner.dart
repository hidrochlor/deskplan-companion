import 'exam_dates.dart';
import '../reminders/reminder_ids.dart';
import '../reminders/reminder_kind.dart';
import 'calendar_event.dart';
import 'calendar_event_kind.dart';

/// One exam notification: when, what, and its Android id.
class ExamReminder {
  final int notificationId;

  /// The exam's id, to open it when the notification is tapped.
  final String eventId;
  final DateTime at;
  final String title;
  final String body;

  const ExamReminder({
    required this.notificationId,
    required this.eventId,
    required this.at,
    required this.title,
    required this.body,
  });
}

/// Decides which calendar events get a notification, as DeskPlan does
/// (protocol.md section 5): an exam 1 day and 1 hour before its start;
/// lectures and other events never. Pure logic, so it is easy to test.
class ExamReminderPlanner {
  static const dayBefore = Duration(days: 1);
  static const hourBefore = Duration(hours: 1);

  /// The Android ids an event's notifications use, kept apart from the
  /// items' own by a prefix (an event id is never an item id).
  static List<int> idsOf(CalendarEvent event) => [
    ReminderIds.forTask('exam-day:${event.id}', ReminderKind.start),
    ReminderIds.forTask('exam-hour:${event.id}', ReminderKind.start),
  ];

  /// [registered] is what the user marked (course key → event id, see
  /// ExamDates): the other dates of a marked exam get no reminder.
  static List<ExamReminder> forEvents(
    Iterable<CalendarEvent> events,
    DateTime now, {
    Map<String, String> registered = const {},
  }) {
    final dates = ExamDates.of(events, registered);
    final plan = <ExamReminder>[];
    for (final e in events) {
      if (e.kind != CalendarEventKind.exam || dates.isPassedOver(e)) continue;
      final [dayId, hourId] = idsOf(e);
      final day = e.start.subtract(dayBefore);
      final hour = e.start.subtract(hourBefore);
      if (day.isAfter(now)) {
        plan.add(
          ExamReminder(
            notificationId: dayId,
            eventId: e.id,
            at: day,
            title: 'Exam tomorrow',
            body: e.title,
          ),
        );
      }
      if (hour.isAfter(now)) {
        plan.add(
          ExamReminder(
            notificationId: hourId,
            eventId: e.id,
            at: hour,
            title: 'Exam in 1 hour',
            body: e.title,
          ),
        );
      }
    }
    return plan;
  }
}
