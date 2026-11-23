import 'package:flutter/material.dart';

import '../theme/deskplan_colors.dart';
import 'calendar_entry.dart';

/// One entry in a day's list: a colour bar in the kind's colour, the time
/// on the left, then the title and its kind label and context. Past events
/// and finished items are dimmed.
class CalendarEntryRow extends StatelessWidget {
  final CalendarEntry entry;

  /// The local day this row is shown under, to say "All day" or where a
  /// long entry starts or ends.
  final DateTime day;
  final DateTime now;
  final VoidCallback onTap;

  /// What it overlaps that day ("Starts 15m before Lecture ends").
  final List<String> relations;

  /// Indented, as a step inside its unfolded assignment: no "Step · course"
  /// line (the assignment above says it), and the date when it is on
  /// another day than [day] ("Nov 20\n12:00").
  final bool nested;

  const CalendarEntryRow({
    super.key,
    required this.entry,
    required this.day,
    required this.now,
    required this.onTap,
    this.relations = const [],
    this.nested = false,
  });

  String _time(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    String hm(DateTime t) => loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(t.toLocal()),
      alwaysUse24HourFormat: true,
    );
    final next = DateTime(day.year, day.month, day.day + 1);
    final s = entry.start.toLocal();
    final e = entry.end.toLocal();
    if (nested && !DateUtils.isSameDay(s, day)) {
      return '${loc.formatShortMonthDay(s)}\n${hm(s)}';
    }
    if (entry.isDue) return 'Due\n${hm(s)}';
    if (s == e) return hm(s);
    final startsBefore = s.isBefore(day);
    final endsAfter = !e.isBefore(next);
    if (startsBefore && endsAfter) return 'All day';
    if (startsBefore) return 'until\n${hm(e)}';
    if (endsAfter) return '${hm(s)}\nonward';
    return '${hm(s)}\n${hm(e)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final dim = entry.dimmed(now);
    final missed = entry.missed(now);
    // An exam that has several dates, or is marked: its label is built here.
    final exam = entry.examDate != null || entry.registered
        ? entry.event
        : null;
    final done = !entry.projected && (entry.task?.done ?? false);
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(nested ? 28 : 12, 3, 12, 3),
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: entry.color),
                  SizedBox(
                    width: 74,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 11, 4, 11),
                      child: Text(
                        _time(context),
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: c.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                              decoration: done && !entry.task!.isAssignment
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          // "Task · WS 2026 · Missed", the last part in red;
                          // a step inside its assignment only says "Missed".
                          // An exam says which date it is right after
                          // "Exam", before the room, so it is not cut off:
                          // "Exam · Registered · Date 1 of 3 · WS46a…".
                          if (!nested || missed) ...[
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                text: nested
                                    ? ''
                                    : exam == null
                                    ? entry.label
                                    : exam.kind.label,
                                children: [
                                  if (entry.registered)
                                    TextSpan(
                                      text: ' · Registered',
                                      style: TextStyle(
                                        color: c.ok,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (entry.examDate case final date?)
                                    TextSpan(text: ' · $date'),
                                  if (exam != null && exam.context.isNotEmpty)
                                    TextSpan(text: ' · ${exam.context}'),
                                  if (missed)
                                    TextSpan(
                                      text: nested ? 'Missed' : ' · Missed',
                                      style: TextStyle(
                                        color: c.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: c.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // A clash: open it to see what with.
                  if (relations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.error_outline,
                        size: 16,
                        color: c.muted,
                        semanticLabel: 'Overlaps something',
                      ),
                    ),
                  // A repeating task, on its stored days and the ones to come.
                  if (entry.task?.repeat != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.repeat_rounded,
                        size: 14,
                        color: c.faint,
                        semanticLabel: 'Repeats',
                      ),
                    ),
                  if (entry.event != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: c.faint,
                        semanticLabel: 'Read-only',
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
}
