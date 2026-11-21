import 'dart:convert';
import 'dart:io';

import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/core/task_storage.dart';
import 'package:deskplan_companion/core/task_tree.dart';
import 'package:deskplan_companion/features/connection/deskplan_client.dart';
import 'package:deskplan_companion/features/connection/pc_info.dart';
import 'package:deskplan_companion/features/connection/ping_result.dart';
import 'package:deskplan_companion/features/discovery/hint_discovery.dart';
import 'package:deskplan_companion/features/files/sqlite_upload_queue.dart';
import 'package:deskplan_companion/features/files/upload_processor.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:deskplan_companion/features/pull/pull_applier.dart';
import 'package:deskplan_companion/features/pull/pull_cursor_store.dart';
import 'package:deskplan_companion/features/pull/pull_reply.dart';
import 'package:deskplan_companion/features/pull/pull_service.dart';
import 'package:deskplan_companion/features/pull/server_change_puller.dart';
import 'package:deskplan_companion/features/queue/queue_processor.dart';
import 'package:deskplan_companion/features/queue/queued_task_repository.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/features/queue/sync_action.dart';
import 'package:deskplan_companion/features/queue/sync_service.dart';
import 'package:deskplan_companion/features/upload/https_task_uploader.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_change_puller.dart';
import 'fakes/fake_connection_checker.dart';
import 'fakes/fake_deskplan_server.dart';
import 'fakes/fake_file_parts.dart';
import 'fakes/fake_uploader.dart';
import 'fakes/in_memory_pairing_store.dart';

final _token = base64.encode(List.filled(32, 7));

const _doc = {
  'type': 'doc',
  'content': [
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': 'Week 3'},
      ],
    },
  ],
};

/// A note as DeskPlan sends it in a pull or a PUT reply.
Map<String, Object?> _noteJson(
  String id, {
  Object? doc = _doc,
  String updatedAt = '2026-10-30T08:15:00.000Z',
  String? parentId,
}) => {
  'id': id,
  'title': 'Note $id',
  'start': null,
  'end': null,
  'done': false,
  'updatedAt': updatedAt,
  'kind': 'note',
  'parentId': parentId,
  'createdAt': '2026-10-28T19:40:00.000Z',
  'description': 'Week 3',
  'doc': doc,
};

Map<String, Object?> _taskJson(String id) => {
  'id': id,
  'title': id,
  'start': '2026-11-01T08:00:00.000Z',
  'end': '2026-11-01T09:00:00.000Z',
  'done': false,
  'updatedAt': '2026-10-30T08:15:00.000Z',
  'kind': 'task',
  'parentId': null,
};

PullReply _reply(List<Object?> items, {bool full = false}) =>
    PullReply.fromJson({
      'items': items,
      'serverTime': '2026-11-02T10:00:00.000Z',
      'fullResync': full,
    });

class _MemoryCursor implements PullCursorStore {
  String? value;
  String? savedKinds;
  Set<String>? savedFields;
  @override
  Future<String?> load() async => value;
  @override
  Future<String?> kinds() async => savedKinds;
  @override
  Future<Set<String>?> fields() async => savedFields;
  @override
  Future<void> save(
    String serverTime, {
    required String kinds,
    Set<String>? fields,
  }) async {
    value = serverTime;
    savedKinds = kinds;
    savedFields = fields;
  }

