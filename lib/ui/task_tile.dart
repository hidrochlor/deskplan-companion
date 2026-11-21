import 'package:flutter/material.dart';

import '../core/task.dart';
import 'date_text.dart';
import 'source_badge.dart';
import 'task_countdown.dart';
import 'theme/deskplan_colors.dart';

/// One task in the Tasks list (assignments have their own card,
/// AssignmentCard): a round tick, the title, its time ("14:10–14:30"), the
/// course, and at the right how long until it needs you ("Starts in 3hrs",
/// "Due in 1hr", "Overdue 10hrs"). Red when overdue or within the hour, amber within a day,
/// grey later; red and amber cards get a coloured edge on the left.
class TaskTile extends StatelessWidget {
  final Task task;
  final DateTime now;

  /// The course it belongs to, if known (DeskPlan's `course`).
  final String? course;

  /// Put the day before the time ("Fri, Oct 30 · 10:59–11:59 PM"), under
  /// headings that are not one day (Overdue, Done).
  final bool showDay;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  const TaskTile({
    super.key,
    required this.task,
    required this.now,
    this.course,
    this.showDay = false,
    required this.onTap,
    required this.onToggleDone,
  });

  /// The time line, or null when the task has no time.
  String? _when(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final start = task.start, end = task.end;
    String day(DateTime t) =>
        showDay ? '${loc.formatMediumDate(t.toLocal())} · ' : '';
    String clock(DateTime t) => loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(t.toLocal()),
      alwaysUse24HourFormat: true,
    );
    if (start != null && end != null) {
      return DateUtils.isSameDay(start.toLocal(), end.toLocal())
          ? '${day(start)}${DateText.timeRange(context, start, end)}'
          : DateText.range(context, start, end);
    }
    if (end != null) return 'Due ${day(end)}${clock(end)}';
    // Old data only: DeskPlan no longer allows a start without an end.
    if (start != null) return 'Starts ${day(start)}${clock(start)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final countdown = TaskCountdown.of(task, now);
    final edge = switch (countdown?.tone) {
      TaskTone.red => c.danger,
      TaskTone.amber => c.warn,
      _ => null,
    };
    final when = _when(context);
    final source = task.sourceLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: edge == null
                ? null
                : BoxDecoration(
                    border: Border(left: BorderSide(color: edge, width: 3)),
                  ),
            padding: EdgeInsets.fromLTRB(edge == null ? 4 : 1, 4, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: task.done,
                  shape: const CircleBorder(),
                  side: BorderSide(color: c.check, width: 1.6),
                  onChanged: (_) => onToggleDone(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: task.done ? c.muted : c.text,
                                  decoration: task.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: c.muted,
                                ),
                              ),
                            ),
                            if (countdown != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                countdown.text,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: edge ?? c.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (when != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    when,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: c.muted,
                                    ),
                                  ),
                                ),
                                if (task.repeat case final rule?) ...[
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: rule.label,
                                    child: Icon(
                                      Icons.repeat,
                                      size: 14,
                                      semanticLabel: 'Repeats',
                                      color: c.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (course != null || source != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                if (course != null) ...[
                                  Icon(
                                    Icons.school_outlined,
                                    size: 14,
                                    color: c.muted,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    course ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: c.muted,
                                    ),
                                  ),
                                ),
                                if (source != null) SourceBadge(label: source),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
