/// A piece of a line's text with the same look: bold, italic, strikethrough
/// and an optional link. `\n` inside [text] is a line break inside the line
/// (Tiptap's `hardBreak`). The same shape as `inline` in the PC's
/// `NoteFormat.js`.
class InlineRun {
  /// The marks the editor knows, in the fixed order they are saved in.
  static const knownMarks = ['bold', 'italic', 'strike'];

  final String text;

  /// Some of [knownMarks], always in that order.
  final List<String> marks;

  /// Set when the text is a link (Tiptap's `link` mark).
  final String? href;

  InlineRun(this.text, {List<String> marks = const [], this.href})
    : marks = List.unmodifiable(knownMarks.where(marks.contains));

  bool has(String mark) => marks.contains(mark);

  /// The same look (marks and link), whatever the text.
  bool sameLook(InlineRun other) =>
      marks.join() == other.marks.join() && href == other.href;

  @override
  bool operator ==(Object other) =>
      other is InlineRun && other.text == text && sameLook(other);

  @override
  int get hashCode => Object.hash(text, marks.join(), href);

  @override
  String toString() =>
      'InlineRun(${[text, ...marks, if (href != null) href].join(', ')})';
}
