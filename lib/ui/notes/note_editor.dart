import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';

import '../../features/notes/note_block.dart';
import '../../features/notes/note_format.dart';
import '../theme/deskplan_colors.dart';
import 'editor_line.dart';
import 'link_dialog.dart';
import 'note_line_view.dart';
import 'note_toolbar.dart';

/// The writing area of a note: one row per line, like DeskPlan's editor,
/// and the same rules for the keys (the PC's `RichEditor.js`):
///
/// - Enter splits the line. On an empty list line it steps out of the list
///   instead (first a level, then entirely); after a heading the new line
///   is normal text.
/// - Backspace at the start of a list line or heading outdents it, then
///   makes it normal text; at the start of a normal line it joins the line
///   above.
/// - "- " bullet, "[] " checklist, "[x] " ticked, "# " / "## " headings,
///   typed at the start of a normal line.
///
/// Every change gives [onChanged] the whole note as Tiptap JSON. Parts the
/// phone cannot edit stay where they are, untouched.
class NoteEditor extends StatefulWidget {
  final Map<String, Object?> doc;

  /// Change it to load [doc] again (for example a newer version from the PC).
  final int version;
  final ValueChanged<Map<String, Object?>> onChanged;

  /// Shown above the first line, scrolling with it (the title).
  final Widget? header;

  const NoteEditor({
    super.key,
    required this.doc,
    required this.onChanged,
    this.version = 0,
    this.header,
  });

  @override
  State<NoteEditor> createState() => NoteEditorState();
}

class NoteEditorState extends State<NoteEditor> {
  final _lines = <EditorLine>[];
  EditorLine? _focused;

