import 'inline_run.dart';
import 'json_equality.dart';

/// What one line of a note is. `raw` is a part the editor cannot edit (for
/// example a table): it is shown read-only and saved back untouched.
enum NoteBlockType {
  paragraph,
  heading1,
  heading2,
  bullet,
  task,
  raw;

  bool get isList => this == bullet || this == task;
  bool get isHeading => this == heading1 || this == heading2;
}

/// One line of a note, as the editor works with it. The PC's editor works
/// the same way (a flat list of lines); nested lists in the saved JSON
/// become [indent] levels here, and back.
class NoteBlock {
  final NoteBlockType type;

  /// How deep a list line is, 0 to `NoteFormat.maxIndent`. Always 0 for
  /// other lines.
  final int indent;

  /// For a checklist line: whether it is ticked.
  final bool checked;
  final List<InlineRun> inline;

  /// For a `raw` block: the node exactly as it was in the note.
  final Map<String, Object?>? node;

  NoteBlock(
    this.type, {
    this.indent = 0,
    this.checked = false,
    List<InlineRun> inline = const [],
    this.node,
  }) : inline = List.unmodifiable(inline);

  NoteBlock.raw(Map<String, Object?> this.node)
    : type = NoteBlockType.raw,
      indent = 0,
      checked = false,
      inline = const [];

  /// The line's text without its look.
  String get text => inline.map((r) => r.text).join();

  NoteBlock copyWith({
    NoteBlockType? type,
    int? indent,
    bool? checked,
    List<InlineRun>? inline,
  }) => NoteBlock(
    type ?? this.type,
    indent: indent ?? this.indent,
    checked: checked ?? this.checked,
    inline: inline ?? this.inline,
    node: node,
  );

  @override
  bool operator ==(Object other) {
    if (other is! NoteBlock ||
        other.type != type ||
        other.indent != indent ||
        other.checked != checked ||
        other.inline.length != inline.length ||
        !JsonEquality.equals(other.node, node)) {
      return false;
    }
    for (var i = 0; i < inline.length; i++) {
      if (other.inline[i] != inline[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(type, indent, checked, inline.length);

  @override
  String toString() =>
      'NoteBlock(${type.name}, indent $indent, '
      '${checked ? 'ticked, ' : ''}$inline)';
}
