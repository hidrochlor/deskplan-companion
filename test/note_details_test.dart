import 'dart:async';

import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_repository.dart';
import 'package:deskplan_companion/features/connection/destination.dart';
import 'package:deskplan_companion/features/queue/sync_report.dart';
import 'package:deskplan_companion/ui/notes/note_details_sheet.dart';
import 'package:deskplan_companion/ui/notes/note_page.dart';
import 'package:deskplan_companion/ui/notes/note_places.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Memory implements TaskRepository {
  final items = <String, Task>{};
  @override
  Future<List<Task>> all() async => items.values.toList();
  @override
  Future<void> delete(String id) async => items.remove(id);
  @override
  Future<Task?> get(String id) async => items[id];
  @override
  Future<void> save(Task task) async => items[task.id] = task;
}

void main() {
  test('words are counted like a word processor', () {
    expect(NoteDetailsSheet.wordCount(''), 0);
    expect(NoteDetailsSheet.wordCount('Read chapter 3'), 3);
    expect(NoteDetailsSheet.wordCount("don't  stop -\nnow"), 3);
  });

  test('a location is the whole path from Home', () {
    final places = NotePlaces(
      [
        const Destination(id: 'folder:csc', label: 'CSC101', name: 'CSC101'),
        const Destination(
          id: 'folder:w1',
          label: 'CSC101 › Week 1',
          name: 'Week 1',
          depth: 1,
        ),
      ],
      [
        Task.fromSyncJson({
          'id': 'hw',
          'title': 'HW 2',
          'start': null,
          'end': null,
          'done': false,
          'updatedAt': '2026-10-30T08:15:00.000Z',
          'kind': 'assignment',
          'parentId': 'w1',
        }),
      ],
    );
    expect(places.pathOf(null), 'Home');
    expect(places.pathOf('w1'), 'Home › CSC101 › Week 1');
    expect(places.pathOf('hw'), 'Home › CSC101 › Week 1 › HW 2');
    expect(places.pathOf('unknown'), 'Home');
  });

  testWidgets('the note page shows its details: place, course, times, size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final reports = StreamController<SyncReport>.broadcast();
    addTearDown(reports.close);

    final note = Task.fromSyncJson({
      'id': 'n',
      'title': 'Week 3',
      'start': null,
      'end': null,
      'done': false,
      'updatedAt': '2026-10-30T08:15:00.000Z',
      'kind': 'note',
      'parentId': 'csc',
      'createdAt': '2026-10-01T07:00:00.000Z',
      'course': 'CSC101',
      'doc': {
        'type': 'doc',
        'content': [
          {
            'type': 'heading',
            'attrs': {'level': 1},
            'content': [
              {'type': 'text', 'text': 'Week 3'},
            ],
          },
          {
            'type': 'taskList',
            'content': [
              {
                'type': 'taskItem',
                'attrs': {'checked': true},
                'content': [
                  {
                    'type': 'paragraph',
                    'content': [
                      {'type': 'text', 'text': 'Read slides'},
                    ],
                  },
                ],
              },
              {
                'type': 'taskItem',
                'attrs': {'checked': false},
                'content': [
                  {
                    'type': 'paragraph',
                    'content': [
                      {'type': 'text', 'text': 'Do exercises'},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    });
    final repo = _Memory()..items['n'] = note;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NotePage(
          note: note,
          repository: repo,
          syncNow: () {},
          syncReports: reports.stream,
          places: NotePlaces([
            const Destination(
              id: 'folder:csc',
              label: 'CSC101',
              name: 'CSC101',
            ),
          ], const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Details is the info icon only, not in the ⋮ menu as well.
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Details'));
    await tester.pumpAndSettle();

    final sheet = find.byType(NoteDetailsSheet);
    expect(sheet, findsOneWidget);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet('Location'), findsOneWidget);
    expect(inSheet('Home › CSC101'), findsOneWidget);
    expect(inSheet('Course'), findsOneWidget);
    expect(inSheet('Created'), findsOneWidget);
    expect(inSheet('Last changed'), findsOneWidget);
    expect(inSheet('Words'), findsOneWidget);
    expect(inSheet('6'), findsOneWidget); // Week 3, Read slides, Do exercises
    expect(inSheet('1 of 2 ticked'), findsOneWidget);
    expect(inSheet('Headings'), findsOneWidget);
    // Read-only: nothing to edit or delete here.
    expect(
      find.descendant(of: sheet, matching: find.byType(TextField)),
      findsNothing,
    );
  });
}
