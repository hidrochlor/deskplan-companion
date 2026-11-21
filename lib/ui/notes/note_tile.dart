import 'package:flutter/material.dart';

import '../../core/task.dart';
import '../../features/notes/note_format.dart';
import '../date_text.dart';
import '../progress_count.dart';
import '../theme/deskplan_colors.dart';

/// One note in the notes list (docs/DESIGN.md "Note row"): where it sits on
/// top ("● Learn Basics › CSC101"), the title, two lines of its text, when
/// it was last edited, and how much of its checklist is ticked at the bottom
/// right, green once all of it is.
class NoteTile extends StatelessWidget {
  final Task note;

  /// The folders down to where it sits ("CSC101 › Week 1"), if known; null
  /// at the top level of Home.
  final String? place;
  final VoidCallback onTap;

  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    this.place,
  });

  /// The note's text, without empty lines.
  String get _preview {
    final text = note.details.isNotEmpty
        ? note.details
        : NoteFormat.toPlainText(note.doc);
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }

  /// The path, the last part (where it sits) brighter than the ones above.
  Widget _place(DeskPlanColors c, String place) {
    final parts = place.split(' › ');
    final above = parts.length > 1
        ? '${parts.sublist(0, parts.length - 1).join(' › ')} › '
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: DeskPlanColors.noteKind,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: above,
                    style: TextStyle(color: c.faint),
                  ),
                  TextSpan(
                    text: parts.last,
                    style: TextStyle(
                      color: c.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final preview = _preview;
    final stats = NoteFormat.checklistStats(note.doc);
    final place = this.place;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (place != null) _place(c, place),
                Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: note.title.isEmpty ? c.faint : c.text,
                  ),
                ),
                if (preview.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: c.muted,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Edited '
                          '${DateText.edited(context, note.updatedAt, DateTime.now())}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: c.faint),
                        ),
                      ),
                      if (!stats.isEmpty) ProgressCount(progress: stats),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
