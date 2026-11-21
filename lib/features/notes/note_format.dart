import '../../core/progress.dart';
import 'inline_run.dart';
import 'note_block.dart';

/// How notes are saved: the Dart copy of the PC's
/// `renderer/modules/workspace/editor/NoteFormat.js` (protocol.md section 4
/// "Note text"). Pure functions, no widgets, so they are easy to test, and
/// the tests use the PC's own cases so both sides read and write the same
/// JSON.
///
/// A note is Tiptap / ProseMirror JSON:
///   `{ type: 'doc', content: [ paragraph | heading | bulletList | taskList | (anything else, kept as is) ] }`
/// The editor works with a flat list of [NoteBlock]s, one per line. Nested
/// lists in the JSON become indent levels on flat blocks, and back.
class NoteFormat {
  const NoteFormat._();

  /// Deepest list indent the PC's editor allows.
  static const maxIndent = 6;

  static const _listKind = {
    NoteBlockType.bullet: 'bulletList',
    NoteBlockType.task: 'taskList',
  };

  static Map<String, Object?> emptyDoc() => {
    'type': 'doc',
    'content': [
      {'type': 'paragraph'},
    ],
  };

  // ── Inline text ─────────────────────────────────────────────────────────

  static List<InlineRun> _runsFromNodes(Object? nodes) {
    final runs = <InlineRun>[];
    for (final n in _list(nodes)) {
      if (n is! Map) continue;
      if (n['type'] == 'text') {
        final marks = _list(n['marks']).whereType<Map>().toList();
        final link = marks.where((m) => m['type'] == 'link').firstOrNull;
        final href = link == null ? null : _map(link['attrs'])['href'];
        runs.add(
          InlineRun(
            n['text'] is String ? n['text'] as String : '',
            marks: marks.map((m) => m['type']).whereType<String>().toList(),
            href: href is String && href.isNotEmpty ? href : null,
          ),
        );
      } else if (n['type'] == 'hardBreak') {
        runs.add(InlineRun('\n'));
      }
    }
    return mergeRuns(runs);
  }

