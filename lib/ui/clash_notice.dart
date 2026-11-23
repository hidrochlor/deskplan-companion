import 'package:flutter/material.dart';

import 'theme/deskplan_colors.dart';

/// How an item sits against the other blocks that day, shown at the top of
/// its sheet when opened from the calendar: (text, overlaps). An overlap
/// ("Starts 15m after Lecture starts, ...") is in the warning colour, a near one
/// ("Starts 30m after Lab ends") is muted.
class ClashNotice extends StatelessWidget {
  final List<(String, bool)> lines;

  const ClashNotice({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final c = DeskPlanColors.of(context);
    final clash = lines.any((l) => l.$2);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: (clash ? c.warn : c.muted).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (text, overlaps) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    overlaps
                        ? Icons.warning_amber_rounded
                        : Icons.arrow_forward_rounded,
                    size: 16,
                    color: overlaps ? c.warn : c.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        color: overlaps ? c.warn : c.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
