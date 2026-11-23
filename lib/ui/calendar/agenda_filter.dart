import '../../features/calendar/calendar_event_kind.dart';
import 'calendar_entry.dart';

/// What the agenda can be narrowed to. With none picked it shows
/// everything; with some picked, only entries of those kinds (lectures and
/// other events then drop out).
enum AgendaFilter {
  tasks('Tasks'),
  assignments('Assignments'),
  exams('Exams');

  final String label;
  const AgendaFilter(this.label);

  /// Which filter [e] belongs to, or null for a lecture or another event.
  /// A step counts as its assignment, so it stays with it.
  static AgendaFilter? of(CalendarEntry e) {
    final event = e.event;
    if (event != null) {
      return event.kind == CalendarEventKind.exam ? exams : null;
    }
    final task = e.task!;
    return task.isAssignment || e.parentId != null ? assignments : tasks;
  }

  /// True when [e] is shown while [picked] are on.
  static bool shows(Set<AgendaFilter> picked, CalendarEntry e) =>
      picked.isEmpty || picked.contains(of(e));
}
