import '../connection/client_reply.dart';
import 'calendar_event.dart';
import 'calendar_result.dart';
import 'calendar_service.dart';
import 'calendar_store.dart';
import 'exam_reminders.dart';

/// What one calendar fetch did.
class CalendarOutcome {
  /// The cached events were replaced with DeskPlan's.
  final bool updated;

  /// DeskPlan is older than the calendar: its events were hidden.
  final bool unsupported;

  /// The phone is blocked as a whole (not approved, receiving off...).
  final NoReply? blocked;

  /// Why it did not complete; tried again at the next sync.
  final String? failure;

  const CalendarOutcome({
    this.updated = false,
    this.unsupported = false,
    this.blocked,
    this.failure,
  });
}

/// Keeps the phone's copy of DeskPlan's calendar (protocol.md section 5
/// "GET /v1/calendar"). Used only while the last ping listed `calendar`.
abstract class CalendarFetcher {
  /// Fetches the default window and replaces the cached events of it.
  Future<CalendarOutcome> fetch();

  /// DeskPlan no longer has the calendar: forget its events and their
  /// notifications.
  Future<void> hide();
}

/// The real [CalendarFetcher].
class ServerCalendarFetcher implements CalendarFetcher {
  final CalendarService _service;
  final CalendarStore _store;
  final ExamReminders _reminders;

  ServerCalendarFetcher(this._service, this._store, this._reminders);

  @override
  Future<CalendarOutcome> fetch() async {
    try {
      switch (await _service.fetch()) {
        case CalendarOk(:final reply):
          final before = await _store.events();
          await _store.replaceWindow(reply);
          await _setReminders(before, await _store.events());
          return const CalendarOutcome(updated: true);
        case CalendarUnsupported():
          await hide();
          return const CalendarOutcome(unsupported: true);
        case CalendarBlocked(:final problem):
          return CalendarOutcome(blocked: problem);
        case CalendarFailed(:final reason):
          return CalendarOutcome(failure: reason);
      }
    } catch (e) {
      return CalendarOutcome(failure: 'Could not keep the calendar: $e');
    }
  }

  @override
  Future<void> hide() async {
    final before = await _store.events();
    if (before.isEmpty && await _store.asOf() == null) return;
    await _store.clear();
    await _setReminders(before, const []);
  }

  /// Notifications are a bonus: a problem with them never loses the events.
  Future<void> _setReminders(
    List<CalendarEvent> before,
    List<CalendarEvent> now,
  ) async {
    try {
      await _reminders.replace(before, now);
    } catch (_) {}
  }
}
