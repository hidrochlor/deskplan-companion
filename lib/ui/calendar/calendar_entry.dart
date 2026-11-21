import 'package:flutter/material.dart';

import '../../core/repeats.dart';
import '../../core/task.dart';
import '../../core/task_tree.dart';
import '../../features/calendar/calendar_event.dart';
import '../../features/calendar/calendar_event_kind.dart';
import '../course_names.dart';

/// One thing on the calendar: one of the phone's own items that has an end,
/// or a read-only event from DeskPlan's feeds. Times are UTC instants; a
/// moment (a due time) has [start] equal to [end].
class CalendarEntry {
  final String title;

  /// The kind label and context: "Lecture · VO · Online · Sumereder
  /// Christof" or "Assignment · Climate Change and Dynamics".
  final String label;
  final DateTime start;
  final DateTime end;
  final Color color;

  /// A due time rather than something that runs from start to end.
  final bool isDue;

  /// Set for the phone's own item (tap opens it as today).
  final Task? task;

  /// Set for a feed event (tap shows its details, read-only).
  final CalendarEvent? event;

  /// A coming occurrence of a repeating task, not stored yet.
  final bool projected;

  const CalendarEntry._({
    required this.title,
    required this.label,
    required this.start,
    required this.end,
    required this.color,
    this.isDue = false,
    this.task,
    this.event,
    this.projected = false,
  });

  /// The PC's calendar colours (DESIGN.md, "Calendar colours"). The same in
  /// both themes.
  static const lectureColor = Color(0xFF5C9CE6);
  static const examColor = Color(0xFFFF5C7A);
  static const eventColor = Color(0xFF8B90A3);
  static const assignmentColor = Color(0xFFFF7A8A);
  static const taskColor = Color(0xFF7C8CFF);

  factory CalendarEntry.ofEvent(CalendarEvent e) => CalendarEntry._(
    title: e.title,
    label: e.label,
    start: e.start,
    end: e.end,
    color: switch (e.kind) {
      CalendarEventKind.lecture => lectureColor,
      CalendarEventKind.exam => examColor,
      CalendarEventKind.event => eventColor,
    },
    event: e,
  );

  /// Dimmed: a past event (it counts as done), or a finished item.
  bool dimmed(DateTime now) =>
      event != null ? event!.isPast(now) : !projected && task!.done;

  /// The entries for the phone's items: assignments and deadline tasks at
  /// their end, time blocks and steps from start to end. Notes have no times.
  static List<CalendarEntry> ofItems(
    List<Task> items,
    TaskTree tree,
    CourseNames courses,
  ) {
    final entries = <CalendarEntry>[];
    for (final t in items) {
      final end = t.end;
      if (t.isNote || end == null) continue;
      final course = courses.of(t);
      final step = tree.isStep(t);
      final kind = t.isAssignment ? 'Assignment' : (step ? 'Step' : 'Task');
      final start = t.isAssignment ? null : t.start;
      // Old data may hold a start after its end: show it as a due time.
      final block = start != null && start.isBefore(end);
      entries.add(
        CalendarEntry._(
          title: t.title,
          label: course == null ? kind : '$kind · $course',
          start: block ? start : end,
          end: end,
          isDue: !block,
          color: t.isAssignment ? assignmentColor : taskColor,
          task: t,
        ),
      );
    }
    return entries;
  }

  /// The occurrences of a repeating task still to come, up to [horizon]:
  /// not stored yet (each is made when the one before it ends), shown so
  /// the week ahead is complete. Tapping one opens the series, through its
  /// latest copy in [task].
  static List<CalendarEntry> ofSeries(
    TaskSeries series,
    CourseNames courses, {
    required DateTime horizon,
  }) {
    final latest = series.latest;
    final course = courses.of(latest);
    return [
      for (final t in series.upcoming(max: 400, horizon: horizon))
        CalendarEntry._(
          title: latest.title,
          label: course == null ? 'Task' : 'Task · $course',
          start: t.start != null && t.start!.isBefore(t.end) ? t.start! : t.end,
          end: t.end,
          isDue: t.start == null || !t.start!.isBefore(t.end),
          color: taskColor,
          task: latest,
          projected: true,
        ),
    ];
  }

  /// True when this touches the local day that starts at [dayStart].
  bool isOn(DateTime dayStart) {
    final next = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
    final s = start.toLocal();
    final e = end.toLocal();
    if (s == e || isDue) return !s.isBefore(dayStart) && s.isBefore(next);
    return s.isBefore(next) && e.isAfter(dayStart);
  }

  /// Soonest first; on a tie the longer one first.
  static int compare(CalendarEntry a, CalendarEntry b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : b.end.compareTo(a.end);
  }
}
