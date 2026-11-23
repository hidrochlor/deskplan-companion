import 'package:flutter/material.dart';

import '../theme/deskplan_colors.dart';
import 'calendar_entry.dart';

/// Several steps of one assignment on one day, folded into one row: the
/// time span they cover, "4 steps · Essay", how many are done, and a
/// chevron. Tapping it unfolds (or folds) the steps beneath it.
class StepGroupRow extends StatelessWidget {
  final List<CalendarEntry> steps;
  final String title;
  final DateTime day;
  final DateTime now;
  final bool open;

  /// A step overlaps something else that day.
  final bool clashes;
  final VoidCallback onTap;

  const StepGroupRow({
    super.key,
    required this.steps,
    required this.title,
    required this.day,
    required this.now,
    required this.open,
    required this.clashes,
    required this.onTap,
  });

  String _span(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    String hm(DateTime t) => loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(t.toLocal()),
      alwaysUse24HourFormat: true,
    );
    final next = DateTime(day.year, day.month, day.day + 1);
    var first = steps.first.start.toLocal();
    var last = steps.first.end.toLocal();
    for (final s in steps) {
      if (s.start.toLocal().isBefore(first)) first = s.start.toLocal();
      if (s.end.toLocal().isAfter(last)) last = s.end.toLocal();
    }
    if (first.isBefore(day)) first = day;
    final to = last.isBefore(next) ? hm(last) : 'onward';
    return first == last ? hm(first) : '${hm(first)}\n$to';
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final done = steps.where((s) => s.task?.done ?? false).length;
    final allDone = done == steps.length;
    return Opacity(
      opacity: allDone ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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
                  Container(width: 4, color: steps.first.color),
                  SizedBox(
                    width: 74,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 11, 4, 11),
                      child: Text(
                        _span(context),
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
                      padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${steps.length} steps · $title',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '$done of ${steps.length} done',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.muted,
                                ),
                              ),
                              if (clashes && !open) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 13,
                                  color: c.warn,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Overlaps',
                                  style: TextStyle(fontSize: 12, color: c.warn),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      color: c.muted,
                      semanticLabel: open ? 'Hide steps' : 'Show steps',
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
