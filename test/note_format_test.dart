import 'dart:convert';

import 'package:deskplan_companion/features/notes/inline_run.dart';
import 'package:deskplan_companion/features/notes/json_equality.dart';
import 'package:deskplan_companion/features/notes/note_block.dart';
import 'package:deskplan_companion/features/notes/note_format.dart';
import 'package:deskplan_companion/core/progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same cases as the PC's tests/note-format.test.mjs, so the phone and
/// DeskPlan read and write notes the same way.
List<InlineRun> p(String text, [List<String> marks = const []]) => [
  InlineRun(text, marks: marks),
];

/// A doc as it arrives from DeskPlan (decoded from JSON text).
Map<String, Object?> decoded(Map<String, Object?> doc) =>
    jsonDecode(jsonEncode(doc)) as Map<String, Object?>;

void main() {
  test('blocks -> Tiptap JSON: nested bullets and checklists become nested '
      'lists', () {
    final doc = NoteFormat.fromBlocks([
      NoteBlock(NoteBlockType.heading1, inline: p('Groceries')),
      NoteBlock(NoteBlockType.task, checked: true, inline: p('Milk')),
      NoteBlock(NoteBlockType.task, indent: 1, inline: p('Oat milk')),
      NoteBlock(NoteBlockType.task, inline: p('Bread')),
      NoteBlock(
        NoteBlockType.paragraph,
        inline: [
          InlineRun('Bold', marks: ['bold']),
          InlineRun(' text'),
        ],
      ),
    ]);
    final content = doc['content'] as List;
    expect(
      JsonEquality.equals(content[0], {
        'type': 'heading',
        'attrs': {'level': 1},
        'content': [
          {'type': 'text', 'text': 'Groceries'},
        ],
      }),
      true,
    );
    final list = content[1] as Map;
    expect(list['type'], 'taskList');
    final items = list['content'] as List;
    expect(items, hasLength(2));
    expect(items[0]['attrs']['checked'], true);
    expect(items[0]['content'][1]['type'], 'taskList'); // nested under Milk
    expect(
      items[0]['content'][1]['content'][0]['content'][0]['content'][0]['text'],
      'Oat milk',
    );
    expect(
      JsonEquality.equals((content[2] as Map)['content'][0], {
        'type': 'text',
        'text': 'Bold',
        'marks': [
          {'type': 'bold'},
        ],
      }),
      true,
    );
  });

  test('round trip blocks -> JSON -> blocks keeps types, indents, ticks and '
      'marks', () {
    final blocks = [
      NoteBlock(NoteBlockType.bullet, inline: p('Week 1')),
      NoteBlock(NoteBlockType.bullet, indent: 1, inline: p('Loops')),
      NoteBlock(
        NoteBlockType.bullet,
        indent: 2,
        inline: p('for', ['bold', 'italic']),
      ),
      NoteBlock(
        NoteBlockType.task,
        indent: 1,
        checked: true,
        inline: p('Exercise 1'),
      ),
      NoteBlock(NoteBlockType.bullet, inline: p('Week 2')),
      NoteBlock(NoteBlockType.heading2, inline: p('Notes')),
      NoteBlock(NoteBlockType.paragraph, inline: p('line one\nline two')),
    ];
    expect(NoteFormat.toBlocks(decoded(NoteFormat.fromBlocks(blocks))), blocks);
  });

  test('links are saved as Tiptap link marks and read back', () {
    final inline = [
      InlineRun('See '),
      InlineRun(
        'the syllabus',
        marks: ['bold'],
        href: 'https://uni.example/csc101',
      ),
    ];
    final doc = NoteFormat.fromBlocks([
      NoteBlock(NoteBlockType.paragraph, inline: inline),
    ]);
    final marks = (doc['content'] as List)[0]['content'][1]['marks'];
    expect(
      JsonEquality.equals(marks, [
        {'type': 'bold'},
        {
          'type': 'link',
          'attrs': {'href': 'https://uni.example/csc101'},
        },
      ]),
      true,
    );
    expect(NoteFormat.toBlocks(decoded(doc))[0].inline, inline);
  });

  test('indents are tidied: no jumping more than one level, plain lines '
      'have none', () {
    final doc = NoteFormat.fromBlocks([
      NoteBlock(NoteBlockType.bullet, indent: 3, inline: p('a')),
      NoteBlock(NoteBlockType.bullet, indent: 5, inline: p('b')),
      NoteBlock(NoteBlockType.paragraph, indent: 2, inline: p('c')),
    ]);
    expect(NoteFormat.toBlocks(doc).map((b) => b.indent), [0, 1, 0]);
  });

  test('unknown nodes (e.g. a future table) are kept untouched', () {
    final table = {
      'type': 'table',
      'content': [
        {
          'type': 'tableRow',
          'content': [
            {
              'type': 'tableCell',
              'content': [
                {
                  'type': 'paragraph',
                  'content': [
                    {'type': 'text', 'text': 'A1'},
                  ],
                },
              ],
            },
          ],
        },
      ],
    };
    final doc = decoded({
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'Hi'},
          ],
        },
        table,
      ],
    });
    expect(
      JsonEquality.equals(NoteFormat.fromBlocks(NoteFormat.toBlocks(doc)), doc),
      true,
    );
    expect(NoteFormat.toPlainText(doc), contains('A1'));
  });

  test('old plain-text notes convert: bullets, checklists, headings, '
      'indents', () {
    final doc = NoteFormat.fromPlainText(
      '# Shopping\n- fruit\n  - apples\n[x] milk\n[ ] eggs\nremember the bags',
    );
    final blocks = NoteFormat.toBlocks(doc);
    expect(blocks.map((b) => (b.type, b.indent)), [
      (NoteBlockType.heading1, 0),
      (NoteBlockType.bullet, 0),
      (NoteBlockType.bullet, 1),
      (NoteBlockType.task, 0),
      (NoteBlockType.task, 0),
      (NoteBlockType.paragraph, 0),
    ]);
    expect(blocks[3].checked, true);
    expect(NoteFormat.checklistStats(doc), const Progress(1, 2));
  });

  test('plain text keeps list markers and reads back the same', () {
    const text = 'Groceries\n- fruit\n  - apples\n[x] milk\n[ ] eggs';
    expect(NoteFormat.toPlainText(NoteFormat.fromPlainText(text)), text);
  });

  test('empty notes and merging of runs', () {
    expect(NoteFormat.toBlocks(NoteFormat.emptyDoc()), [
      NoteBlock(NoteBlockType.paragraph),
    ]);
    expect(
      JsonEquality.equals(NoteFormat.fromPlainText(''), NoteFormat.emptyDoc()),
      true,
    );
    expect(
      NoteFormat.mergeRuns([
        InlineRun('a', marks: ['bold']),
        InlineRun('b', marks: ['bold']),
        InlineRun(''),
      ]),
      [
        InlineRun('ab', marks: ['bold']),
      ],
    );
    expect(NoteFormat.checklistStats(null), const Progress(0, 0));
  });

  group('JsonEquality', () {
    test('ignores key order and spacing, not list order', () {
      final a = jsonDecode('{"type":"doc","content":[{"type":"paragraph"}]}');
      final b = jsonDecode(
        '{ "content": [ { "type": "paragraph" } ], "type": "doc" }',
      );
      expect(JsonEquality.equals(a, b), true);
      expect(JsonEquality.equals([1, 2], [2, 1]), false);
      expect(JsonEquality.equals({'a': 1}, {'a': 1.0}), true);
      expect(JsonEquality.equals({'a': null}, <String, Object?>{}), false);
    });
  });
}
