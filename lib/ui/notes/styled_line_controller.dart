import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/notes/inline_run.dart';
import '../../features/notes/note_format.dart';
import '../theme/deskplan_colors.dart';

/// The look of one character: its marks and, for a link, the address.
class _Look {
  final Set<String> marks;
  final String? href;

  const _Look([this.marks = const {}, this.href]);

  bool same(_Look other) =>
      href == other.href &&
      marks.length == other.marks.length &&
      marks.containsAll(other.marks);
}

/// The text of one line of a note, with its look (bold, italic,
/// strikethrough, links) kept per character so typing anywhere keeps the
/// look around it, and a link keeps its address when the words around it
/// are edited.
///
/// Phone keyboards do not report Backspace in an empty spot, so the text
/// always starts with one invisible character ([sentinel]). Deleting it
/// means "Backspace at the start of the line" and is reported to
/// [onBackspaceAtStart] instead; Enter is reported to [onNewline], so the
/// editor can split, join, outdent or change the line like DeskPlan does.
class StyledLineController extends TextEditingController {
  /// A zero-width space: invisible, but there to be deleted.
  static const sentinel = '​';

  List<_Look> _looks;

  /// Marks to type with next, set by a tool tap with no selection. Cleared
  /// when the caret moves.
  Set<String>? _pending;

  /// Backspace with the caret at the start of the line.
  VoidCallback? onBackspaceAtStart;

  /// Enter was typed: [at] is where, in [plainText], with the line break
  /// already taken out again.
  void Function(int at)? onNewline;

  /// The text or its look changed (not just the caret).
  VoidCallback? onEdited;

  StyledLineController(List<InlineRun> runs)
    : _looks = _looksOf(runs),
      super(text: sentinel + runs.map((r) => r.text).join()) {
    selection = TextSelection.collapsed(offset: text.length);
  }

  static List<_Look> _looksOf(List<InlineRun> runs) => [
    for (final r in runs)
      for (var i = 0; i < r.text.length; i++) _Look(r.marks.toSet(), r.href),
  ];

  /// The line's text, without the invisible first character.
  String get plainText => text.isEmpty ? '' : text.substring(1);

  /// Where the caret is in [plainText] (start of the selection).
  int get caret {
    final s = selection;
    if (!s.isValid) return plainText.length;
    return (s.start - 1).clamp(0, plainText.length);
  }

  /// The line as runs of the same look.
  List<InlineRun> get runs {
    final visible = plainText;
    final out = <InlineRun>[];
    var start = 0;
    for (var i = 1; i <= visible.length; i++) {
      if (i == visible.length || !_looks[i].same(_looks[start])) {
        final look = _looks[start];
        out.add(
          InlineRun(
            visible.substring(start, i),
            marks: look.marks.toList(),
            href: look.href,
          ),
        );
        start = i;
      }
    }
    return NoteFormat.mergeRuns(out);
  }

  /// Replaces the whole line, with the caret at [caretAt] in [plainText].
  void setRuns(List<InlineRun> runs, {int? caretAt}) {
    _looks = _looksOf(runs);
    _pending = null;
    final visible = runs.map((r) => r.text).join();
    super.value = TextEditingValue(
      text: sentinel + visible,
      selection: TextSelection.collapsed(
        offset: 1 + (caretAt ?? visible.length).clamp(0, visible.length),
      ),
    );
  }

  /// Puts the caret at [at] in [plainText].
  void placeCaret(int at) {
    selection = TextSelection.collapsed(
      offset: 1 + at.clamp(0, plainText.length),
    );
  }

  /// The runs before and after [at].
  (List<InlineRun>, List<InlineRun>) splitAt(int at) {
    final all = runs;
    final before = <InlineRun>[];
    final after = <InlineRun>[];
    var pos = 0;
    for (final r in all) {
      final end = pos + r.text.length;
      if (end <= at) {
        before.add(r);
      } else if (pos >= at) {
        after.add(r);
      } else {
        final cut = at - pos;
        before.add(
          InlineRun(r.text.substring(0, cut), marks: r.marks, href: r.href),
        );
        after.add(
          InlineRun(r.text.substring(cut), marks: r.marks, href: r.href),
        );
      }
      pos = end;
    }
    return (before, after);
  }

  @override
  set value(TextEditingValue newValue) {
    final old = super.value;
    if (!newValue.text.startsWith(sentinel)) {
      final rest = newValue.text;
      if (rest == plainText) {
        // Only the invisible character went: Backspace at the start.
        super.value = old.copyWith(
          selection: const TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        );
        final callback = onBackspaceAtStart;
        if (callback != null) scheduleMicrotask(callback);
        return;
      }
      // Everything was replaced (for example select all, then type): put
      // the invisible character back in front.
      newValue = TextEditingValue(
        text: sentinel + rest,
        selection: _shift(newValue.selection, 1),
        composing: TextRange.empty,
      );
    }
    final oldText = plainText;
    final newText = newValue.text.substring(1);
    newValue = newValue.copyWith(
      selection: _keepAfterSentinel(newValue.selection),
    );

    if (oldText == newText) {
      if (old.selection != newValue.selection) _pending = null;
      super.value = newValue;
      return;
    }

    final (at, inserted) = _applyDiff(oldText, newText);
    super.value = newValue;
    final newline = inserted.indexOf('\n');
    final onNewline = this.onNewline;
    if (newline >= 0 && onNewline != null) {
      // The editor turns Enter into a new line. A line break pasted inside
      // a longer text stays, as DeskPlan's own hard breaks do.
      if (inserted.length == 1) {
        final where = at + newline;
        _removeAt(where);
        scheduleMicrotask(() => onNewline(where));
        return;
      }
    }
    onEdited?.call();
  }

