import 'package:flutter/material.dart';

import '../../features/notes/note_block.dart';
import '../../features/notes/note_format.dart';
import '../theme/deskplan_colors.dart';
import 'editor_line.dart';

/// One line of the note page, drawn like DeskPlan's editor
/// (docs/DESIGN.md "Note page"): list lines indented 24 px per level with
/// the marker in a 26 px gutter, a checklist box that ticks on tap, and
/// parts the phone cannot edit in a read-only box.
class NoteLineView extends StatelessWidget {
  static const bodySize = 14.5;
  static const lineHeight = 1.65;

  final EditorLine line;
  final String? hint;
  final VoidCallback onToggleChecked;

  const NoteLineView({
    super.key,
    required this.line,
    required this.onToggleChecked,
    this.hint,
  });

  /// Plain writing, no box. The app's input theme fills text boxes and
  /// draws borders when enabled and focused; `InputDecoration.collapsed`
  /// only turns off the plain border, so each one is switched off here.
  static InputDecoration bare({String? hint, TextStyle? hintStyle}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: hintStyle,
        isCollapsed: true,
        filled: false,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      );

  TextStyle _style(DeskPlanColors c) {
    final ticked = line.type == NoteBlockType.task && line.checked;
    final base = TextStyle(
      fontSize: bodySize,
      height: lineHeight,
      color: ticked ? c.muted : c.text,
      decoration: ticked ? TextDecoration.lineThrough : null,
      decorationColor: c.faint,
    );
    return switch (line.type) {
      NoteBlockType.heading1 => base.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      NoteBlockType.heading2 => base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      _ => base,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    if (line.isRaw) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                NoteFormat.rawText(line.node),
                style: TextStyle(fontSize: 13, color: c.muted),
              ),
              const SizedBox(height: 2),
              Text(
                'Edit this part on your PC',
                style: TextStyle(fontSize: 11, color: c.faint),
              ),
            ],
          ),
        ),
      );
    }

    final isList = line.type.isList;
    final field = TextField(
      controller: line.controller,
      focusNode: line.focus,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: _style(c),
      cursorColor: c.accent,
      decoration: bare(
        hint: hint,
        hintStyle: TextStyle(color: c.faint, fontSize: NoteLineView.bodySize),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: line.type == NoteBlockType.heading1
            ? 14
            : line.type == NoteBlockType.heading2
            ? 10
            : 2,
        left: isList ? line.indent * 24.0 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isList) SizedBox(width: 26, child: _marker(c)),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget _marker(DeskPlanColors c) {
    const lineBox = bodySize * lineHeight;
    if (line.type == NoteBlockType.task) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggleChecked,
        child: SizedBox(
          height: lineBox,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 15,
              height: 15,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: line.checked
                    ? c.accent
                    : c.muted.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  width: 1.6,
                  color: line.checked
                      ? c.accent
                      : c.muted.withValues(alpha: 0.85),
                ),
              ),
              child: line.checked
                  ? Icon(Icons.check, size: 11, color: c.onAccent)
                  : null,
            ),
          ),
        ),
      );
    }
    // A dot at level 0, a ring at odd levels, a small square at even ones.
    final level = line.indent;
    final ring = level.isOdd;
    final square = level > 0 && level.isEven;
    return SizedBox(
      height: lineBox,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(left: 9),
          decoration: BoxDecoration(
            color: ring ? null : c.muted,
            border: ring ? Border.all(color: c.muted, width: 1.5) : null,
            shape: square ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: square ? BorderRadius.circular(1) : null,
          ),
        ),
      ),
    );
  }
}
