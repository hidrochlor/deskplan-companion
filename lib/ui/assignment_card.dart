import 'package:flutter/material.dart';

import '../core/due_urgency.dart';
import '../core/task.dart';
import '../core/progress.dart';
import 'countdown.dart';
import 'date_text.dart';
import 'progress_count.dart';
import 'source_badge.dart';
import 'theme/deskplan_colors.dart';

/// One assignment in the Assignments list, countdown first: how long is left
/// (coloured by urgency, docs/DESIGN.md "Due dates") with the due day and
/// time on the right, then the title, the course, and the steps done with
/// the source pill ("Moodle") at the end. Overdue and due-within-a-day cards
/// get a coloured edge on the left. A submitted one says so in `ok` and its
/// title is struck through.
class AssignmentCard extends StatelessWidget {
  final Task task;
  final DateTime now;

  /// The course it belongs to, if known (DeskPlan's `course`).
  final String? course;

  /// How many steps are finished.
  final Progress? progress;
  final VoidCallback onTap;

  const AssignmentCard({
    super.key,
    required this.task,
    required this.now,
    this.course,
    this.progress,
    required this.onTap,
  });

  /// The countdown's colour, and the left edge's (null: no edge).
  (Color, Color?) _urgency(DeskPlanColors c) {
    final end = task.end;
    if (task.done) return (c.ok, null);
    if (end == null) return (c.muted, null);
    return switch (DueUrgency.of(end, now)) {
      DueUrgency.overdue => (c.danger, c.danger),
      DueUrgency.within24Hours => (c.warn, c.warn),
      DueUrgency.withinWeek => (c.text, null),
      DueUrgency.later => (c.muted, null),
    };
  }

  String get _countdown {
    if (task.done) return 'Submitted';
    final end = task.end;
    return end == null ? 'No due date' : Countdown.of(end, now);
  }

  /// A small icon and text, for the course and the steps.
  Widget _line(IconData icon, String text, Color color) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: color),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final (tone, edge) = _urgency(c);
    final steps = progress ?? Progress.none;
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
            padding: EdgeInsets.fromLTRB(edge == null ? 14 : 11, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _countdown,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: tone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (task.end case final end?)
                      Expanded(
                        child: Text(
                          DateText.dayAndTime(context, end),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.faint),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: task.done ? c.muted : c.text,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    decorationColor: c.muted,
                  ),
                ),
                if (course != null) ...[
                  const SizedBox(height: 4),
                  _line(Icons.school_outlined, course!, c.muted),
                ],
                if (task.repeat case final rule?) ...[
                  const SizedBox(height: 4),
                  _line(Icons.repeat, rule.label, c.muted),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: steps.isEmpty
                          ? _line(Icons.checklist, 'No steps yet', c.muted)
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: ProgressCount(
                                progress: steps,
                                suffix: 'steps done',
                                color: c.muted,
                                fontSize: 12.5,
                              ),
                            ),
                    ),
                    if (task.sourceLabel case final label?) ...[
                      const SizedBox(width: 8),
                      SourceBadge(label: label),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
