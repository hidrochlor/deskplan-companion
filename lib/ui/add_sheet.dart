import 'package:flutter/material.dart';

import 'theme/deskplan_colors.dart';

/// What the "+" button can add.
enum AddChoice { task, assignment, note, files }

/// The menu that slides up from the "+" button: a task, an assignment, a
/// note, or files and photos to send to DeskPlan. Pops with the
/// [AddChoice], or null if dismissed.
class AddSheet extends StatelessWidget {
  /// An assignment lives in a folder on the PC, so it can only be offered
  /// once the phone has seen the PC's folders.
  final bool assignmentAvailable;

  /// Notes are offered only while DeskPlan syncs them (its ping lists
  /// `notes`).
  final bool noteAvailable;

  const AddSheet({
    super.key,
    required this.assignmentAvailable,
    this.noteAvailable = false,
  });

  static Future<AddChoice?> show(
    BuildContext context, {
    required bool assignmentAvailable,
    bool noteAvailable = false,
  }) => showModalBottomSheet<AddChoice>(
    context: context,
    showDragHandle: true,
    builder: (_) => AddSheet(
      assignmentAvailable: assignmentAvailable,
      noteAvailable: noteAvailable,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Add',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            _Option(
              icon: Icons.check_box_outlined,
              color: c.accent,
              title: 'Task',
              subtitle: 'Something to do, from a start time to an end time',
              onTap: () => Navigator.pop(context, AddChoice.task),
            ),
            _Option(
              icon: Icons.assignment_outlined,
              color: DeskPlanColors.assignmentKind,
              title: 'Assignment',
              subtitle: assignmentAvailable
                  ? 'Has a submission deadline, and steps'
                  : 'Connect to DeskPlan once, to choose its folder',
              onTap: assignmentAvailable
                  ? () => Navigator.pop(context, AddChoice.assignment)
                  : null,
            ),
            if (noteAvailable)
              _Option(
                icon: Icons.sticky_note_2_outlined,
                color: DeskPlanColors.noteKind,
                title: 'Note',
                subtitle:
                    'Headings, lists and checklists, shared with DeskPlan',
                onTap: () => Navigator.pop(context, AddChoice.note),
              ),
            _Option(
              icon: Icons.attach_file,
              color: c.muted,
              title: 'Files & photos',
              subtitle: 'Sent to DeskPlan on your PC',
              onTap: () => Navigator.pop(context, AddChoice.files),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the menu: a coloured icon tile, a title and a short line.
class _Option extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _Option({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}
