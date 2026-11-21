import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_repository.dart';
import 'package:deskplan_companion/features/notes/inline_run.dart';
import 'package:deskplan_companion/features/notes/json_equality.dart';
import 'package:deskplan_companion/features/notes/note_autosaver.dart';
import 'package:deskplan_companion/features/notes/note_block.dart';
import 'package:deskplan_companion/features/notes/note_format.dart';
import 'package:deskplan_companion/ui/notes/note_editor.dart';
import 'package:deskplan_companion/ui/notes/note_places.dart';
import 'package:deskplan_companion/ui/notes/styled_line_controller.dart';
import 'package:deskplan_companion/features/connection/destination.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:deskplan_companion/core/progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows the editor with [doc] and collects every doc it reports.
Future<List<Map<String, Object?>>> _pump(
  WidgetTester tester,
  Map<String, Object?> doc,
) async {
  final changes = <Map<String, Object?>>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: NoteEditor(doc: doc, onChanged: changes.add),
      ),
    ),
  );
  return changes;
}

NoteEditorState _editor(WidgetTester tester) =>
    tester.state<NoteEditorState>(find.byType(NoteEditor));

/// Types into line [i] as a keyboard would: the whole new text of the line.
Future<void> _type(WidgetTester tester, int i, String text) async {
  await tester.enterText(find.byType(TextField).at(i), text);
  await tester.pump();
}

