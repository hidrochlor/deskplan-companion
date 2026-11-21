import 'package:flutter/material.dart';

import '../../core/task.dart';
import '../../features/notes/note_block.dart';
import '../../features/notes/note_format.dart';
import '../date_text.dart';
import '../progress_count.dart';
import '../theme/deskplan_colors.dart';

/// A note's properties, like the info DeskPlan shows for one: where it is,
/// its course, when it was made and last changed, and how long it is.
/// Read-only; the place is changed with Move.
class NoteDetailsSheet extends StatelessWidget {
  final Task note;

  /// Where it sits, as a path from Home ("Home › CSC101 › Week 1").
  final String place;

  /// The course it belongs to, if any.
  final String? course;

  const NoteDetailsSheet({
    super.key,
    required this.note,
    required this.place,
    this.course,
  });

  static Future<void> show(
    BuildContext context, {
    required Task note,
    required String place,
    String? course,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => NoteDetailsSheet(note: note, place: place, course: course),
  );

  /// Words in the plain text: runs of letters or digits.
  static int wordCount(String text) => RegExp(
    r"[\p{L}\p{N}][\p{L}\p{N}'’\-]*",
    unicode: true,
  ).allMatches(text).length;

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final blocks = NoteFormat.toBlocks(note.doc);
    // The words themselves, without the "- " and "[x] " list markers.
    final text = blocks
        .map(
          (b) =>
              b.type == NoteBlockType.raw ? NoteFormat.rawText(b.node) : b.text,
        )
        .join('\n');
    final stats = NoteFormat.checklistStats(note.doc);
    final headings = blocks.where((b) => b.type.isHeading).length;
    final chars = text.replaceAll('\n', '').length;

    Widget row(
      IconData icon,
      String label,
      String value, {
      bool oneLine = false,
      Color? valueColor,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.muted),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Text(label, style: TextStyle(fontSize: 13, color: c.muted)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: oneLine ? 1 : null,
              softWrap: !oneLine,
              overflow: oneLine ? TextOverflow.ellipsis : null,
              style: TextStyle(fontSize: 13.5, color: valueColor ?? c.text),
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              note.title.isEmpty ? 'Untitled' : note.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.muted),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: c.borderSoft),
            const SizedBox(height: 6),
            // The path from Home down, as far as it fits, then "…".
            row(Icons.folder_open, 'Location', place, oneLine: true),
            if (course != null) row(Icons.school_outlined, 'Course', course!),
            row(
              Icons.add_circle_outline,
              note.createdKnown ? 'Created' : 'First seen',
              DateText.when(context, note.createdAt),
            ),
            row(
              Icons.edit_calendar_outlined,
              'Last changed',
              DateText.when(context, note.updatedAt),
            ),
            row(Icons.notes, 'Words', '${wordCount(text)}'),
            row(Icons.text_fields, 'Characters', '$chars'),
            if (headings > 0) row(Icons.title, 'Headings', '$headings'),
            if (!stats.isEmpty)
              row(
                Icons.checklist,
                'Checklist',
                '${stats.done} of ${stats.total} ticked',
                valueColor: ProgressCount.colorOf(c, stats, c.text),
              ),
            if (!note.createdKnown)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'The creation time comes from your PC after the next sync.',
                  style: TextStyle(fontSize: 12, color: c.faint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
