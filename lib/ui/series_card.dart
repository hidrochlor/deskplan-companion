import 'package:flutter/material.dart';

import '../core/repeats.dart';
import 'date_text.dart';
import 'theme/deskplan_colors.dart';

/// One repeating task, pinned at the top of the Tasks list: its title, how
/// it repeats, and its next occurrence with a tick for it. Its other
/// occurrences stay out of the list; tapping opens them all
/// (SeriesDetailsSheet).
class SeriesCard extends StatelessWidget {
  final TaskSeries series;
  final DateTime now;
  final VoidCallback onTap;

  /// Ticks the next occurrence off (its next copy then comes, as always).
  final VoidCallback onToggleDone;

  const SeriesCard({
    super.key,
    required this.series,
    required this.now,
    required this.onTap,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final latest = series.latest;
    final ended = series.ended(now);
    final rule = latest.repeat;
    final end = latest.end;
    final when = end == null ? null : DateText.slot(context, latest.start, end);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.accent.withValues(alpha: 0.28)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ended ? c.surface2 : c.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.repeat_rounded,
                    size: 20,
                    color: ended ? c.muted : c.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: ended ? c.muted : c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ended
                            ? 'Ended'
                            : [
                                if (when != null) 'Next $when',
                                if (rule != null) DateText.rule(context, rule),
                              ].join('  ·  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.muted),
                      ),
                    ],
                  ),
                ),
                if (!ended)
                  Checkbox(
                    value: latest.done,
                    shape: const CircleBorder(),
                    side: BorderSide(color: c.check, width: 1.6),
                    onChanged: (_) => onToggleDone(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_right, color: c.faint),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
