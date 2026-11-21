import 'dart:convert';

import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_storage.dart';
import 'package:deskplan_companion/features/connection/deskplan_client.dart';
import 'package:deskplan_companion/features/connection/unreachable_cause.dart';
import 'package:deskplan_companion/features/discovery/hint_discovery.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:deskplan_companion/features/pull/pull_applier.dart';
import 'package:deskplan_companion/features/pull/pull_cursor_store.dart';
import 'package:deskplan_companion/features/pull/pull_reply.dart';
import 'package:deskplan_companion/features/pull/pull_result.dart';
import 'package:deskplan_companion/features/pull/pull_service.dart';
import 'package:deskplan_companion/features/pull/server_change_puller.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/features/queue/sync_action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_deskplan_server.dart';
import 'fakes/in_memory_pairing_store.dart';

final _token = base64.encode(List.filled(32, 7));

class _MemoryCursor implements PullCursorStore {
  String? value;
  String? savedKinds;
  Set<String>? savedFields;
  _MemoryCursor();
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
  Future<void> clear() async {
    value = null;
    savedKinds = null;
    savedFields = null;
  }
}

Map<String, Object?> _taskJson(
  String id, {
  String title = 'Read chapter 3',
  bool done = false,
  String updatedAt = '2026-10-30T08:15:00.000Z',
}) => {
  'id': id,
  'title': title,
  'start': null,
  'end': '2026-11-01T09:00:00.000Z',
  'done': done,
  'updatedAt': updatedAt,
};

