import 'package:flutter/material.dart';

import '../theme/deskplan_colors.dart';
import 'calendar_entry.dart';

/// An assignment on its due day, with its steps living inside it: the due
/// time, the title, its label ("Assignment · WS 2026", then "· Missed" in
/// red), and at the right the steps done ("3/4") over a chevron. Tapping
/// the row opens the assignment; the chevron shows every step, whatever
/// day it is on.
class StepGroupRow extends StatelessWidget {
  final CalendarEntry assignment;

  /// All its steps, soonest first.
  final List<CalendarEntry> steps;
  final DateTime now;
  final bool open;

  /// A step overlaps something else on its day.
  final bool clashes;

  /// Shows or hides the steps.
  final VoidCallback onToggle;

  /// Opens the assignment.
  final VoidCallback onOpen;

  const StepGroupRow({
    super.key,
    required this.assignment,
    required this.steps,
    required this.now,
    required this.open,
    required this.clashes,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final loc = MaterialLocalizations.of(context);
    final a = assignment;
    final n = steps.length;
    final done = steps.where((s) => s.task?.done ?? false).length;
    final missedSteps = steps.where((s) => s.missed(now)).length;
    final missed = a.missed(now)
        ? ' · Missed'
        : missedSteps > 0
        ? ' · $missedSteps missed'
        : null;
    final allDim = a.dimmed(now) && steps.every((s) => s.dimmed(now));
    final due = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(a.end.toLocal()),
      alwaysUse24HourFormat: true,
    );
    return Opacity(
      opacity: allDim ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: a.color),
                  SizedBox(
                    width: 74,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 11, 4, 11),
                      child: Text(
                        'Due\n$due',
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
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            a.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              text: a.label,
                              children: [
                                if (missed != null)
                                  TextSpan(
                                    text: missed,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: c.danger,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (clashes && !open)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.error_outline,
                        size: 16,
                        color: c.muted,
                        semanticLabel: 'A step overlaps something',
                      ),
                    ),
                  // The steps done over the chevron: only this shows them.
                  InkWell(
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$done/$n',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: done == n ? c.ok : c.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Icon(
                            open ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: c.muted,
                            semanticLabel: open ? 'Hide steps' : 'Show steps',
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
      ),
    );
  }
}