void main() {
  testWidgets('typing writes the note as Tiptap JSON', (tester) async {
    final changes = await _pump(tester, NoteFormat.emptyDoc());
    await _type(tester, 0, 'Read chapter 3');
    expect(NoteFormat.toPlainText(changes.last), 'Read chapter 3');
  });

  testWidgets('"- " and "[] " at the start of a line make a list', (
    tester,
  ) async {
    await _pump(tester, NoteFormat.emptyDoc());
    await _type(tester, 0, '- ');
    expect(_editor(tester).blocks.single.type, NoteBlockType.bullet);
    expect(_editor(tester).blocks.single.text, '');

    await _type(tester, 0, '');
    // Backspace at the start of a bullet makes it normal text again.
    await _type(tester, 0, '');
    await tester.pump();
    expect(_editor(tester).blocks.single.type, NoteBlockType.paragraph);

    await _type(tester, 0, '[x] ');
    final line = _editor(tester).blocks.single;
    expect((line.type, line.checked), (NoteBlockType.task, true));
  });

  testWidgets('Enter splits a list line, and on an empty one steps out', (
    tester,
  ) async {
    await _pump(tester, NoteFormat.fromPlainText('- Milk'));
    await _type(tester, 0, 'Milk\n');
    await tester.pump();
    var blocks = _editor(tester).blocks;
    expect(blocks.map((b) => (b.type, b.text)), [
      (NoteBlockType.bullet, 'Milk'),
      (NoteBlockType.bullet, ''),
    ]);

    await _type(tester, 1, '\n');
    await tester.pump();
    blocks = _editor(tester).blocks;
    expect(blocks.map((b) => b.type), [
      NoteBlockType.bullet,
      NoteBlockType.paragraph,
    ]);
  });

  testWidgets('Backspace at the start of a normal line joins the one above', (
    tester,
  ) async {
    await _pump(tester, NoteFormat.fromPlainText('one\ntwo'));
    // The second line loses its invisible first character.
    await _type(tester, 1, 'two');
    await tester.pump();
    final blocks = _editor(tester).blocks;
    expect(blocks.map((b) => b.text), ['onetwo']);
  });

  testWidgets('tapping a checklist box ticks it', (tester) async {
    final changes = await _pump(tester, NoteFormat.fromPlainText('[ ] eggs'));
    await tester.tapAt(
      tester.getTopLeft(find.byType(TextField).first) - const Offset(12, -8),
    );
    await tester.pump();
    expect(NoteFormat.checklistStats(changes.last), const Progress(1, 1));
  });

  testWidgets('a part the phone cannot edit is shown and kept in place', (
    tester,
  ) async {
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
    final changes = await _pump(tester, {
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
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('Edit this part on your PC'), findsOneWidget);

    await _type(tester, 0, 'Hello');
    final content = changes.last['content'] as List;
    expect(JsonEquality.equals(content[1], table), true);
  });

  group('StyledLineController', () {
    test('typing keeps the look of the text before it', () {
      final c = StyledLineController([
        InlineRun('Bold', marks: ['bold']),
      ]);
      c.value = TextEditingValue(
        text: '${StyledLineController.sentinel}Bolder',
        selection: const TextSelection.collapsed(offset: 7),
      );
      expect(c.runs, [
        InlineRun('Bolder', marks: ['bold']),
      ]);
    });

    test('bold on a selection, and a link keeps its address when edited '
        'inside', () {
      final c = StyledLineController([
        InlineRun('See '),
        InlineRun('syllabus', href: 'https://uni.example'),
      ]);
      c.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
      c.toggle('bold');
      expect(c.runs.first, InlineRun('See', marks: ['bold']));

      // Type inside the link: "sylla-bus".
      c.value = TextEditingValue(
        text: '${StyledLineController.sentinel}See sylla-bus',
        selection: const TextSelection.collapsed(offset: 11),
      );
      expect(c.runs.last, InlineRun('sylla-bus', href: 'https://uni.example'));

      // Typing right after the link is not part of it.
      c.value = TextEditingValue(
        text: '${StyledLineController.sentinel}See sylla-bus!',
        selection: const TextSelection.collapsed(offset: 15),
      );
      expect(c.runs.last, InlineRun('!'));
    });

    test('a tool tap with nothing selected sets the look of what is typed '
        'next', () {
      final c = StyledLineController([InlineRun('a')]);
      c.toggle('italic');
      c.value = TextEditingValue(
        text: '${StyledLineController.sentinel}ab',
        selection: const TextSelection.collapsed(offset: 3),
      );
      expect(c.runs, [
        InlineRun('a'),
        InlineRun('b', marks: ['italic']),
      ]);
    });
  });

  group('NoteAutosaver', () {
    test('writes after a pause, syncs a little later, and keeps only the '
        'newest', () async {
      final repo = _Recorder();
      var syncs = 0;
      final saver = NoteAutosaver(
        repo,
        () => syncs++,
        writeAfter: const Duration(milliseconds: 20),
        sendAfter: const Duration(milliseconds: 150),
      );
      final note = Task.createNote(title: 'a');
      saver.change(note);
      saver.change(note.copyWith(title: 'ab'));
      expect(repo.saved, isEmpty); // not on every key
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(repo.saved.map((t) => t.title), ['ab']);
      expect(syncs, 0);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(syncs, 1);
    });

    test('flush writes and syncs at once', () async {
      final repo = _Recorder();
      var syncs = 0;
      final saver = NoteAutosaver(repo, () => syncs++);
      saver.change(Task.createNote(title: 'x'));
      await saver.flush();
      expect(repo.saved, hasLength(1));
      expect(syncs, 1);
    });

    test('nothing changed, nothing written', () async {
      final repo = _Recorder();
      var syncs = 0;
      await NoteAutosaver(repo, () => syncs++).flush();
      expect(repo.saved, isEmpty);
      expect(syncs, 0);
    });
  });

  test('NotePlaces: Home, folders, and assignments under their folder', () {
    final asg = Task(
      id: 'a1',
      title: 'HW 2',
      end: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 10, 30),
      parentId: 'csc',
    );
    final places = NotePlaces(
      [const Destination(id: 'folder:csc', label: 'CSC101', name: 'CSC101')],
      [asg],
    );
    expect(places.entries.map((d) => d.id), [
      '',
      'folder:csc',
      'assignment:a1',
    ]);
    expect(places.entries.last.depth, 1);
    expect(places.idFor('a1'), 'assignment:a1');
    expect(places.idFor('csc'), 'folder:csc');
    expect(NotePlaces.parentIdFor('assignment:a1'), 'a1');
    expect(NotePlaces.parentIdFor(''), isNull);
    expect(places.nameOf('a1'), 'HW 2');
  });
}

/// Records what was saved.
class _Recorder implements TaskRepository {
  final saved = <Task>[];
  @override
  Future<List<Task>> all() async => saved;
  @override
  Future<void> delete(String id) async {}
  @override
  Future<Task?> get(String id) async => null;
  @override
  Future<void> save(Task task) async => saved.add(task);
}
