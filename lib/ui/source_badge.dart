import 'package:flutter/material.dart';

import 'theme/deskplan_colors.dart';

/// The small "Moodle" pill on an item imported from a calendar feed
/// (protocol.md section 4 "Imported assignments"): at the end of an
/// assignment card, and in its sheet.
class SourceBadge extends StatelessWidget {
  /// The feed's name, `source.label`.
  final String label;

  const SourceBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_download_outlined, size: 12, color: c.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}
