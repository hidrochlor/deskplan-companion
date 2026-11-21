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

  const CalendarEntryRow({
    super.key,
    required this.entry,
    required this.day,
    required this.now,
    required this.onTap,
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
    final done = !entry.projected && (entry.task?.done ?? false);
    return Opacity(
      opacity: dim ? 0.5 : 1,
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
                          const SizedBox(height: 2),
                          Text(
                            entry.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: c.muted),
                          ),
                        ],
                      ),
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
