import 'calendar_event.dart';
import 'calendar_reply.dart';

/// The calendar events kept on the phone, to show offline.
abstract class CalendarStore {
  /// Replaces every cached event that touches the reply's window with the
  /// reply's events, and remembers when DeskPlan built it. Events outside the
  /// window are kept.
  Future<void> replaceWindow(CalendarReply reply);

  /// Every cached event, soonest first.
  Future<List<CalendarEvent>> events();

  /// DeskPlan's clock at the last reply ("Timetable as of ..."), or null
  /// when nothing has been fetched.
  Future<DateTime?> asOf();

  /// Forgets every event (a DeskPlan without the calendar).
  Future<void> clear();

  /// Replaces the events this phone downloaded from one feed, and notes
  /// [fetchedAt] as "Timetable as of".
  Future<void> replaceFeed(
    String feedId,
    List<CalendarEvent> events,
    DateTime fetchedAt,
  );

  /// One feed's events, hidden courses included (to list its courses).
  Future<List<CalendarEvent>> feedEvents(String feedId);

  /// Forgets one feed's events (it was removed).
  Future<void> removeFeed(String feedId);

  /// Forgets the events DeskPlan sent (the phone downloads the feeds itself
  /// now, protocol.md section 5
  /// `/v1/feed-settings`).
  Future<void> clearFromPc();
}
