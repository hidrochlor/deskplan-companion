import 'package:flutter/material.dart';

import '../clash_notice.dart';

import '../../features/calendar/calendar_event.dart';
import '../../features/calendar/calendar_event_kind.dart';
import '../date_text.dart';
import '../theme/deskplan_colors.dart';
import '../../features/calendar/exam_dates.dart';
import 'calendar_entry.dart';
import 'course_sessions.dart';
import 'course_timetable_screen.dart';

/// The details of a feed event. Read-only: it has no edit or delete, because
/// it belongs to the feed on the PC (protocol.md section 5). An exam with
/// several dates says which one this is, and can be marked as the date
/// registered for (kept on the phone; the feed does not know it).
class EventDetailsSheet extends StatefulWidget {
  final CalendarEvent event;

  /// Every cached event, to offer the course's whole timetable. Null hides
  /// that button (the sheet is opened from the course timetable itself).
  final List<CalendarEvent>? all;

  /// How it sits against the day's other blocks, when opened from the
  /// calendar.
  final List<String> clashes;

  /// The exam dates and which one is registered for.
  final ExamDates exams;

  /// Marks this exam date as registered for (true) or not. Null hides the
  /// switch.
  final Future<void> Function(CalendarEvent event, bool registered)? onRegister;

  const EventDetailsSheet({
    super.key,
    required this.event,
    this.all,
    this.clashes = const [],
    this.exams = ExamDates.none,
    this.onRegister,
  });

  static Future<void> show(
    BuildContext context,
    CalendarEvent event, {
    List<CalendarEvent>? all,
    List<String> clashes = const [],
    ExamDates exams = ExamDates.none,
    Future<void> Function(CalendarEvent event, bool registered)? onRegister,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Up to nearly full height, scrolling when it is taller (an exam with
    // its dates and the Registered switch).
    isScrollControlled: true,
    builder: (_) => EventDetailsSheet(
      event: event,
      all: all,
      clashes: clashes,
      exams: exams,
      onRegister: onRegister,
    ),
  );

  @override
  State<EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<EventDetailsSheet> {
  late bool _registered = widget.exams.isRegistered(widget.event);

  Future<void> _setRegistered(bool on) async {
    setState(() => _registered = on);
    await widget.onRegister?.call(widget.event, on);
  }

  /// "Jan 18, Mar 2": this exam's other dates.
  String _otherDates(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final key = ExamDates.keyOf(widget.event);
    return ([
          for (final e in widget.all ?? const <CalendarEvent>[])
            if (e.kind == CalendarEventKind.exam &&
                e.id != widget.event.id &&
                ExamDates.keyOf(e) == key)
              e,
        ]..sort((a, b) => a.start.compareTo(b.start)))
        .map((e) => loc.formatShortMonthDay(e.start.toLocal()))
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final all = widget.all;
    final clashes = widget.clashes;
    final c = DeskPlanColors.of(context);
    final color = CalendarEntry.ofEvent(event).color;
    final past = event.isPast(DateTime.now());
    final moment = event.start == event.end;
    final events = all;
    final course = events == null || event.kind == CalendarEventKind.event
        ? null
        : CourseSessions.of(event.courseName, events);
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: c.text)),
          ),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.kind.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (past) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Past',
                      style: TextStyle(fontSize: 12, color: c.faint),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                event.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              line(
                Icons.schedule,
                moment
                    ? DateText.when(context, event.start)
                    : DateText.range(context, event.start, event.end),
              ),
              if (event.context.isNotEmpty)
                line(Icons.info_outline, event.context),
              if (widget.exams.labelOf(event) case final date?)
                line(
                  Icons.event_repeat,
                  '$date · also ${_otherDates(context)}',
                ),
              if (widget.onRegister != null &&
                  event.kind == CalendarEventKind.exam)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Registered for this date'),
                    subtitle: Text(
                      (widget.exams.numberOf(event)?.$2 ?? 1) > 1
                          ? 'The other dates of this exam are dimmed and '
                                'get no reminder'
                          : 'Only on this phone',
                      style: TextStyle(fontSize: 12.5, color: c.muted),
                    ),
                    value: _registered,
                    onChanged: _setRegistered,
                  ),
                ),
              ClashNotice(lines: clashes),
              if (course != null && course.sessions.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_view_week_outlined),
                    label: Text(
                      course.sessions.length == 1
                          ? 'See the course timetable'
                          : 'See all ${course.sessions.length} sessions',
                    ),
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute<void>(
                          builder: (_) => CourseTimetableScreen(course: course),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: c.faint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'From your calendar feeds on DeskPlan. Read-only here.',
                      style: TextStyle(fontSize: 12.5, color: c.faint),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
