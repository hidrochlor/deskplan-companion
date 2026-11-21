import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/core/task_storage.dart';
import 'package:deskplan_companion/features/connection/destination.dart';
import 'package:deskplan_companion/features/pull/pull_applier.dart';
import 'package:deskplan_companion/features/pull/pull_reply.dart';
import 'package:deskplan_companion/features/queue/queue_processor.dart';
import 'package:deskplan_companion/features/queue/queued_task_repository.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';
import 'package:deskplan_companion/ui/course_names.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_uploader.dart';

/// What DeskPlan sends for an assignment. [course] and [source] are left out
/// entirely when [withCourse] is false, like a DeskPlan from before the
/// calendar.
Map<String, Object?> _pcEntry(
  String id, {
  String title = 'Essay',
  String? course = 'Climate Change and Dynamics',
  Map<String, Object?>? source,
  bool withCourse = true,
  String end = '2026-11-20T22:59:00.000Z',
  String updatedAt = '2026-10-30T08:15:00.000Z',
  String parentId = 'cc',
}) => {
  'id': id,
  'title': title,
  'start': null,
  'end': end,
  'done': false,
  'updatedAt': updatedAt,
  'kind': 'assignment',
  'parentId': parentId,
  'createdAt': '2026-10-01T07:00:00.000Z',
  'description': '',
  if (withCourse) 'course': course,
  if (withCourse) 'source': source,
};

PullReply _reply(List<Object?> items) => PullReply.fromJson({
  'items': items,
  'serverTime': '2026-11-02T10:00:00.000Z',
  'fullResync': false,
});