  @override
  Future<void> clear() async => value = savedKinds = null;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('a note as an item', () {
    test('sends its doc, no times, no tick and never a description', () {
      final note = Task.createNote(
        title: 'Week 3',
        parentId: 'f1',
        doc: _doc,
      ).copyWith(details: 'stale copy');
      final json = note.toSyncJson();
      expect(json['kind'], 'note');
      expect(json['parentId'], 'f1');
      expect(json['doc'], _doc);
      expect(json['start'], isNull);
      expect(json['end'], isNull);
      expect(json['done'], false);
      expect(json.containsKey('description'), false);
    });

    test('is read from DeskPlan with its doc and plain text, ignoring a '
        'due time the PC keeps', () {
      final note = Task.fromSyncJson(
        _noteJson('n')..['end'] = '2026-11-01T09:00:00.000Z',
      );
      expect(note.isNote, true);
      expect(note.end, isNull);
      expect(note.details, 'Week 3');
      expect(note.doc, _doc);
    });

    test('a doc that is not a note is refused', () {
      for (final bad in <Object?>[
        'text',
        {'type': 'paragraph'},
        [1, 2],
      ]) {
        expect(
          () => Task.fromSyncJson(_noteJson('n', doc: bad)),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('keeps its doc through the database', () async {
      final database = AppDatabase(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final storage = TaskStorage(database);
      final note = Task.fromSyncJson(_noteJson('n'));
      await storage.save(note);
      final back = (await storage.get('n'))!;
      expect(back.kind, TaskKind.note);
      expect(back.doc, _doc);
    });

    test('inside an assignment it is not a step, but goes when the '
        'assignment is deleted', () {
      final asg = Task(
        id: 'asg',
        title: 'HW',
        end: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 10, 30),
        kind: TaskKind.assignment,
        parentId: 'f1',
      );
      final step = Task(
        id: 's',
        title: 'step',
        updatedAt: DateTime.utc(2026, 10, 30),
        parentId: 'asg',
      );
      final note = Task.fromSyncJson(_noteJson('n', parentId: 'asg'));
      final tree = TaskTree([asg, step, note]);
      expect(tree.stepsOf('asg').map((t) => t.id), ['s']);
      expect(tree.progressOf('asg').total, 1);
      expect(tree.withDescendantsChildrenFirst(asg).map((t) => t.id).toSet(), {
        's',
        'n',
        'asg',
      });
    });
  });

  group('PcInfo features', () {
    test('notes are synced only when the ping lists them', () {
      final base = {'name': 'PC', 'version': '1'};
      expect(PcInfo.fromJson(base).syncsNotes, false);
      expect(
        PcInfo.fromJson({
          ...base,
          'features': ['notes'],
        }).syncsNotes,
        true,
      );
      final saved = PcInfo.fromJson({
        ...base,
        'features': ['notes'],
      }).toJson();
      expect(PcInfo.fromJson(saved).syncsNotes, true);
    });
  });

  group('pull with notes', () {
    late FakeDeskPlanServer server;
    late AppDatabase database;
    late TaskStorage tasks;
    late SqliteActionQueue queue;
    late _MemoryCursor cursor;
    late ServerChangePuller puller;

    setUp(() async {
      server = await FakeDeskPlanServer.start();
      database = AppDatabase(path: inMemoryDatabasePath);
      tasks = TaskStorage(database);
      queue = SqliteActionQueue(database);
      cursor = _MemoryCursor();
      final store = InMemoryPairingStore(
        PairingData(
          name: 'PC',
          port: server.port,
          token: _token,
          fingerprint: FakeDeskPlanServer.fingerprintOf('test'),
          hint: '127.0.0.1',
        ),
      );
      puller = ServerChangePuller(
        PullService(DeskPlanClient(store, HintDiscovery())),
        PullApplier(tasks, queue),
        cursor,
      );
      server.reply = {
        'items': [_noteJson('n'), _taskJson('t')],
        'serverTime': '2026-11-02T10:00:00.000Z',
        'fullResync': false,
      };
    });

    tearDown(() async {
      await server.stop();
      await database.close();
    });

    test('without notes, kinds is left out, as an older phone asked', () async {
      cursor.value = '2026-11-01T00:00:00.000Z';
      server.reply = {
        'items': [_taskJson('t')],
        'serverTime': '2026-11-02T10:00:00.000Z',
        'fullResync': false,
      };
      await puller.pull();
      final query = server.requests.single.query;
      expect(query.containsKey('kinds'), false);
      expect(query['since'], '2026-11-01T00:00:00.000Z');
    });

    test('the first pull with notes asks for them from the beginning, '
        'then goes on from its place', () async {
      cursor.value = '2026-11-01T00:00:00.000Z'; // a place from before notes

      await puller.pull(notes: true);
      final first = server.requests.single.query;
      expect(first['kinds'], 'task,assignment,note');
      expect(first.containsKey('since'), false);
      expect((await tasks.get('n'))!.doc, _doc);

      await puller.pull(notes: true);
      expect(server.requests.last.query['since'], '2026-11-02T10:00:00.000Z');
    });

    test('a full resync without notes keeps the phone\'s notes', () async {
      await tasks.save(Task.fromSyncJson(_noteJson('mine')));
      await tasks.save(Task.fromSyncJson(_taskJson('stale')));
      await PullApplier(
        tasks,
        queue,
      ).apply(_reply([_taskJson('t')], full: true));
      expect(await tasks.get('mine'), isNotNull);
      expect(await tasks.get('stale'), isNull);
    });

    test('a full resync with notes removes notes that are gone', () async {
      await tasks.save(Task.fromSyncJson(_noteJson('gone')));
      await PullApplier(tasks, queue).apply(
        _reply([_noteJson('n')], full: true),
        kinds: {TaskKind.task, TaskKind.assignment, TaskKind.note},
      );
      expect(await tasks.get('gone'), isNull);
      expect(await tasks.get('n'), isNotNull);
    });

    test('a change to the text alone is applied', () async {
      final applier = PullApplier(tasks, queue);
      await applier.apply(_reply([_noteJson('n')]));
      final changed = await applier.apply(
        _reply([
          _noteJson(
            'n',
            doc: {
              'type': 'doc',
              'content': [
                {'type': 'paragraph'},
              ],
            },
          ),
        ]),
      );
      expect(changed, 1);
    });
  });

  group('sending notes', () {
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

    test('wait while DeskPlan does not sync notes, then go', () async {
      final note = Task.createNote(title: 'N', doc: _doc);
      await app.save(note);

      await processor.run();
      expect(uploader.calls, isEmpty);
      expect(await queue.hasPending(note.id), true);

      await processor.run(syncNotes: true);
      expect(uploader.calls, ['save ${note.id}']);
      expect(await queue.pendingCount(), 0);
    });

    test('only the newest save of a note waits', () async {
      final note = Task.createNote(title: 'N', doc: _doc);
      await app.save(note);
      await app.save(note.copyWith(title: 'N2'));
      await app.save(note.copyWith(title: 'N3'));
      expect(await queue.pendingCount(), 1);
    });

    test('kept-newer with other text keeps the phone\'s as a copy', () async {
      final note = Task.createNote(title: 'Week 3', parentId: 'f1', doc: _doc);
      await app.save(note);
      final pc = Task.fromSyncJson(
        _noteJson(
          note.id,
          parentId: 'f1',
          updatedAt: '2030-01-01T00:00:00.000Z',
          doc: {
            'type': 'doc',
            'content': [
              {'type': 'paragraph'},
            ],
          },
        ),
      );
      uploader.next = (_) => Confirmed(pcVersion: pc);

      await processor.run(syncNotes: true);

      final all = await plain.all();
      expect(all, hasLength(2));
      final original = all.firstWhere((t) => t.id == note.id);
      final copy = all.firstWhere((t) => t.id != note.id);
      expect(original.doc, pc.doc); // the PC's version for the original
      expect(copy.title, 'Week 3 (phone copy)');
      expect(copy.parentId, 'f1');
      expect(copy.doc, _doc);
      expect(await queue.hasPending(copy.id), true);
    });

    test(
      'kept-newer with the same text written differently makes no copy',
      () async {
        final note = Task.createNote(title: 'N', doc: _doc);
        await app.save(note);
        // The same doc, keys in another order.
        final reordered = jsonDecode(
          '{"content":[{"content":[{"text":"Week 3","type":"text"}],'
          '"type":"paragraph"}],"type":"doc"}',
        );
        final pc = Task.fromSyncJson(
          _noteJson(
            note.id,
            doc: reordered,
            updatedAt: '2030-01-01T00:00:00.000Z',
          ),
        );
        uploader.next = (_) => Confirmed(pcVersion: pc);
        await processor.run(syncNotes: true);
        expect(await plain.all(), hasLength(1));
      },
    );

    test('the copy\'s title stays within 500 characters', () async {
      final note = Task.createNote(title: 'x' * 500, doc: _doc);
      await app.save(note);
      final pc = Task.fromSyncJson(
        _noteJson(
          note.id,
          doc: {'type': 'doc', 'content': []},
          updatedAt: '2030-01-01T00:00:00.000Z',
        ),
      );
      uploader.next = (_) => Confirmed(pcVersion: pc);
      await processor.run(syncNotes: true);
      final copy = (await plain.all()).firstWhere((t) => t.id != note.id);
      expect(copy.title.length, 500);
      expect(copy.title, endsWith(' (phone copy)'));
    });

    test('a note over 1 MB is too big, and is not sent', () async {
      final huge = Task.createNote(
        title: 'Big',
        doc: {
          'type': 'doc',
          'content': [
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': 'a' * (1024 * 1024)},
              ],
            },
          ],
        },
      );
      expect(HttpsTaskUploader.tooBig(huge), true);
      expect(HttpsTaskUploader.tooBig(Task.createNote(doc: _doc)), false);
    });

    test('the sync asks for notes only when the ping lists them', () async {
      final puller = FakeChangePuller();
      final checker = FakeConnectionChecker();
      final service = SyncService(
        checker,
        processor,
        UploadProcessor(
          queue: SqliteUploadQueue(database),
          uploader: FakeFileUploader(),
          files: FakeLocalFileStore(),
        ),
        puller,
      );
      addTearDown(service.dispose);
      final note = Task.createNote(doc: _doc);
      await app.save(note);

      await service.syncNow();
      expect(puller.askedForNotes, false);
      expect(uploader.calls, isEmpty);

      checker.result = const PingOk(
        PcInfo(name: 'PC', version: '1', destinations: [], features: {'notes'}),
      );
      await service.syncNow();
      expect(puller.askedForNotes, true);
      expect(uploader.calls, ['save ${note.id}']);
    });
  });

  test('database version 6: tasks from version 5 keep their data', () async {
    final dir = await Directory.systemTemp.createTemp('deskplan_v5');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v5.db';
    final old = await openDatabase(
      path,
      version: 5,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, '
          'start TEXT, end TEXT, done INTEGER NOT NULL DEFAULT 0, '
          'updatedAt TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'task\', '
          'parentId TEXT, placeKnown INTEGER NOT NULL DEFAULT 1, '
          'details TEXT NOT NULL DEFAULT \'\', '
          'detailsKnown INTEGER NOT NULL DEFAULT 1, '
          'detailsEdited INTEGER NOT NULL DEFAULT 0, createdAt TEXT, '
          'createdKnown INTEGER NOT NULL DEFAULT 0)',
        );
      },
    );
    await old.insert('tasks', {
      'id': 'a',
      'title': 'kept',
      'updatedAt': '2026-11-01T09:00:00.000Z',
    });
    await old.close();

    final database = AppDatabase(path: path);
    addTearDown(database.close);
    final storage = TaskStorage(database);
    expect((await storage.get('a'))!.title, 'kept');
    expect((await storage.get('a'))!.doc, isNull);
    await storage.save(Task.fromSyncJson(_noteJson('n')));
    expect((await storage.get('n'))!.doc, _doc);
  });

  test('an unsent note is never overwritten by a pull', () async {
    final database = AppDatabase(path: inMemoryDatabasePath);
    addTearDown(database.close);
    final tasks = TaskStorage(database);
    final queue = SqliteActionQueue(database);
    final mine = Task.fromSyncJson(
      _noteJson('n', updatedAt: '2026-10-01T00:00:00.000Z'),
    ).copyWith(title: 'typed on the phone');
    await tasks.save(mine);
    await queue.enqueue('n', ActionType.save);
    await PullApplier(tasks, queue).apply(
      _reply([_noteJson('n')]),
      kinds: {TaskKind.task, TaskKind.assignment, TaskKind.note},
    );
    expect((await tasks.get('n'))!.title, 'typed on the phone');
  });
}
