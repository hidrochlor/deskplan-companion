import 'package:flutter/material.dart';

import 'theme/deskplan_colors.dart';

/// A small heading over a group of the list ("OVERDUE   4"), with its count
/// at the right. Given [open], it folds: tap it to show or hide the group.
class SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  /// The label and count's colour (red for Overdue); `muted` / `faint` when
  /// null.
  final Color? color;

  /// Null: always open, no dropdown.
  final bool? open;
  final VoidCallback? onToggle;

  const SectionHeader({
    super.key,
    required this.label,
    required this.count,
    this.color,
    this.open,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final open = this.open;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(16, 14, open == null ? 16 : 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: color ?? c.muted,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color ?? c.faint,
            ),
          ),
          if (open != null) ...[
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.expand_more, size: 18, color: color ?? c.muted),
            ),
          ],
        ],
      ),
    );
    if (open == null) return header;
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(onTap: onToggle, child: header),
    );
  }
}
