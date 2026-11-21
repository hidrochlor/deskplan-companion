import '../connection/client_reply.dart';
import 'calendar_reply.dart';

/// What came of asking DeskPlan for its calendar.
sealed class CalendarResult {
  const CalendarResult();
}

class CalendarOk extends CalendarResult {
  final CalendarReply reply;
  const CalendarOk(this.reply);
}

/// `404`: a DeskPlan older than the calendar. Its events are hidden.
class CalendarUnsupported extends CalendarResult {
  const CalendarUnsupported();
}

/// The phone is blocked as a whole (not approved, receiving off, no longer
/// paired, cannot be reached).
class CalendarBlocked extends CalendarResult {
  final NoReply problem;
  const CalendarBlocked(this.problem);
}

/// Something that may clear up (`503`, say): tried again at the next sync,
/// like the pull. The cached events stay.
class CalendarFailed extends CalendarResult {
  final String reason;
  const CalendarFailed(this.reason);
}
