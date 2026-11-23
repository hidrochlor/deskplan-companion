import 'package:flutter/material.dart';

import 'theme/deskplan_colors.dart';

/// What an item overlaps that day ("Starts 15m before Lecture ends"),
/// shown at the top of its sheet when opened from
/// the calendar.
class ClashNotice extends StatelessWidget {
  final List<String> lines;

  const ClashNotice({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final c = DeskPlanColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: c.muted.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final text in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: c.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 13, color: c.text),
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
