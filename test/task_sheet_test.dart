import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/features/connection/destination.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:deskplan_companion/ui/task_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _folders = [
  Destination(id: 'folder:csc', label: 'CSC101', name: 'CSC101'),
  Destination(
    id: 'folder:wk1',
    label: 'CSC101 › Week 1',
    name: 'Week 1',
    depth: 1,
  ),
];

/// Opens the sheet from a button and collects what it pops with.
Future<void> _open(
  WidgetTester tester,
  List<Object?> results, {
  Task? task,
  TaskKind kind = TaskKind.task,
  String? fixedParentId,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(
              await TaskSheet.show(
                context,
                task: task,
                kind: kind,
                folders: _folders,
                fixedParentId: fixedParentId,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an assignment cannot be saved without a folder and a due time', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(tester, results, kind: TaskKind.assignment);

    await tester.enterText(find.byType(TextFormField), 'Homework 2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('An assignment needs a folder'), findsOneWidget);
    expect(find.text('An assignment needs a due time'), findsOneWidget);
    expect(results, isEmpty); // the sheet stays open
  });

  testWidgets('an assignment with a folder and due time is saved as one', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(tester, results, kind: TaskKind.assignment);

    await tester.enterText(find.byType(TextFormField), 'Homework 2');
    await tester.tap(find.text('Choose a folder'));
    await tester.pumpAndSettle();
    // Week 1 is inside CSC101, which starts closed.
    await tester.tap(find.byTooltip('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = results.single as Task;
    expect(saved.kind, TaskKind.assignment);
    expect(saved.parentId, 'wk1'); // the id without the "folder:" prefix
    expect(saved.end, isNotNull);
  });

  testWidgets('a task can be put in a folder, or left in Home', (tester) async {
    final results = <Object?>[];
    await _open(tester, results);

    await tester.enterText(find.byType(TextFormField), 'Read chapter 3');
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSC101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = results.single as Task;
    expect(saved.kind, TaskKind.task);
    expect(saved.parentId, 'csc');
  });

  testWidgets('a step stays in its assignment and has no place picker', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(tester, results, fixedParentId: 'asg-1');

    expect(find.text('New step'), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Do question 1');
    await tester.tap(find.text('Next hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((results.single as Task).parentId, 'asg-1');
  });

  testWidgets('a new task or step needs both From and To', (tester) async {
    final results = <Object?>[];
    await _open(tester, results, fixedParentId: 'asg-1');

    await tester.enterText(find.byType(TextFormField), 'Do question 1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('A task needs a From and a To time'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('a time block saves its start and end, From before To', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(tester, results);

    await tester.enterText(find.byType(TextFormField), 'Study');
    await tester.tap(find.text('Tomorrow 9:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = results.single as Task;
    expect(saved.start, isNotNull);
    expect(saved.end!.difference(saved.start!), const Duration(hours: 1));
    expect(saved.toSyncJson()['start'], isNotNull);
  });

  testWidgets('From equal to To is refused', (tester) async {
    final results = <Object?>[];
    final at = DateTime.utc(2026, 11, 1, 9);
    final block = Task(
      id: 'b',
      title: 'Block',
      start: at,
      end: at.add(const Duration(hours: 1)),
      updatedAt: DateTime.utc(2026, 10, 30),
    );
    // The same task, but its end moved onto its start (as if picked so).
    await _open(
      tester,
      results,
      task: block.copyWith(end: at, updatedAt: block.updatedAt),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('From must be earlier than To'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('a task with a start keeps it: no way to clear it', (
    tester,
  ) async {
    final results = <Object?>[];
    final block = Task(
      id: 'b',
      title: 'Block',
      start: DateTime.utc(2026, 11, 1, 9),
      end: DateTime.utc(2026, 11, 1, 10),
      updatedAt: DateTime.utc(2026, 10, 30),
    );
    await _open(tester, results, task: block);

    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.byTooltip('Clear'), findsNothing);
  });

  testWidgets('an old due-time-only task may stay so, or get a start', (
    tester,
  ) async {
    final results = <Object?>[];
    final old = Task(
      id: 'o',
      title: 'Old deadline',
      end: DateTime.utc(2026, 11, 1, 9),
      updatedAt: DateTime.utc(2026, 10, 30),
    );
    await _open(tester, results, task: old);

    expect(find.text('Due'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((results.single as Task).start, isNull);
  });

  testWidgets('an assignment is offered no start, and never sends one', (
    tester,
  ) async {
    final results = <Object?>[];
    final oldWithStart = Task(
      id: 'a',
      title: 'HW',
      start: DateTime.utc(2026, 10, 31),
      end: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 10, 30),
      kind: TaskKind.assignment,
      parentId: 'csc',
    );
    await _open(tester, results, task: oldWithStart);

    expect(find.text('From'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = results.single as Task;
    expect(saved.start, isNull);
    expect(saved.toSyncJson()['start'], isNull);
  });

  testWidgets('Cancel drops the draft', (tester) async {
    final results = <Object?>[];
    final known = Task(
      id: 'k',
      title: 'Old title',
      updatedAt: DateTime.utc(2026, 10, 30),
    );
    await _open(tester, results, task: known);
    await tester.enterText(find.byType(TextFormField), 'Half typed');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results.single, isNull);
  });

  testWidgets('an assignment says Submitted instead of Done', (tester) async {
    final results = <Object?>[];
    final assignment = Task(
      id: 'a',
      title: 'HW',
      end: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 10, 30),
      kind: TaskKind.assignment,
      parentId: 'csc',
    );
    await _open(tester, results, task: assignment);

    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Not submitted'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets(
    'an old task that does not know its place is not moved by an edit',
    (tester) async {
      final results = <Object?>[];
      final legacy = Task(
        id: 'old',
        title: 'Old task',
        updatedAt: DateTime.utc(2026, 10, 30),
        placeKnown: false,
      );
      await _open(tester, results, task: legacy);

      expect(find.text('Home'), findsNothing); // no picker to move it with
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = results.single as Task;
      expect(
        saved.placeKnown,
        false,
      ); // so kind and parentId are still not sent
    },
  );

  testWidgets('details written on a new task are sent, none means none', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(tester, results);
    await tester.enterText(find.byType(TextFormField), 'Read chapter 3');
    await tester.enterText(
      find.widgetWithText(TextField, 'Details'),
      'Pages 3 to 9',
    );
    await tester.tap(find.text('Next hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final withNotes = results.single as Task;
    expect(withNotes.details, 'Pages 3 to 9');
    expect(withNotes.toSyncJson()['description'], 'Pages 3 to 9');

    final plain = <Object?>[];
    await _open(tester, plain);
    await tester.enterText(find.byType(TextFormField), 'Another');
    await tester.tap(find.text('Next hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      (plain.single as Task).toSyncJson().containsKey('description'),
      false,
    );
  });

  testWidgets('editing only the title never sends the description', (
    tester,
  ) async {
    final results = <Object?>[];
    final known = Task(
      id: 'k',
      title: 'Old title',
      updatedAt: DateTime.utc(2026, 10, 30),
      details: 'typed on the PC',
      createdAt: DateTime.utc(2026, 10, 1),
      createdKnown: true,
    );
    await _open(tester, results, task: known);
    await tester.enterText(find.byType(TextFormField), 'New title');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = results.single as Task;
    expect(saved.title, 'New title');
    expect(saved.details, 'typed on the PC');
    expect(saved.toSyncJson().containsKey('description'), false);
  });

  testWidgets('changing the details sends them', (tester) async {
    final results = <Object?>[];
    final known = Task(
      id: 'k',
      title: 'Title',
      updatedAt: DateTime.utc(2026, 10, 30),
      details: 'old',
    );
    await _open(tester, results, task: known);
    await tester.enterText(
      find.widgetWithText(TextField, 'Details'),
      'rewritten',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((results.single as Task).toSyncJson()['description'], 'rewritten');
  });

  testWidgets('details wait for DeskPlan on a task that has not heard them', (
    tester,
  ) async {
    final results = <Object?>[];
    final legacy = Task(
      id: 'o',
      title: 'Old',
      updatedAt: DateTime.utc(2026, 10, 30),
      detailsKnown: false,
    );
    await _open(tester, results, task: legacy);
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Details'),
    );
    expect(field.enabled, false);
    expect(find.textContaining('Sync with DeskPlan first'), findsOneWidget);
  });
}
