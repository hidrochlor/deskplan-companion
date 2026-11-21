import 'package:flutter/widgets.dart';

import '../../features/notes/inline_run.dart';
import '../../features/notes/note_block.dart';
import 'styled_line_controller.dart';

/// One line while the note is open: what it is, and (unless it is a part
/// the phone cannot edit) its text box.
class EditorLine {
  static int _nextId = 0;

  /// Stays the same while the line lives, so its widget is kept as lines
  /// come and go above it.
  final int id = _nextId++;

  NoteBlockType type;
  int indent;
  bool checked;

  /// Null for a `raw` line.
  final StyledLineController? controller;
  final FocusNode? focus;

  /// For a `raw` line: the node, kept untouched.
  final Map<String, Object?>? node;

  EditorLine._(
    this.type, {
    this.indent = 0,
    this.checked = false,
    this.controller,
    this.focus,
    this.node,
  });

  factory EditorLine.fromBlock(NoteBlock b) => b.type == NoteBlockType.raw
      ? EditorLine._(NoteBlockType.raw, node: b.node)
      : EditorLine.text(
          b.type,
          indent: b.indent,
          checked: b.checked,
          inline: b.inline,
        );

  factory EditorLine.text(
    NoteBlockType type, {
    int indent = 0,
    bool checked = false,
    List<InlineRun> inline = const [],
  }) => EditorLine._(
    type,
    indent: indent,
    checked: checked,
    controller: StyledLineController(inline),
    focus: FocusNode(),
  );

  bool get isRaw => type == NoteBlockType.raw;

  NoteBlock toBlock() => isRaw
      ? NoteBlock.raw(node!)
      : NoteBlock(
          type,
          indent: type.isList ? indent : 0,
          checked: type == NoteBlockType.task && checked,
          inline: controller!.runs,
        );

  void dispose() {
    controller?.dispose();
    focus?.dispose();
  }
}
