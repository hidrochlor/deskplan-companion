import 'package:flutter/material.dart';

import '../core/task_kind.dart';
import 'theme/deskplan_colors.dart';

/// The small "Task", "Assignment" or "Note" label on a row, in the item's
/// own colour (docs/DESIGN.md "Item kind colours"), so they read
/// differently at a glance, like on DeskPlan's list.
class KindChip extends StatelessWidget {
  final TaskKind kind;

  const KindChip({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final (color, label) = switch (kind) {
      TaskKind.task => (c.accent, 'Task'),
      TaskKind.assignment => (DeskPlanColors.assignmentKind, 'Assignment'),
      TaskKind.note => (DeskPlanColors.noteKind, 'Note'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
