import 'dart:io';

import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_storage.dart';
import 'package:deskplan_companion/features/pull/pull_applier.dart';
import 'package:deskplan_companion/features/pull/pull_reply.dart';
import 'package:deskplan_companion/features/queue/queued_task_repository.dart';
import 'package:deskplan_companion/features/queue/queue_processor.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_uploader.dart';

/// What DeskPlan sends for a task. [description] and [createdAt] are left out
/// entirely when null, like an older DeskPlan does.
Map<String, Object?> _pcEntry(
  String id, {
  String title = 'from PC',
  String? description,
  String? createdAt,
}) => {
  'id': id,
  'title': title,
  'start': null,
  'end': null,
  'done': false,
  'updatedAt': '2026-10-30T08:15:00.000Z',
  'kind': 'task',
  'parentId': null,
  'description': ?description,
  'createdAt': ?createdAt,
};

PullReply _reply(List<Object?> items) => PullReply.fromJson({
  'items': items,
  'serverTime': '2026-11-02T10:00:00.000Z',
  'fullResync': false,
});

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('details (DeskPlan\'s description)', () {
    test('a new task has empty, known details and a creation time', () {
      final before = DateTime.now().toUtc();
      final t = Task.create(title: 'A');
      expect(t.details, '');
      expect(t.detailsKnown, true);
      expect(t.createdAt.isBefore(before), false);
    });

    test(
      'are sent only when the user edited them, never the creation time',
      () {
        final fresh = Task.create(title: 'A');
        expect(fresh.toSyncJson().containsKey('description'), false);

        final edited = fresh.copyWith(details: 'Bring the book');
        expect(edited.toSyncJson()['description'], 'Bring the book');
        expect(edited.toSyncJson().containsKey('createdAt'), false);
        expect(edited.toSyncJson().containsKey('details'), false);

        // Still marked until DeskPlan confirms it, even across other edits.
        expect(
          edited.copyWith(title: 'B').toSyncJson()['description'],
          isNotNull,
        );
        // Once confirmed, a title edit leaves the PC's description alone.
        final confirmed = edited.copyWith(detailsEdited: false);
        expect(
          confirmed
              .copyWith(title: 'C')
              .toSyncJson()
              .containsKey('description'),
          false,
        );
      },
    );

    test('clearing the details sends an empty description', () {
      final known = Task.fromSyncJson(_pcEntry('a', description: 'old'));
      expect(known.copyWith(details: '').toSyncJson()['description'], '');
    });

    test('not seen yet: an edit makes them known, a title edit does not', () {
      final old = Task(
        id: 'a',
        title: 'old',
        updatedAt: DateTime.utc(2026),
        detailsKnown: false,
      );
      expect(old.toSyncJson().containsKey('description'), false);
      expect(old.copyWith(title: 'edited').detailsKnown, false);
      expect(old.copyWith(details: 'now written').detailsKnown, true);
    });

    test('are read from DeskPlan, with the creation time', () {
      final t = Task.fromSyncJson(
        _pcEntry(
          'a',
          description: 'From the PC',
          createdAt: '2026-10-01T07:00:00.000Z',
        ),
      );
      expect(t.details, 'From the PC');
      expect(t.detailsKnown, true);
      expect(t.createdAt, DateTime.utc(2026, 10, 1, 7));
      expect(t.createdKnown, true);
    });

    test('an older DeskPlan sends neither, and they stay unknown', () {
      final t = Task.fromSyncJson(_pcEntry('a'));
      expect(t.detailsKnown, false);
      expect(t.createdKnown, false);
      expect(t.detailsEdited, false);
    });

    test('an empty description from DeskPlan is still a known one', () {
      final t = Task.fromSyncJson(_pcEntry('a', description: ''));
      expect(t.detailsKnown, true);
      expect(t.toSyncJson().containsKey('description'), false); // not edited
    });

    test('survive the database round trip', () {
      final t = Task.fromSyncJson(
        _pcEntry('a', description: 'D', createdAt: '2026-10-01T07:00:00.000Z'),
      );
      final back = Task.fromMap(t.toMap());
      expect(back.details, 'D');
      expect(back.detailsKnown, true);
      expect(back.createdAt, DateTime.utc(2026, 10, 1, 7));
      expect(back.createdKnown, true);
    });

    test('editing a task keeps when it was created', () {
      final t = Task.create(title: 'A');
      expect(t.copyWith(title: 'B', done: true).createdAt, t.createdAt);
    });
  });

  group('merging DeskPlan\'s version with ours', () {
    final local = Task(
      id: 't',
      title: 'mine',
      updatedAt: DateTime.utc(2026, 10, 1),
      details: 'local notes',
      createdAt: DateTime.utc(2026, 9, 1),
    );

    test('DeskPlan\'s description and creation time win when sent', () {
      final pc = Task.fromSyncJson(
        _pcEntry(
          't',
          description: 'PC notes',
          createdAt: '2026-08-01T00:00:00.000Z',
        ),
      );
      final merged = pc.withMissingFieldsFrom(local);
      expect(merged.details, 'PC notes');
      expect(merged.createdAt, DateTime.utc(2026, 8, 1));
    });

    test('what an older DeskPlan leaves out is kept from the phone', () {
      final pc = Task.fromSyncJson(_pcEntry('t', title: 'PC title'));
      final merged = pc.withMissingFieldsFrom(local);
      expect(merged.title, 'PC title');
      expect(merged.details, 'local notes');
      expect(merged.createdAt, DateTime.utc(2026, 9, 1));
    });
  });

  group('database version 5', () {
    test('old tasks keep their data and wait to hear DeskPlan\'s', () async {
      final dir = await Directory.systemTemp.createTemp('deskplan_v4');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/v4.db';
      final old = await openDatabase(
        path,
        version: 4,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, '
            'start TEXT, end TEXT, done INTEGER NOT NULL DEFAULT 0, '
            'updatedAt TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'task\', '
            'parentId TEXT, placeKnown INTEGER NOT NULL DEFAULT 1)',
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
        'updatedAt': '2026-10-20T09:00:00.000Z',
      });
      await old.close();

      final database = AppDatabase(path: path);
      addTearDown(database.close);
      final task = (await TaskStorage(database).get('a'))!;

      expect(task.title, 'kept');
      expect(task.details, '');
      expect(task.detailsKnown, false); // not sent until DeskPlan's is seen
      expect(task.createdKnown, false);
      expect(task.createdAt, DateTime.utc(2026, 10, 20, 9));
    });
  });

  group('what DeskPlan sends reaches the phone', () {
    late AppDatabase database;
    late TaskStorage tasks;
    late SqliteActionQueue queue;

    setUp(() {
      database = AppDatabase(path: inMemoryDatabasePath);
      tasks = TaskStorage(database);
      queue = SqliteActionQueue(database);
    });

    tearDown(() => database.close());

    Task local() => Task(
      id: 't',
      title: 'old title',
      updatedAt: DateTime.utc(2026, 10, 1),
      details: 'local notes',
      createdAt: DateTime.utc(2026, 9, 1),
    );

    test('a pull brings DeskPlan\'s description and creation time', () async {
      await tasks.save(local());
      await PullApplier(tasks, queue).apply(
        _reply([
          _pcEntry(
            't',
            title: 'new title',
            description: 'PC notes',
            createdAt: '2026-08-01T00:00:00.000Z',
          ),
        ]),
      );
      final now = (await tasks.get('t'))!;
      expect(now.details, 'PC notes');
      expect(now.createdAt, DateTime.utc(2026, 8, 1));
    });

    test('a pull from an older DeskPlan does not wipe the phone\'s', () async {
      await tasks.save(local());
      await PullApplier(
        tasks,
        queue,
      ).apply(_reply([_pcEntry('t', title: 'new title')]));
      final now = (await tasks.get('t'))!;
      expect(now.title, 'new title');
      expect(now.details, 'local notes');
      expect(now.createdAt, DateTime.utc(2026, 9, 1));
    });

    test(
      'once DeskPlan confirms the details, they are not sent again',
      () async {
        final app = QueuedTaskRepository(database, tasks, queue);
        await app.save(local().copyWith(details: 'new notes'));
        expect((await tasks.get('t'))!.detailsEdited, true);

        await QueueProcessor(
          queue: queue,
          repository: tasks,
          uploader: FakeUploader(),
        ).run();

        final now = (await tasks.get('t'))!;
        expect(now.details, 'new notes');
        expect(now.detailsEdited, false);
        expect(now.toSyncJson().containsKey('description'), false);
      },
    );

    test('a kept-newer answer to a push brings them too', () async {
      final app = QueuedTaskRepository(database, tasks, queue);
      await app.save(local());
      final uploader = FakeUploader()
        ..next = (_) => Confirmed(
          pcVersion: Task.fromSyncJson(
            _pcEntry('t', title: 'PC wins', description: 'PC notes'),
          ),
        );

      await QueueProcessor(
        queue: queue,
        repository: tasks,
        uploader: uploader,
      ).run();

      final now = (await tasks.get('t'))!;
      expect(now.title, 'PC wins');
      expect(now.details, 'PC notes');
    });
  });
}
