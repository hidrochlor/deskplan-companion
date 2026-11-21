import 'calendar_event.dart';

/// Puts exam notifications on the phone's clock. An interface, so tests can
/// use a fake and the Android part stays in one place.
abstract class ExamReminders {
  /// Cancels the notifications of [before] and sets the ones [now] needs.
  Future<void> replace(List<CalendarEvent> before, List<CalendarEvent> now);
}

/// For places with no notifications (the background worker's copy needs
/// none of its own: the app sets them when it opens or syncs).
class NoExamReminders implements ExamReminders {
  const NoExamReminders();

  @override
  Future<void> replace(List<CalendarEvent> before, List<CalendarEvent> now) =>
      Future.value();
}
