import 'package:flutter/material.dart';

import '../../features/calendar/calendar_event.dart';
import '../../features/calendar/calendar_event_kind.dart';
import '../date_text.dart';
import '../theme/deskplan_colors.dart';
import 'calendar_entry.dart';
import 'course_sessions.dart';
import 'event_details_sheet.dart';

/// One course's whole timetable: the weekly slots it meets in, then every
/// lecture and exam month by month. Past sessions are dimmed and the next
/// one is marked.
class CourseTimetableScreen extends StatelessWidget {
  final CourseSessions course;

  /// For tests: the moment taken as now.
  final DateTime Function() now;

  const CourseTimetableScreen({
    super.key,
    required this.course,
    this.now = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final at = now();
    final next = course.next(at);
    final left = course.sessions.where((e) => !e.isPast(at)).length;
    final lectures = course.lectures.length;
    final exams = course.exams.length;
    final slots = course.weekly;
    final irregular = course.irregular;
    final loc = MaterialLocalizations.of(context);

    final children = <Widget>[
      Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                '$lectures ${lectures == 1 ? 'lecture' : 'lectures'}',
                if (exams > 0) '$exams ${exams == 1 ? 'exam' : 'exams'}',
                '$left still to come',
              ].join(' · '),
              style: TextStyle(fontSize: 13, color: c.muted),
            ),
            const SizedBox(height: 10),
            if (slots.isEmpty)
              Text(
                'No weekly pattern: the dates are listed below.',
                style: TextStyle(fontSize: 14, color: c.text),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in slots)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CalendarEntry.lectureColor.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${s.label}  ×${s.count}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            if (slots.isNotEmpty && irregular > 0) ...[
              const SizedBox(height: 8),
              Text(
                '+ $irregular at other times',
                style: TextStyle(fontSize: 12.5, color: c.muted),
              ),
            ],
          ],
        ),
      ),
    ];

    int? month;
    for (final e in course.sessions) {
      final local = e.start.toLocal();
      final key = local.year * 12 + local.month;
      if (key != month) {
        month = key;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              loc.formatMonthYear(local),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.muted,
              ),
            ),
          ),
        );
      }
      children.add(
        _SessionRow(
          event: e,
          past: e.isPast(at),
          next: identical(e, next),
          onTap: () => EventDetailsSheet.show(context, e),
        ),
      );
    }
    if (course.sessions.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No sessions of this course in the timetable.',
            style: TextStyle(color: c.muted),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(course.course)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: children,
      ),
    );
  }
}

/// One session: the date, the time and the room or lecturer. The next one
/// is marked "Next"; past ones are dimmed.
class _SessionRow extends StatelessWidget {
  final CalendarEvent event;
  final bool past;
  final bool next;
  final VoidCallback onTap;

  const _SessionRow({
    required this.event,
    required this.past,
    required this.next,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final color = CalendarEntry.ofEvent(event).color;
    final local = event.start.toLocal();
    final loc = MaterialLocalizations.of(context);
    final exam = event.kind == CalendarEventKind.exam;
    final time = event.start == event.end
        ? loc.formatTimeOfDay(
            TimeOfDay.fromDateTime(local),
            alwaysUse24HourFormat: true,
          )
        : DateText.timeRange(context, event.start, event.end);
    return Opacity(
      opacity: past ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: next ? c.surface2 : c.surface,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: color),
                  SizedBox(
                    width: 56,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${local.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        Text(
                          _weekday(local.weekday),
                          style: TextStyle(fontSize: 11.5, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  exam ? 'Exam · $time' : time,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: exam
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: exam ? color : c.text,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              if (next) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.accentSoft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Next',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: c.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (event.context.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.context,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: c.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _weekday(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}