Map<String, Object?> _body(
  List<Object?> items, {
  String serverTime = '2026-11-02T10:00:00.000Z',
  bool fullResync = false,
}) => {'items': items, 'serverTime': serverTime, 'fullResync': fullResync};

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('PullReply', () {
    test('reads tasks, deletions, serverTime and fullResync', () {
      final reply = PullReply.fromJson(
        _body([
          _taskJson('a'),
          {'id': 'b', 'deleted': true},
        ], fullResync: true),
      );
      expect(reply.items, hasLength(2));
      expect(reply.serverTime, '2026-11-02T10:00:00.000Z');
      expect(reply.fullResync, true);
    });

    test('anything unreadable refuses the whole answer', () {
      for (final bad in <Object?>[
        'nope',
        {'items': [], 'fullResync': false}, // no serverTime
        {'items': [], 'serverTime': 'yesterday'},
        {'items': 'x', 'serverTime': '2026-11-02T10:00:00Z'},
        _body([42]),
        _body([
          {'title': 'no id'},
        ]),
        _body([_taskJson('a')..['done'] = 'yes']),
      ]) {
        expect(
          () => PullReply.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  group('PullService', () {
    late FakeDeskPlanServer server;
    late PullService service;

    setUp(() async {
      server = await FakeDeskPlanServer.start();
      final store = InMemoryPairingStore(
        PairingData(
          name: 'PC',
          port: server.port,
          token: _token,
          fingerprint: FakeDeskPlanServer.fingerprintOf('test'),
          hint: '127.0.0.1',
        ),
      );
      service = PullService(DeskPlanClient(store, HintDiscovery()));
    });

    tearDown(() => server.stop());

    test(
      'asks GET /v1/items with since, exactly as DeskPlan gave it',
      () async {
        server.reply = _body([_taskJson('a')]);
        final result = await service.pull(since: '2026-11-02T10:00:00.000Z');

        expect(result, isA<PullOk>());
        final seen = server.requests.single;
        expect(seen.method, 'GET');
        expect(seen.path, '/v1/items');
        expect(seen.authorization, 'Bearer $_token');
      },
    );

    test('the first pull leaves since out', () async {
      server.reply = _body([]);
      await service.pull();
      expect(server.requests.single.path, '/v1/items');
    });

    test('404 means the PC is too old, quietly', () async {
      server.status = 404;
      server.reply = {'error': 'not-found'};
      expect(await service.pull(), isA<PullUnsupported>());
    });

    test('blocking answers carry their cause', () async {
      server.status = 403;
      server.reply = {'error': 'awaiting-approval'};
      final result = await service.pull() as PullBlocked;
      expect(result.problem.cause, UnreachableCause.awaitingApproval);
    });

    test('422 forgets the place, 503 and odd answers just retry', () async {
      server.status = 422;
      server.reply = {'error': 'invalid-request'};
      expect((await service.pull() as PullFailed).resetPlace, true);

      server.status = 503;
      server.reply = {'error': 'busy'};
      expect((await service.pull() as PullFailed).resetPlace, false);

      server.status = 200;
      server.reply = {'unexpected': true};
      expect(await service.pull(), isA<PullFailed>());
    });
  });

  group('PullApplier', () {
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

    Task local(String id, {String title = 'mine', String? updatedAt}) => Task(
      id: id,
      title: title,
      updatedAt: DateTime.parse(updatedAt ?? '2026-10-30T08:15:00.000Z'),
    );

    PullReply reply(List<Object?> items, {bool full = false}) =>
        PullReply.fromJson(_body(items, fullResync: full));

    test('adds a task the phone does not have', () async {
      final changed = await applier.apply(reply([_taskJson('a')]));
      expect(changed, 1);
      expect((await tasks.get('a'))!.title, 'Read chapter 3');
    });

    test('DeskPlan wins when newer, and when equal', () async {
      await tasks.save(
        local('a', title: 'old', updatedAt: '2026-10-29T00:00:00Z'),
      );
      await tasks.save(local('b', title: 'tie'));

      await applier.apply(
        reply([
          _taskJson('a', title: 'new from PC'),
          _taskJson('b', title: 'PC at same time'),
        ]),
      );
      expect((await tasks.get('a'))!.title, 'new from PC');
      expect((await tasks.get('b'))!.title, 'PC at same time');
    });

    test('the phone wins when its copy is newer', () async {
      await tasks.save(
        local('a', title: 'newer here', updatedAt: '2026-11-05T00:00:00Z'),
      );
      final changed = await applier.apply(
        reply([_taskJson('a', title: 'older')]),
      );
      expect(changed, 0);
      expect((await tasks.get('a'))!.title, 'newer here');
    });

    test('an unsent phone change is never overwritten', () async {
      await tasks.save(
        local('a', title: 'edited offline', updatedAt: '2026-10-01T00:00:00Z'),
      );
      await queue.enqueue('a', ActionType.save);

      await applier.apply(reply([_taskJson('a', title: 'PC says otherwise')]));
      expect((await tasks.get('a'))!.title, 'edited offline');
    });

    test(
      'a full resync teaches an unchanged item its source (imported assignments lock)',
      () async {
        // Saved before the pull carried `source`: same updatedAt as DeskPlan's.
        await tasks.save(local('a', title: 'Read chapter 3'));
        expect((await tasks.get('a'))!.isImported, false);

        final changed = await applier.apply(
          reply([
            {
              ..._taskJson('a'),
              'source': {'label': 'Moodle'},
            },
          ], full: true),
        );
        expect(changed, 1);
        final a = (await tasks.get('a'))!;
        expect(a.isImported, true);
        expect(a.sourceLabel, 'Moodle');
      },
    );

    test('a repeated item changes nothing and is not counted', () async {
      await applier.apply(reply([_taskJson('a')]));
      final again = await applier.apply(reply([_taskJson('a')]));
      expect(again, 0);
    });

    test(
      'a deletion removes the task, unless the phone has unsent work',
      () async {
        await tasks.save(local('gone'));
        await tasks.save(local('busy'));
        await queue.enqueue('busy', ActionType.save);

        final changed = await applier.apply(
          reply([
            {'id': 'gone', 'deleted': true},
            {'id': 'busy', 'deleted': true},
            {'id': 'never-had-it', 'deleted': true},
          ]),
        );
        expect(changed, 1);
        expect(await tasks.get('gone'), isNull);
        expect(await tasks.get('busy'), isNotNull);
      },
    );

    test(
      'a full resync removes tasks that are not listed, keeping unsent ones',
      () async {
        await tasks.save(local('keep'));
        await tasks.save(local('stale'));
        await tasks.save(local('unsent'));
        await queue.enqueue('unsent', ActionType.save);

        await applier.apply(
          reply([_taskJson('keep', title: 'mine')], full: true),
        );
        expect(await tasks.get('stale'), isNull);
        expect(await tasks.get('unsent'), isNotNull);
        expect(await tasks.get('keep'), isNotNull);
      },
    );

    test('pulled changes never create queued actions', () async {
      await applier.apply(
        reply([
          _taskJson('a'),
          {'id': 'b', 'deleted': true},
        ]),
      );
      expect(await queue.pendingCount(), 0);
    });
  });

  group('ServerChangePuller', () {
    late FakeDeskPlanServer server;
    late AppDatabase database;
    late TaskStorage tasks;
    late _MemoryCursor cursor;
    late ServerChangePuller puller;

    setUp(() async {
      server = await FakeDeskPlanServer.start();
      database = AppDatabase(path: inMemoryDatabasePath);
      tasks = TaskStorage(database);
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
        PullApplier(tasks, SqliteActionQueue(database)),
        cursor,
      );
    });

    tearDown(() async {
      await server.stop();
      await database.close();
    });

    test(
      'applies the answer, then saves serverTime as the new place',
      () async {
        server.reply = _body([
          _taskJson('a'),
        ], serverTime: '2026-11-02T10:00:00.000Z');
        final outcome = await puller.pull();

        expect(outcome.changed, 1);
        expect(cursor.value, '2026-11-02T10:00:00.000Z');
        expect(await tasks.get('a'), isNotNull);
      },
    );

    test('an unreadable answer leaves the place where it was', () async {
      cursor.value = '2026-11-01T00:00:00.000Z';
      server.reply = {
        'items': 'broken',
        'serverTime': '2026-11-02T10:00:00.000Z',
      };
      final outcome = await puller.pull();

      expect(outcome.failure, isNotNull);
      expect(cursor.value, '2026-11-01T00:00:00.000Z');
    });

    test(
      'a refused place is forgotten so the next pull asks for everything',
      () async {
        cursor.value = 'garbage';
        server.status = 422;
        server.reply = {'error': 'invalid-request'};
        await puller.pull();
        expect(cursor.value, isNull);
      },
    );

    group('fields', () {
      const before = [
        'course',
        'createdAt',
        'description',
        'done',
        'end',
        'id',
        'kind',
        'parentId',
        'start',
        'title',
        'updatedAt',
      ];
      Map<String, Object?> answer(List<String> fields) => {
        ..._body([_taskJson('a')]),
        'fields': fields,
      };

      test(
        'a field the phone reads that was not there last time: everything once',
        () async {
          cursor
            ..value = '2026-11-01T00:00:00.000Z'
            ..savedKinds = 'task,assignment'
            ..savedFields = before.toSet();
          server.reply = answer([...before, 'source']);
          await puller.pull();

          expect(server.requests.map((r) => r.query['since']), [
            '2026-11-01T00:00:00.000Z',
            null, // asked again for everything
          ]);
          expect(cursor.savedFields, contains('source'));
        },
      );

      test(
        'the same fields, or one the phone does not read: no extra pull',
        () async {
          cursor
            ..value = '2026-11-01T00:00:00.000Z'
            ..savedKinds = 'task,assignment'
            ..savedFields = {...before, 'source'};
          server.reply = answer([...before, 'source', 'priority']);
          await puller.pull();
          expect(server.requests, hasLength(1));
          expect(cursor.savedFields, isNot(contains('priority')));
        },
      );

      test('an older PC lists no fields: no extra pull', () async {
        cursor
          ..value = '2026-11-01T00:00:00.000Z'
          ..savedKinds = 'task,assignment';
        server.reply = _body([_taskJson('a')]);
        await puller.pull();
        expect(server.requests, hasLength(1));
        expect(cursor.savedFields, isNull);
      });
    });

    test('a PC that is too old is reported, and nothing is saved', () async {
      server.status = 404;
      server.reply = {'error': 'not-found'};
      final outcome = await puller.pull();
      expect(outcome.unsupported, true);
      expect(cursor.value, isNull);
    });
  });
}
