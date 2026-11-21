import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_repository.dart';
import 'package:deskplan_companion/core/task_storage.dart';
import 'package:deskplan_companion/features/pull/pull_applier.dart';
import 'package:deskplan_companion/features/pull/pull_reply.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/ui/assignment_sheet.dart';
import 'package:deskplan_companion/ui/date_time_field.dart';
import 'package:deskplan_companion/ui/source_badge.dart';
import 'package:deskplan_companion/ui/task_sheet.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A Moodle assignment as DeskPlan sends it (protocol.md section 4
/// "Imported assignments").
Map<String, Object?> _moodle({
  String title = 'Essay 1',
  String end = '2026-11-20T22:59:00.000Z',
  String updatedAt = '2026-10-30T08:15:00.000Z',
}) => {
  'id': 'm1',
  'title': title,
  'start': null,
  'end': end,
  'done': false,
  'updatedAt': updatedAt,
  'kind': 'assignment',
  'parentId': 'cc',
  'createdAt': '2026-10-01T07:00:00.000Z',
  'description': '',
  'course': 'Climate Change and Dynamics',
  'source': {'label': 'Moodle'},
};

/// How the sheet writes [utc]'s day in this machine's time zone (en-US).
String _shortDate(String utc) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final d = DateTime.parse(utc).toLocal();
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// The phone's items, kept in memory.
class _MemoryRepository implements TaskRepository {
  final Map<String, Task> items = {};

  @override
  Future<List<Task>> all() async => items.values.toList();
  @override
  Future<Task?> get(String id) async => items[id];
  @override
  Future<void> save(Task task) async => items[task.id] = task;
  @override
  Future<void> delete(String id) async => items.remove(id);
}

Future<void> _openSheet(
  WidgetTester tester,
  List<Object?> results,
  Task task,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                results.add(await TaskSheet.show(context, task: task)),
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
  final imported = Task.fromSyncJson(_moodle());

  testWidgets('the due field is not editable, and says who set it', (
    tester,
  ) async {
    await _openSheet(tester, [], imported);

    expect(find.byType(DateTimeField), findsNothing);
    expect(find.text('Today'), findsNothing); // no quick due buttons
    expect(find.textContaining('Set by Moodle'), findsOneWidget);
    expect(find.byType(SourceBadge), findsOneWidget);

    await tester.tap(find.byKey(const Key('feed-due')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('title, details and Submitted stay editable', (tester) async {
    await _openSheet(tester, [], imported);
    expect(find.byType(TextFormField), findsOneWidget);
    final details = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Details'),
    );
    expect(details.enabled, true);
    expect(find.text('Submitted'), findsOneWidget);
  });

  testWidgets('a saved title edit sends the old end', (tester) async {
    final results = <Object?>[];
    await _openSheet(tester, results, imported);

    await tester.enterText(find.byType(TextFormField), 'Essay 1 (draft)');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = results.single as Task;
    expect(saved.title, 'Essay 1 (draft)');
    expect(saved.toSyncJson()['end'], '2026-11-20T22:59:00.000Z');
    expect(saved.toSyncJson()['start'], null);
    expect(saved.isImported, true);
  });

  test('a reply to a PUT keeps the feed\'s end', () {
    final mine = imported.copyWith(
      title: 'Edited',
      end: DateTime.utc(2026, 12, 1),
    );
    final reply = Task.fromSyncJson(_moodle(title: 'Edited'));
    final now = reply.serverFieldsOnto(mine);
    expect(now.end, DateTime.utc(2026, 11, 20, 22, 59));
    expect(now.title, 'Edited');
  });

  group('a pull', () {
    late AppDatabase database;

    setUp(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      database = AppDatabase(path: inMemoryDatabasePath);
    });

    tearDown(() => database.close());

    test('with a newer end replaces the shown one', () async {
      final tasks = TaskStorage(database);
      final queue = SqliteActionQueue(database);
      await tasks.save(imported);

      await PullApplier(tasks, queue).apply(
        PullReply.fromJson({
          'items': [
            _moodle(
              end: '2026-11-27T22:59:00.000Z',
              updatedAt: '2026-11-01T09:00:00.000Z',
            ),
          ],
          'serverTime': '2026-11-02T10:00:00.000Z',
          'fullResync': false,
        }),
      );

      expect((await tasks.get('m1'))!.end, DateTime.utc(2026, 11, 27, 22, 59));
    });
  });

  testWidgets('the assignment sheet shows the new due date after a pull', (
    tester,
  ) async {
    final repo = _MemoryRepository()..items['m1'] = imported;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AssignmentSheet.show(
                context,
                assignmentId: 'm1',
                repository: repo,
                folders: const [],
                onChanged: () async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Set by Moodle'), findsOneWidget);
    expect(
      find.textContaining(_shortDate('2026-11-20T22:59:00Z')),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.byType(AssignmentSheet))).pop();
    await tester.pumpAndSettle();
    repo.items['m1'] = Task.fromSyncJson(
      _moodle(
        end: '2026-11-27T22:59:00.000Z',
        updatedAt: '2026-11-01T09:00:00.000Z',
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(_shortDate('2026-11-27T22:59:00Z')),
      findsOneWidget,
    );
  });

  testWidgets('deleting asks with the feed\'s warning', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final repo = _MemoryRepository()..items['m1'] = imported;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AssignmentSheet.show(
                context,
                assignmentId: 'm1',
                repository: repo,
                folders: const [],
                onChanged: () async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        "Moodle won't add it back. You can restore it on your PC in "
        'Settings › Data.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(repo.items.containsKey('m1'), true);
  });
}
