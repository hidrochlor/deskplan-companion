import 'dart:io';

import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/core/task_storage.dart';
import 'package:deskplan_companion/core/task_tree.dart';
import 'package:deskplan_companion/features/pull/pull_applier.dart';
import 'package:deskplan_companion/features/pull/pull_reply.dart';
import 'package:deskplan_companion/features/queue/parents_first_order.dart';
import 'package:deskplan_companion/features/queue/queued_task_repository.dart';
import 'package:deskplan_companion/features/queue/queue_processor.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/features/queue/sync_action.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_uploader.dart';

Task _task(
  String id, {
  TaskKind kind = TaskKind.task,
  String? parentId,
  bool done = false,
  String updatedAt = '2026-10-30T08:15:00Z',
}) => Task(
  id: id,
  title: id,
  end: kind == TaskKind.assignment ? DateTime.utc(2026, 11, 1) : null,
  done: done,
  updatedAt: DateTime.parse(updatedAt),
  kind: kind,
  parentId: parentId,
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Task kind and parentId', () {
    test('are sent on every save', () {
      final json = Task.create(
        title: 'HW',
        kind: TaskKind.assignment,
        parentId: '7c1e',
        end: DateTime.utc(2026, 11, 1),
      ).toSyncJson();
      expect(json['kind'], 'assignment');
      expect(json['parentId'], '7c1e');
    });

    test('a top-level task sends parentId null, which means Home', () {
      final json = Task.create(title: 'A').toSyncJson();
      expect(json['kind'], 'task');
      expect(json.containsKey('parentId'), true);
      expect(json['parentId'], isNull);
    });

    test('an unknown place is left out, so DeskPlan keeps its own', () {
      final legacy = Task(
        id: 'a',
        title: 'old',
        updatedAt: DateTime.utc(2026),
        placeKnown: false,
      );
      final json = legacy.toSyncJson();
      expect(json.containsKey('kind'), false);
      expect(json.containsKey('parentId'), false);
    });

    test('choosing a place makes it known', () {
      final legacy = Task(
        id: 'a',
        title: 'old',
        updatedAt: DateTime.utc(2026),
        placeKnown: false,
      );
      expect(legacy.copyWith(title: 'edited').placeKnown, false);
      expect(legacy.copyWith(parentId: 'f1').placeKnown, true);
      expect(legacy.copyWith(clearParent: true).placeKnown, true);
    });

    test('are read from DeskPlan replies, with the place known', () {
      final t = Task.fromSyncJson({
        'id': 'a',
        'title': 'x',
        'start': null,
        'end': null,
        'done': false,
        'updatedAt': '2026-10-30T08:15:00.000Z',
        'kind': 'assignment',
        'parentId': '9d2f',
      });
      expect(t.kind, TaskKind.assignment);
      expect(t.parentId, '9d2f');
      expect(t.placeKnown, true);
    });

    test('an older DeskPlan with neither leaves the place unknown', () {
      final t = Task.fromSyncJson({
        'id': 'a',
        'title': 'x',
        'start': null,
        'end': null,
        'done': false,
        'updatedAt': '2026-10-30T08:15:00.000Z',
      });
      expect(t.placeKnown, false);
      expect(t.kind, TaskKind.task);
    });

    test('a kind that is not task or assignment is refused', () {
      expect(
        () => Task.fromSyncJson({
          'id': 'a',
          'title': 'x',
          'done': false,
          'updatedAt': '2026-10-30T08:15:00Z',
          'kind': 'folder',
          'parentId': null,
        }),
        throwsFormatException,
      );
    });

    test('survive the database round trip', () {
      final t = _task('s', parentId: 'asg');
      final back = Task.fromMap(t.toMap());
      expect(back.parentId, 'asg');
      expect(back.kind, TaskKind.task);
      expect(back.placeKnown, true);
    });
  });

  group('database version 4', () {
    test('old tasks keep their data and do not know their place', () async {
      final dir = await Directory.systemTemp.createTemp('deskplan_v3');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/v3.db';
      final old = await openDatabase(
        path,
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, '
            'start TEXT, end TEXT, done INTEGER NOT NULL DEFAULT 0, '
            'updatedAt TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE sync_queue (seq INTEGER PRIMARY KEY AUTOINCREMENT, '
            'taskId TEXT NOT NULL UNIQUE, type TEXT NOT NULL, '
            'attempts INTEGER NOT NULL DEFAULT 0, '
            'nextAttemptAt INTEGER NOT NULL, lastError TEXT)',
          );
          await db.execute(
            'CREATE TABLE uploads (uploadId TEXT PRIMARY KEY, '
            'localPath TEXT NOT NULL, displayName TEXT NOT NULL, '
            'destId TEXT NOT NULL, sizeBytes INTEGER NOT NULL, '
            'status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, '
            'nextAttemptAt INTEGER NOT NULL, lastError TEXT, '
            'createdAt INTEGER NOT NULL, sentAt INTEGER)',
          );
        },
      );
      await old.insert('tasks', {
        'id': 'a',
        'title': 'kept',
        'done': 0,
        'updatedAt': '2026-11-01T09:00:00.000Z',
      });
      await old.close();

      final database = AppDatabase(path: path);
      addTearDown(database.close);
      final task = (await TaskStorage(database).get('a'))!;

      expect(task.title, 'kept');
      expect(task.kind, TaskKind.task);
      expect(task.parentId, isNull);
      expect(task.placeKnown, false);
    });
  });

  group('TaskTree', () {
    final tasks = [
      _task('folderTask', parentId: 'folder1'),
      _task('asg', kind: TaskKind.assignment, parentId: 'folder1'),
      _task('s1', parentId: 'asg', done: true),
      _task('s2', parentId: 'asg'),
      _task('home'),
    ];
    final tree = TaskTree(tasks);

    test('steps are tasks inside an assignment, and leave the main list', () {
      expect(tree.isStep(tasks[2]), true);
      expect(tree.isStep(tasks[0]), false);
      expect(tree.listed.map((t) => t.id), ['folderTask', 'asg', 'home']);
    });

    test('progress counts finished steps out of all steps', () {
      final p = tree.progressOf('asg');
      expect((p.done, p.total), (1, 2));
      expect(tree.progressOf('home').isEmpty, true);
    });

    test('delete order puts steps before their assignment', () {
      final order = tree
          .withDescendantsChildrenFirst(tasks[1])
          .map((t) => t.id)
          .toList();
      expect(order.last, 'asg');
      expect(order.toSet(), {'s1', 's2', 'asg'});
    });
  });

  group('sending order', () {
    late AppDatabase database;
    late TaskStorage plain;
    late SqliteActionQueue queue;
    late QueuedTaskRepository app;
    late FakeUploader uploader;
    late QueueProcessor processor;

    setUp(() {
      database = AppDatabase(path: inMemoryDatabasePath);
      plain = TaskStorage(database);
      queue = SqliteActionQueue(database);
      app = QueuedTaskRepository(database, plain, queue);
      uploader = FakeUploader();
      processor = QueueProcessor(
        queue: queue,
        repository: plain,
        uploader: uploader,
      );
    });

    tearDown(() => database.close());

    test(
      'an assignment edited after its steps are added still goes first',
      () async {
        final asg = Task.create(
          title: 'HW',
          kind: TaskKind.assignment,
          parentId: 'folder1',
          end: DateTime.utc(2026, 11, 1),
        );
        await app.save(asg);
        final step = Task.create(title: 'step', parentId: asg.id);
        await app.save(step);
        await app.save(asg.copyWith(title: 'HW 2')); // now newer than the step

        await processor.run();

        expect(uploader.calls, ['save ${asg.id}', 'save ${step.id}']);
      },
    );

    test('a step waits while its assignment is still queued', () async {
      final asg = Task.create(
        title: 'HW',
        kind: TaskKind.assignment,
        parentId: 'folder1',
        end: DateTime.utc(2026, 11, 1),
      );
      final step = Task.create(title: 'step', parentId: asg.id);
      await app.save(asg);
      await app.save(step);
      uploader.next = (call) => call == 'save ${asg.id}'
          ? const RetryLater('busy')
          : throw StateError('the step must not be sent yet');

      await processor.run();

      expect(uploader.calls, ['save ${asg.id}']);
      expect(await queue.hasPending(step.id), true); // still waiting
    });

    test('deletes keep their order: steps before the assignment', () async {
      final asg = Task.create(
        title: 'HW',
        kind: TaskKind.assignment,
        parentId: 'folder1',
        end: DateTime.utc(2026, 11, 1),
      );
      final step = Task.create(title: 'step', parentId: asg.id);
      await plain.save(asg);
      await plain.save(step);
      await app.delete(step.id);
      await app.delete(asg.id);

      await processor.run();

      expect(uploader.calls, ['delete ${step.id}', 'delete ${asg.id}']);
    });

    test('ParentsFirstOrder alone: saves by depth, deletes last', () async {
      final asg = Task.create(
        title: 'HW',
        kind: TaskKind.assignment,
        parentId: 'f',
        end: DateTime.utc(2026, 11, 1),
      );
      final step = Task.create(title: 's', parentId: asg.id);
      await plain.save(asg);
      await plain.save(step);
      final actions = [
        SyncAction(
          seq: 1,
          taskId: step.id,
          type: ActionType.save,
          attempts: 0,
          nextAttemptAt: DateTime.utc(2026),
        ),
        SyncAction(
          seq: 2,
          taskId: 'gone',
          type: ActionType.delete,
          attempts: 0,
          nextAttemptAt: DateTime.utc(2026),
        ),
        SyncAction(
          seq: 3,
          taskId: asg.id,
          type: ActionType.save,
          attempts: 0,
          nextAttemptAt: DateTime.utc(2026),
        ),
      ];
      final ordered = await ParentsFirstOrder(plain).order(actions);
      expect(ordered.map((a) => a.seq), [3, 1, 2]);
    });
  });

  group('pull with assignments', () {
    late AppDatabase database;
    late TaskStorage tasks;
    late SqliteActionQueue queue;
    late PullApplier applier;

    setUp(() {
      database = AppDatabase(path: inMemoryDatabasePath);
      tasks = TaskStorage(database);
      queue = SqliteActionQueue(database);
      applier = PullApplier(tasks, queue);
    });

    tearDown(() => database.close());

    Map<String, Object?> entry(
      String id, {
      String kind = 'task',
      String? parentId,
    }) => {
      'id': id,
      'title': id,
      'start': null,
      'end': kind == 'assignment' ? '2026-11-01T09:00:00.000Z' : null,
      'done': false,
      'updatedAt': '2026-10-30T08:15:00.000Z',
      'kind': kind,
      'parentId': parentId,
    };

    PullReply reply(List<Object?> items) => PullReply.fromJson({
      'items': items,
      'serverTime': '2026-11-02T10:00:00.000Z',
      'fullResync': false,
    });

    test('brings the assignment, its steps and where they live', () async {
      await applier.apply(
        reply([
          entry('asg', kind: 'assignment', parentId: 'f1'),
          entry('s1', parentId: 'asg'),
        ]),
      );
      expect((await tasks.get('asg'))!.kind, TaskKind.assignment);
      expect((await tasks.get('asg'))!.parentId, 'f1');
      expect((await tasks.get('s1'))!.parentId, 'asg');
    });

    test(
      'a move on the PC changes parentId even if nothing else changed',
      () async {
        await applier.apply(reply([entry('t', parentId: 'f1')]));
        final changed = await applier.apply(
          reply([entry('t', parentId: 'f2')]),
        );
        expect(changed, 1);
        expect((await tasks.get('t'))!.parentId, 'f2');
      },
    );

    test(
      'deleting an assignment also clears the steps the phone knows',
      () async {
        await applier.apply(
          reply([
            entry('asg', kind: 'assignment', parentId: 'f1'),
            entry('s1', parentId: 'asg'),
            entry('s2', parentId: 'asg'),
            entry('other'),
          ]),
        );
        await applier.apply(
          reply([
            {'id': 'asg', 'deleted': true},
          ]),
        );
        expect(await tasks.get('asg'), isNull);
        expect(await tasks.get('s1'), isNull);
        expect(await tasks.get('s2'), isNull);
        expect(await tasks.get('other'), isNotNull);
      },
    );

    test(
      'a step with an unsent change survives its assignment\'s deletion',
      () async {
        await applier.apply(
          reply([
            entry('asg', kind: 'assignment', parentId: 'f1'),
            entry('s1', parentId: 'asg'),
          ]),
        );
        await queue.enqueue('s1', ActionType.save);
        await applier.apply(
          reply([
            {'id': 'asg', 'deleted': true},
          ]),
        );
        expect(await tasks.get('s1'), isNotNull);
      },
    );
  });
}