  /// Removes one character from [plainText] without telling anyone.
  void _removeAt(int at) {
    _looks.removeAt(at);
    final visible = plainText;
    super.value = TextEditingValue(
      text: sentinel + visible.substring(0, at) + visible.substring(at + 1),
      selection: TextSelection.collapsed(offset: 1 + at),
    );
  }

  /// Keeps [_looks] in step with a text change. Returns where the change
  /// was and what was inserted.
  (int, String) _applyDiff(String oldText, String newText) {
    var prefix = 0;
    final shortest = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < shortest && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shortest - prefix &&
        oldText[oldText.length - 1 - suffix] ==
            newText[newText.length - 1 - suffix]) {
      suffix++;
    }
    final removed = oldText.length - prefix - suffix;
    final inserted = newText.substring(prefix, newText.length - suffix);

    // New text takes the look of the text before it (or what a tool asked
    // for). It is part of a link only inside one, never just after it.
    final before = prefix > 0 ? _looks[prefix - 1] : null;
    final afterIndex = prefix + removed;
    final after = afterIndex < _looks.length ? _looks[afterIndex] : null;
    final marks = _pending ?? before?.marks ?? after?.marks ?? const {};
    final href = before?.href != null && before?.href == after?.href
        ? before!.href
        : null;
    _looks.replaceRange(
      prefix,
      prefix + removed,
      List.filled(inserted.length, _Look({...marks}, href)),
    );
    return (prefix, inserted);
  }

  TextSelection _keepAfterSentinel(TextSelection s) {
    if (!s.isValid) return s;
    return s.copyWith(
      baseOffset: s.baseOffset < 1 ? 1 : s.baseOffset,
      extentOffset: s.extentOffset < 1 ? 1 : s.extentOffset,
    );
  }

  static TextSelection _shift(TextSelection s, int by) => s.isValid
      ? s.copyWith(
          baseOffset: s.baseOffset + by,
          extentOffset: s.extentOffset + by,
        )
      : s;

  /// The selected range in [plainText], or null when nothing is selected.
  (int, int)? get _range {
    final s = selection;
    if (!s.isValid || s.isCollapsed) return null;
    return (
      (s.start - 1).clamp(0, plainText.length),
      (s.end - 1).clamp(0, plainText.length),
    );
  }

  /// The look at the caret: what typing there would give.
  _Look get _lookAtCaret {
    final at = caret;
    if (at > 0 && at <= _looks.length) return _looks[at - 1];
    return _looks.isEmpty ? const _Look() : _looks.first;
  }

  /// Whether [mark] is on: for every selected character, or for what would
  /// be typed at the caret.
  bool isOn(String mark) {
    final range = _range;
    if (range == null) {
      return (_pending ?? _lookAtCaret.marks).contains(mark);
    }
    final (from, to) = range;
    return _looks.sublist(from, to).every((l) => l.marks.contains(mark));
  }

  /// Bold, italic or strikethrough on or off: for the selection, or for
  /// what is typed next.
  void toggle(String mark) {
    final range = _range;
    final on = !isOn(mark);
    if (range == null) {
      final marks = {...(_pending ?? _lookAtCaret.marks)};
      on ? marks.add(mark) : marks.remove(mark);
      _pending = marks;
      notifyListeners();
      return;
    }
    final (from, to) = range;
    for (var i = from; i < to; i++) {
      final marks = {..._looks[i].marks};
      on ? marks.add(mark) : marks.remove(mark);
      _looks[i] = _Look(marks, _looks[i].href);
    }
    notifyListeners();
    onEdited?.call();
  }

  /// The address of the link at the caret or selection, if any.
  String? get link {
    final range = _range;
    if (range != null) {
      final (from, to) = range;
      final hrefs = _looks.sublist(from, to).map((l) => l.href).toSet();
      return hrefs.length == 1 ? hrefs.first : null;
    }
    final at = caret;
    final here = at < _looks.length ? _looks[at].href : null;
    final before = at > 0 && at <= _looks.length ? _looks[at - 1].href : null;
    return here ?? before;
  }

  /// True when words are selected, so a link can be put on them.
  bool get hasSelection => _range != null;

  /// Links the selected words to [href]; with null, removes the link from
  /// the selection, or from the whole link at the caret.
  void setLink(String? href) {
    var range = _range;
    if (range == null) {
      final current = link;
      if (current == null || href != null) return;
      range = _linkAround(current);
    }
    final (from, to) = range;
    for (var i = from; i < to; i++) {
      _looks[i] = _Look(_looks[i].marks, href);
    }
    notifyListeners();
    onEdited?.call();
  }

  /// The characters around the caret that carry [href].
  (int, int) _linkAround(String href) {
    var from = caret;
    if (from >= _looks.length || _looks[from].href != href) from--;
    var to = from;
    while (from > 0 && _looks[from - 1].href == href) {
      from--;
    }
    while (to < _looks.length && _looks[to].href == href) {
      to++;
    }
    return (from < 0 ? 0 : from, to);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final c = DeskPlanColors.of(context);
    final children = <InlineSpan>[const TextSpan(text: sentinel)];
    for (final r in runs) {
      final decorations = [
        if (r.has('strike')) TextDecoration.lineThrough,
        if (r.href != null) TextDecoration.underline,
        if (style?.decoration != null) style!.decoration!,
      ];
      children.add(
        TextSpan(
          text: r.text,
          style: TextStyle(
            fontWeight: r.has('bold') ? FontWeight.w700 : null,
            fontStyle: r.has('italic') ? FontStyle.italic : null,
            color: r.href != null ? c.accent : null,
            decoration: decorations.isEmpty
                ? null
                : TextDecoration.combine(decorations),
          ),
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }
}