  static List<Map<String, Object?>> _nodesFromRuns(List<InlineRun> runs) {
    final nodes = <Map<String, Object?>>[];
    for (final r in mergeRuns(runs)) {
      final list = <Map<String, Object?>>[
        for (final m in r.marks) {'type': m},
        if (r.href != null)
          {
            'type': 'link',
            'attrs': {'href': r.href},
          },
      ];
      final parts = r.text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) nodes.add({'type': 'hardBreak'});
        if (parts[i].isEmpty) continue;
        nodes.add({
          'type': 'text',
          'text': parts[i],
          if (list.isNotEmpty) 'marks': list,
        });
      }
    }
    return nodes;
  }

  /// Joins neighbouring runs with the same marks and link, and drops empty
  /// ones.
  static List<InlineRun> mergeRuns(List<InlineRun> runs) {
    final out = <InlineRun>[];
    for (final r in runs) {
      if (r.text.isEmpty) continue;
      if (out.isNotEmpty && out.last.sameLook(r)) {
        final last = out.removeLast();
        out.add(
          InlineRun(last.text + r.text, marks: last.marks, href: last.href),
        );
      } else {
        out.add(r);
      }
    }
    return out;
  }

  // ── Doc JSON → blocks ───────────────────────────────────────────────────

  static bool _isTextNode(Object? n) =>
      n is Map && (n['type'] == 'paragraph' || n['type'] == 'heading');

  static List<NoteBlock> toBlocks(Map<String, Object?>? doc) {
    final out = <NoteBlock>[];
    for (final node in _list(doc?['content'])) {
      if (node is Map) _addNode(node, out);
    }
    return out.isEmpty ? [NoteBlock(NoteBlockType.paragraph)] : out;
  }

  static void _addNode(Map node, List<NoteBlock> out) {
    switch (node['type']) {
      case 'paragraph':
        out.add(
          NoteBlock(
            NoteBlockType.paragraph,
            inline: _runsFromNodes(node['content']),
          ),
        );
      case 'heading':
        final level = _map(node['attrs'])['level'];
        out.add(
          NoteBlock(
            (level is num ? level : 1) <= 1
                ? NoteBlockType.heading1
                : NoteBlockType.heading2,
            inline: _runsFromNodes(node['content']),
          ),
        );
      case 'bulletList' || 'orderedList' || 'taskList':
        _addList(node, 0, out);
      case 'blockquote':
        for (final child in _list(node['content'])) {
          if (child is Map) _addNode(child, out);
        }
      default:
        // For example a table made by a later editor: kept untouched.
        out.add(NoteBlock.raw(Map<String, Object?>.from(node)));
    }
  }

  static void _addList(Map list, int depth, List<NoteBlock> out) {
    final type = list['type'] == 'taskList'
        ? NoteBlockType.task
        : NoteBlockType.bullet;
    for (final item in _list(list['content'])) {
      if (item is! Map) continue;
      final content = _list(item['content']);
      final first = content.isEmpty ? null : content.first;
      final own = _isTextNode(first) ? first as Map : null;
      out.add(
        NoteBlock(
          type,
          indent: depth < maxIndent ? depth : maxIndent,
          checked: _map(item['attrs'])['checked'] == true,
          inline: _runsFromNodes(own?['content']),
        ),
      );
      for (final child in own != null ? content.skip(1) : content) {
        if (child is! Map) continue;
        final childType = child['type'];
        if (childType is String && childType.endsWith('List')) {
          _addList(child, depth + 1, out);
        } else if (_isTextNode(child)) {
          out.add(
            NoteBlock(
              type,
              indent: depth + 1 < maxIndent ? depth + 1 : maxIndent,
              inline: _runsFromNodes(child['content']),
            ),
          );
        }
      }
    }
  }

  // ── Blocks → doc JSON ───────────────────────────────────────────────────

  static Map<String, Object?> fromBlocks(List<NoteBlock> blocks) {
    final norm = _normalizeIndents(blocks);
    final content = <Map<String, Object?>>[];
    var i = 0;
    while (i < norm.length) {
      final b = norm[i];
      if (b.type.isList) {
        final (list, next) = _buildList(norm, i, 0);
        content.add(list);
        i = next;
        continue;
      }
      if (b.type == NoteBlockType.raw) {
        content.add(b.node!);
      } else if (b.type.isHeading) {
        content.add(
          _textNode('heading', b.inline, {
            'level': b.type == NoteBlockType.heading1 ? 1 : 2,
          }),
        );
      } else {
        content.add(_textNode('paragraph', b.inline));
      }
      i++;
    }
    return {
      'type': 'doc',
      'content': content.isEmpty
          ? [
              {'type': 'paragraph'},
            ]
          : content,
    };
  }

  /// A list line can be at most one level deeper than the line above it;
  /// other lines go back to 0.
  static List<NoteBlock> _normalizeIndents(List<NoteBlock> blocks) {
    var prev = -1;
    final out = <NoteBlock>[];
    for (final b in blocks) {
      var indent = 0;
      if (b.type.isList) {
        indent = b.indent;
        if (indent > prev + 1) indent = prev + 1;
        if (indent > maxIndent) indent = maxIndent;
        if (indent < 0) indent = 0;
        prev = indent;
      } else {
        prev = -1;
      }
      out.add(indent == b.indent ? b : b.copyWith(indent: indent));
    }
    return out;
  }

  static (Map<String, Object?>, int) _buildList(
    List<NoteBlock> blocks,
    int i,
    int depth,
  ) {
    final kind = _listKind[blocks[i].type];
    final items = <Map<String, Object?>>[];
    while (i < blocks.length &&
        blocks[i].type.isList &&
        blocks[i].indent >= depth) {
      final b = blocks[i];
      if (b.indent > depth && items.isNotEmpty) {
        final (sub, next) = _buildList(blocks, i, depth + 1);
        (items.last['content'] as List).add(sub);
        i = next;
        continue;
      }
      if (_listKind[b.type] != kind) break; // a different kind starts here
      items.add(
        b.type == NoteBlockType.task
            ? {
                'type': 'taskItem',
                'attrs': {'checked': b.checked},
                'content': [_textNode('paragraph', b.inline)],
              }
            : {
                'type': 'listItem',
                'content': [_textNode('paragraph', b.inline)],
              },
      );
      i++;
    }
    return ({'type': kind, 'content': items}, i);
  }

  static Map<String, Object?> _textNode(
    String type,
    List<InlineRun> inline, [
    Map<String, Object?>? attrs,
  ]) {
    final content = _nodesFromRuns(inline);
    return {
      'type': type,
      'attrs': ?attrs,
      if (content.isNotEmpty) 'content': content,
    };
  }

  // ── Plain text (previews, old notes) ────────────────────────────────────

  /// Readable plain text. Lists keep "- " / "[x] " markers so
  /// [fromPlainText] can read it back.
  static String toPlainText(Map<String, Object?>? doc) => toBlocks(doc)
      .map((b) {
        if (b.type == NoteBlockType.raw) return rawText(b.node);
        final pad = '  ' * b.indent;
        return switch (b.type) {
          NoteBlockType.bullet => '$pad- ${b.text}',
          NoteBlockType.task => '$pad[${b.checked ? 'x' : ' '}] ${b.text}',
          _ => b.text,
        };
      })
      .join('\n');

  /// The readable text of a part the editor cannot edit (a table's cells
  /// joined with " | "), for showing it read-only.
  static String rawText(Object? node) {
    if (node is! Map) return '';
    if (node['type'] == 'text') {
      return node['text'] is String ? node['text'] as String : '';
    }
    final content = _list(node['content']);
    final firstIsText =
        content.isNotEmpty &&
        content.first is Map &&
        (content.first as Map)['type'] == 'text';
    return content
        .map(rawText)
        .join(
          node['type'] == 'tableRow'
              ? ' | '
              : firstIsText
              ? ''
              : '\n',
        );
  }

  static final _taskLine = RegExp(r'^(\s*)\[( |x|X)?\]\s?(.*)$');
  static final _bulletLine = RegExp(r'^(\s*)[-*•]\s+(.*)$');
  static final _heading2Line = RegExp(r'^##+\s+(.*)$');
  static final _heading1Line = RegExp(r'^#\s+(.*)$');

  /// Old plain-text notes, or pasted text: "- " bullets, "[ ]" / "[x]"
  /// checklists, "# " headings.
  static Map<String, Object?> fromPlainText(String text) {
    int indentOf(String spaces) {
      final level = spaces.replaceAll('\t', '  ').length ~/ 2;
      return level < maxIndent ? level : maxIndent;
    }

    List<InlineRun> plain(String s) => s.isEmpty ? [] : [InlineRun(s)];

    final lines = text.replaceAll(RegExp(r'\r\n?'), '\n').split('\n');
    final blocks = lines.map((line) {
      RegExpMatch? m;
      if ((m = _taskLine.firstMatch(line)) != null) {
        return NoteBlock(
          NoteBlockType.task,
          indent: indentOf(m!.group(1)!),
          checked: (m.group(2) ?? '').toLowerCase() == 'x',
          inline: plain(m.group(3)!),
        );
      }
      if ((m = _bulletLine.firstMatch(line)) != null) {
        return NoteBlock(
          NoteBlockType.bullet,
          indent: indentOf(m!.group(1)!),
          inline: plain(m.group(2)!),
        );
      }
      if ((m = _heading2Line.firstMatch(line)) != null) {
        return NoteBlock(NoteBlockType.heading2, inline: plain(m!.group(1)!));
      }
      if ((m = _heading1Line.firstMatch(line)) != null) {
        return NoteBlock(NoteBlockType.heading1, inline: plain(m!.group(1)!));
      }
      return NoteBlock(NoteBlockType.paragraph, inline: plain(line));
    }).toList();
    return fromBlocks(blocks);
  }

  /// Ticked and total checklist lines in a note.
  static Progress checklistStats(Map<String, Object?>? doc) {
    if (doc == null) return Progress.none;
    final tasks = toBlocks(
      doc,
    ).where((b) => b.type == NoteBlockType.task).toList();
    return Progress(tasks.where((b) => b.checked).length, tasks.length);
  }

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static Map _map(Object? value) => value is Map ? value : const {};
}