  static final _shortcuts = <(RegExp, NoteBlockType, bool)>[
    (RegExp(r'^[-*•] '), NoteBlockType.bullet, false),
    (RegExp(r'^\[ ?\] '), NoteBlockType.task, false),
    (RegExp(r'^\[[xX]\] '), NoteBlockType.task, true),
    (RegExp(r'^## '), NoteBlockType.heading2, false),
    (RegExp(r'^# '), NoteBlockType.heading1, false),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version) {
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      _focused = null;
      _load();
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _load() {
    for (final b in NoteFormat.toBlocks(widget.doc)) {
      _wire(EditorLine.fromBlock(b));
    }
    if (_lines.every((l) => l.isRaw)) {
      _wire(EditorLine.text(NoteBlockType.paragraph));
    }
  }

  /// Adds [line] (at [at], or at the end) and listens to it.
  EditorLine _wire(EditorLine line, {int? at}) {
    if (at == null) {
      _lines.add(line);
    } else {
      _lines.insert(at, line);
    }
    final controller = line.controller;
    if (controller == null) return line;
    controller.onEdited = () => _edited(line);
    controller.onNewline = (where) => _newline(line, where);
    controller.onBackspaceAtStart = () => _backspaceAtStart(line);
    // The bar shows the look at the caret, so it follows the caret.
    controller.addListener(() {
      if (_focused == line && mounted) setState(() {});
    });
    line.focus!.addListener(() {
      if (!mounted) return;
      if (line.focus!.hasFocus) {
        setState(() => _focused = line);
      } else if (_focused == line) {
        // Keep the bar while focus moves to another line.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focused == line && !line.focus!.hasFocus) {
            setState(() => _focused = null);
          }
        });
      }
    });
    return line;
  }

  /// Focuses the first line (for a new note, after its title).
  void focusStart() {
    final first = _lines.where((l) => !l.isRaw).firstOrNull;
    if (first == null) return;
    first.focus!.requestFocus();
    first.controller!.placeCaret(first.controller!.plainText.length);
  }

  void _changed() {
    widget.onChanged(
      NoteFormat.fromBlocks([for (final l in _lines) l.toBlock()]),
    );
    if (mounted) setState(() {});
  }

  void _focusLine(EditorLine line, int caret) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_lines.contains(line)) return;
      line.focus!.requestFocus();
      line.controller!.placeCaret(caret);
    });
  }

  void _remove(EditorLine line) {
    _lines.remove(line);
    if (_focused == line) _focused = null;
    // Disposed after the frame: its widget is still on screen until then.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  // ── Keys ──────────────────────────────────────────────────────────────

  void _edited(EditorLine line) {
    if (line.type == NoteBlockType.paragraph) _shortcut(line);
    _changed();
  }

  /// "- ", "[] ", "[x] ", "# ", "## " typed at the start of a normal line.
  void _shortcut(EditorLine line) {
    final controller = line.controller!;
    final text = controller.plainText.replaceAll(' ', ' ');
    for (final (pattern, type, checked) in _shortcuts) {
      final match = pattern.firstMatch(text);
      if (match == null || controller.caret != match.end) continue;
      final (_, rest) = controller.splitAt(match.end);
      line
        ..type = type
        ..checked = checked;
      controller.setRuns(rest, caretAt: 0);
      return;
    }
  }

  void _newline(EditorLine line, int at) {
    final controller = line.controller!;
    final index = _lines.indexOf(line);
    if (index < 0) return;

    // Enter on an empty list line steps out of the list.
    if (line.type.isList && controller.plainText.trim().isEmpty) {
      if (line.indent > 0) {
        line.indent--;
      } else {
        line.type = NoteBlockType.paragraph;
      }
      _changed();
      return;
    }

    final (before, after) = controller.splitAt(at);
    controller.setRuns(before);
    final afterText = after.map((r) => r.text).join();
    final type = line.type.isHeading && afterText.isEmpty
        ? NoteBlockType.paragraph
        : line.type;
    final next = _wire(
      EditorLine.text(type, indent: line.indent, inline: after),
      at: index + 1,
    );
    // A checklist line split while empty starts unticked, as on the PC.
    if (line.type == NoteBlockType.task && before.isEmpty) {
      line.checked = false;
    }
    _changed();
    _focusLine(next, 0);
  }

  void _backspaceAtStart(EditorLine line) {
    final index = _lines.indexOf(line);
    if (index < 0) return;
    if (line.type != NoteBlockType.paragraph) {
      if (line.type.isList && line.indent > 0) {
        line.indent--;
      } else {
        line.type = NoteBlockType.paragraph;
      }
      _changed();
      return;
    }
    if (index == 0) return;
    final above = _lines[index - 1];
    final controller = line.controller!;
    if (above.isRaw) {
      // A part the phone cannot edit is never joined or removed; an empty
      // line under it can go.
      if (controller.plainText.isEmpty && index + 1 < _lines.length) {
        _remove(line);
        _changed();
      }
      return;
    }
    final aboveController = above.controller!;
    final join = aboveController.plainText.length;
    aboveController.setRuns(
      NoteFormat.mergeRuns([...aboveController.runs, ...controller.runs]),
      caretAt: join,
    );
    _remove(line);
    _changed();
    _focusLine(above, join);
  }

  // ── Toolbar ───────────────────────────────────────────────────────────

  void _setType(NoteBlockType type) {
    final line = _focused;
    if (line == null) return;
    // Tapping the type the line already is turns it back into text.
    line.type = line.type == type && type != NoteBlockType.paragraph
        ? NoteBlockType.paragraph
        : type;
    if (!line.type.isList) line.indent = 0;
    if (line.type != NoteBlockType.task) line.checked = false;
    _changed();
  }

  /// How deep [line] may go: one level below the list line above it.
  int _maxIndent(EditorLine line) {
    final index = _lines.indexOf(line);
    final above = index > 0 ? _lines[index - 1] : null;
    if (above == null || !above.type.isList) return 0;
    final most = above.indent + 1;
    return most < NoteFormat.maxIndent ? most : NoteFormat.maxIndent;
  }

  void _indent(int by) {
    final line = _focused;
    if (line == null || !line.type.isList) return;
    final next = line.indent + by;
    if (next < 0 || next > _maxIndent(line)) return;
    line.indent = next;
    _changed();
  }

  void _toggleChecked(EditorLine line) {
    line.checked = !line.checked;
    _changed();
  }

  Future<void> _editLink() async {
    final line = _focused;
    final controller = line?.controller;
    if (controller == null) return;
    final current = controller.link;
    if (current == null && !controller.hasSelection) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Select the words to link first'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final result = await LinkDialog.show(context, current: current);
    if (result == null || !mounted) return;
    controller.setLink(result.isEmpty ? null : result);
    line!.focus!.requestFocus();
  }

  Future<void> _openLink() async {
    final href = _focused?.controller?.link;
    if (href == null) return;
    try {
      await AndroidIntent(action: 'action_view', data: href).launch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $href')));
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final focused = _focused;
    final controller = focused?.controller;
    final onlyEmptyLine =
        _lines.length == 1 &&
        !_lines.first.isRaw &&
        _lines.first.type == NoteBlockType.paragraph &&
        _lines.first.controller!.plainText.isEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
            children: [
              ?widget.header,
              for (final line in _lines)
                NoteLineView(
                  key: ValueKey(line.id),
                  line: line,
                  hint: onlyEmptyLine ? 'Start writing…' : null,
                  onToggleChecked: () => _toggleChecked(line),
                ),
              // Tapping below the last line writes on it.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _focusEnd,
                child: SizedBox(
                  height: 120,
                  child: ColoredBox(color: c.surface.withValues(alpha: 0)),
                ),
              ),
            ],
          ),
        ),
        if (focused != null && controller != null)
          NoteToolbar(
            lineType: focused.type,
            isOn: controller.isOn,
            inLink: controller.link != null,
            canIndent:
                focused.type.isList && focused.indent < _maxIndent(focused),
            canOutdent: focused.type.isList && focused.indent > 0,
            onType: _setType,
            onIndent: () => _indent(1),
            onOutdent: () => _indent(-1),
            onMark: controller.toggle,
            onLink: _editLink,
            onOpenLink: _openLink,
          ),
      ],
    );
  }

  /// Focuses the last line, or adds a text line after a read-only part.
  void _focusEnd() {
    var last = _lines.lastOrNull;
    if (last == null || last.isRaw) {
      last = _wire(EditorLine.text(NoteBlockType.paragraph));
      setState(() {});
    }
    _focusLine(last, last.controller!.plainText.length);
  }

  /// The lines as they are now (for tests).
  @visibleForTesting
  List<NoteBlock> get blocks => [for (final l in _lines) l.toBlock()];
}