const _folders = [
  Destination.receivedFiles,
  Destination(id: 'folder:ws', label: 'WS 2026', name: 'WS 2026'),
  Destination(
    id: 'folder:cc',
    label: 'WS 2026 › Climate Change and Dynamics',
    name: 'Climate Change and Dynamics',
    depth: 1,
  ),
  Destination(id: 'folder:csc', label: 'CSC101', name: 'CSC101'),
  Destination(
    id: 'folder:w1',
    label: 'CSC101 › Week 1',
    name: 'Week 1',
    depth: 1,
  ),
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('course and source from DeskPlan', () {
    test('are read, and survive the database round trip', () {
      final t = Task.fromSyncJson(_pcEntry('a', source: {'label': 'Moodle'}));
      expect(t.course, 'Climate Change and Dynamics');
      expect(t.courseKnown, true);
      expect(t.sourceLabel, 'Moodle');
      expect(t.isImported, true);

      final back = Task.fromMap(t.toMap());
      expect(back.course, 'Climate Change and Dynamics');
      expect(back.courseKnown, true);
      expect(back.source, {'label': 'Moodle'});
    });

    test('a null course is a known one; a missing one is not', () {
      expect(Task.fromSyncJson(_pcEntry('a', course: null)).courseKnown, true);
      final old = Task.fromSyncJson(_pcEntry('a', withCourse: false));
      expect(old.courseKnown, false);
      expect(old.isImported, false);
    });

    test('are never sent back', () {
      final t = Task.fromSyncJson(
        _pcEntry('a', source: {'label': 'Moodle'}),
      ).copyWith(title: 'Edited');
      final body = t.toSyncJson();
      expect(body.containsKey('course'), false);
      expect(body.containsKey('source'), false);
    });

    test('a wrong shape is refused', () {
      expect(
        () => Task.fromSyncJson({..._pcEntry('a'), 'course': 3}),
        throwsFormatException,
      );
      expect(
        () => Task.fromSyncJson({..._pcEntry('a'), 'source': 'Moodle'}),
        throwsFormatException,
      );
    });

    test('an edit keeps them', () {
      final t = Task.fromSyncJson(
        _pcEntry('a', source: {'label': 'Moodle'}),
      ).copyWith(title: 'Edited');
      expect(t.course, 'Climate Change and Dynamics');
      expect(t.sourceLabel, 'Moodle');
    });
  });

  group('the course shown', () {
    test('is DeskPlan\'s, even inside a semester folder', () {
      final t = Task.fromSyncJson(_pcEntry('a'));
      expect(CourseNames(_folders, [t]).of(t), 'Climate Change and Dynamics');
    });

    test('a null course from DeskPlan shows none', () {
      final t = Task.fromSyncJson(_pcEntry('a', course: null));
      expect(CourseNames(_folders, [t]).of(t), null);
    });

    test('an older DeskPlan: the top-level folder stands in', () {
      final t = Task.fromSyncJson(
        _pcEntry('a', withCourse: false, parentId: 'w1'),
      );
      expect(CourseNames(_folders, [t]).of(t), 'CSC101');
    });

    test('an older DeskPlan: a step has its assignment\'s', () {
      final a = Task.fromSyncJson(
        _pcEntry('a', withCourse: false, parentId: 'w1'),
      );
      final step = Task(
        id: 's',
        title: 'Step',
        updatedAt: DateTime.utc(2026),
        parentId: 'a',
      );
      expect(CourseNames(_folders, [a, step]).of(step), 'CSC101');
    });
  });

  group('reaching the phone', () {
    late AppDatabase database;
    late TaskStorage tasks;
    late SqliteActionQueue queue;

    setUp(() {
      database = AppDatabase(path: inMemoryDatabasePath);
      tasks = TaskStorage(database);
      queue = SqliteActionQueue(database);
    });

    tearDown(() => database.close());

    test('a pull brings them', () async {
      await PullApplier(tasks, queue).apply(
        _reply([
          _pcEntry('a', source: {'label': 'Moodle'}),
        ]),
      );
      final a = (await tasks.get('a'))!;
      expect(a.course, 'Climate Change and Dynamics');
      expect(a.sourceLabel, 'Moodle');
    });

    test('a pull with only a new course still changes it', () async {
      await PullApplier(tasks, queue).apply(_reply([_pcEntry('a')]));
      final changed = await PullApplier(
        tasks,
        queue,
      ).apply(_reply([_pcEntry('a', course: 'Renamed')]));
      expect(changed, 1);
      expect((await tasks.get('a'))!.course, 'Renamed');
    });

    test('a pull from an older DeskPlan keeps what the phone has', () async {
      await PullApplier(tasks, queue).apply(
        _reply([
          _pcEntry('a', source: {'label': 'Moodle'}),
        ]),
      );
      await PullApplier(tasks, queue).apply(
        _reply([
          _pcEntry(
            'a',
            withCourse: false,
            title: 'New',
            updatedAt: '2026-10-31T08:15:00.000Z',
          ),
        ]),
      );
      final a = (await tasks.get('a'))!;
      expect(a.title, 'New');
      expect(a.course, 'Climate Change and Dynamics');
      expect(a.sourceLabel, 'Moodle');
    });

    test('an "updated" reply to a PUT brings them', () async {
      final app = QueuedTaskRepository(database, tasks, queue);
      final mine = Task.create(
        title: 'Essay',
        end: DateTime.utc(2026, 11, 20),
        kind: TaskKind.assignment,
        parentId: 'cc',
      );
      await app.save(mine);
      final uploader = FakeUploader()
        ..next = (_) => Confirmed(
          stored: Task.fromSyncJson({
            ..._pcEntry(mine.id, updatedAt: mine.updatedAt.toIso8601String()),
            'end': mine.end!.toIso8601String(),
          }),
        );

      await QueueProcessor(
        queue: queue,
        repository: tasks,
        uploader: uploader,
      ).run();

      final now = (await tasks.get(mine.id))!;
      expect(now.course, 'Climate Change and Dynamics');
      expect(now.courseKnown, true);
      expect(now.title, 'Essay');
      expect(await queue.hasPending(mine.id), false);
    });
  });
}
