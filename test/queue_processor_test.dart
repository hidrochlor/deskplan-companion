import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:deskplan_companion/features/background/background_sync.dart';
import 'package:deskplan_companion/features/connection/unreachable_cause.dart';
import 'package:deskplan_companion/features/files/sqlite_upload_queue.dart';
import 'package:deskplan_companion/features/files/upload_processor.dart';
import 'package:deskplan_companion/features/connection/client_reply.dart';
import 'package:deskplan_companion/features/pull/pull_outcome.dart';
import 'package:deskplan_companion/features/queue/queue_processor.dart';
import 'package:deskplan_companion/features/queue/queued_task_repository.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/features/queue/sync_action.dart';
import 'package:deskplan_companion/features/queue/sync_service.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/core/task_storage.dart';

import 'fakes/fake_change_puller.dart';
import 'fakes/fake_connection_checker.dart';
import 'fakes/fake_file_parts.dart';
import 'fakes/fake_uploader.dart';

/// Counts how often a retry was requested.
class _FakeBackground implements BackgroundSync {
  int requests = 0;
  @override
  Future<void> start() async {}
  @override
  Future<void> requestSoon() async => requests++;
}

/// An upload processor with nothing queued, for tests about tasks.
UploadProcessor _noFiles(AppDatabase database) => UploadProcessor(
  queue: SqliteUploadQueue(database),
  uploader: FakeFileUploader(),
  files: FakeLocalFileStore(),
);

/// A queue whose write fails, to prove the task write is rolled back too.
class _BrokenQueue extends SqliteActionQueue {
  _BrokenQueue(super.database);

  @override
  Future<void> enqueueIn(
    DatabaseExecutor db,
    String taskId,
    ActionType type,
  ) async {
    throw StateError('disk full');
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase database;
  late TaskStorage plain; // storage without queueing
  late SqliteActionQueue queue;
  late QueuedTaskRepository app; // what the screens use
  late FakeUploader uploader;
  late QueueProcessor processor;
  var clock = DateTime.utc(2026, 11, 1, 12);

  setUp(() {
    clock = DateTime.utc(2026, 11, 1, 12);
    database = AppDatabase(path: inMemoryDatabasePath);
    plain = TaskStorage(database);
    queue = SqliteActionQueue(database, now: () => clock);
    app = QueuedTaskRepository(database, plain, queue);
    uploader = FakeUploader();
    processor = QueueProcessor(
      queue: queue,
      repository: plain,
      uploader: uploader,
      now: () => clock,
    );
  });

  tearDown(() => database.close());

  test(
    'saving a task queues it, and a confirmed upload empties the queue',
    () async {
      final t = Task.create(title: 'A');
      await app.save(t);
      expect(await queue.pendingCount(), 1);

      final report = await processor.run();
      expect(uploader.calls, ['save ${t.id}']);
      expect(report.sent, 1);
      expect(await queue.pendingCount(), 0);
    },
  );

  test('if queueing fails, the task change is rolled back too', () async {
    final broken = QueuedTaskRepository(
      database,
      plain,
      _BrokenQueue(database),
    );
    final t = Task.create(title: 'A');

    await expectLater(broken.save(t), throwsStateError);
    expect(await plain.get(t.id), isNull);

    await plain.save(t);
    await expectLater(broken.delete(t.id), throwsStateError);
    expect(await plain.get(t.id), isNotNull);
  });

  test('edits before syncing collapse into one save', () async {
    final t = Task.create(title: 'A');
    await app.save(t);
    await app.save(t.copyWith(title: 'B'));
    await processor.run();
    expect(uploader.calls, ['save ${t.id}']);
  });

  test('a task created then deleted offline sends only the delete', () async {
    final t = Task.create(title: 'A');
    await app.save(t);
    await app.delete(t.id);
    await processor.run();
    expect(uploader.calls, ['delete ${t.id}']);
    expect(await plain.get(t.id), isNull);
  });

  test('unreachable PC stops the run and keeps everything queued', () async {
    await app.save(Task.create(title: 'A'));
    await app.save(Task.create(title: 'B'));
    uploader.next = (_) => const Unreachable('PC is off');

    final report = await processor.run();
    expect(uploader.calls, hasLength(1)); // did not try the second
    expect(report.unreachableReason, 'PC is off');
    expect(await queue.pendingCount(), 2);
  });

  test('RetryLater backs off, then succeeds on a later run', () async {
    final t = Task.create(title: 'A');
    await app.save(t);
    uploader.next = (_) => const RetryLater('busy');
    expect((await processor.run()).retryLater, 1);

    // Too early: nothing is due.
    uploader.calls.clear();
    await processor.run();
    expect(uploader.calls, isEmpty);

    // After the 30 s backoff it is tried again.
    clock = clock.add(const Duration(seconds: 31));
    uploader.next = (_) => const Confirmed();
    expect((await processor.run()).sent, 1);
    expect(await queue.pendingCount(), 0);
  });

  test('Rejected (422) is dropped and reported with the task title', () async {
    await app.save(Task.create(title: 'Buy milk'));
    uploader.next = (_) => const Rejected('it is a folder');
    final report = await processor.run();
    expect(report.rejected, 1);
    expect(report.rejections.single, contains('"Buy milk"'));
    expect(report.rejections.single, contains('it is a folder'));
    expect(await queue.pendingCount(), 0);
  });

  test('a rejected delete is reported too', () async {
    await app.delete('some-id');
    uploader.next = (_) => const Rejected('it is a folder');
    final report = await processor.run();
    expect(report.rejections.single, contains('A deleted task'));
  });

  test(
    'kept-newer: the PC version replaces ours without re-queueing',
    () async {
      final t = Task.create(title: 'phone title');
      await app.save(t);
      final pc = Task(id: t.id, title: 'pc title', updatedAt: DateTime.now());
      uploader.next = (_) => Confirmed(pcVersion: pc);

      await processor.run();
      expect((await plain.get(t.id))!.title, 'pc title');
      expect(await queue.pendingCount(), 0);
    },
  );

  test('kept-newer is ignored if the user edited again meanwhile', () async {
    final t = Task.create(title: 'v1');
    await app.save(t);
    final pc = Task(id: t.id, title: 'pc title', updatedAt: DateTime.now());
    Future<void>? edit;
    uploader.next = (_) {
      // The user edits while the upload is in flight.
      edit = plain.save(t.copyWith(title: 'v2'));
      return Confirmed(pcVersion: pc);
    };
    await processor.run();
    await edit;
    expect((await plain.get(t.id))!.title, 'v2');
  });

  test('a save for a task that no longer exists is dropped silently', () async {
    final t = Task.create(title: 'A');
    await app.save(t);
    await plain.delete(t.id);
    await processor.run();
    expect(uploader.calls, isEmpty);
    expect(await queue.pendingCount(), 0);
  });

  group('SyncService', () {
    test('publishes a report for each run', () async {
      final service = SyncService(
        FakeConnectionChecker(),
        processor,
        _noFiles(database),
        FakeChangePuller(),
      );
      addTearDown(service.dispose);
      await app.save(Task.create(title: 'A'));

      final next = service.reports.first;
      await service.syncNow();
      expect((await next).sent, 1);
    });

    test(
      'a failed ping reports the cause and leaves the queue alone',
      () async {
        final checker = FakeConnectionChecker()
          ..block(UnreachableCause.receivingOff, 'Receiving is off on your PC');
        final service = SyncService(
          checker,
          processor,
          _noFiles(database),
          FakeChangePuller(),
        );
        addTearDown(service.dispose);
        await app.save(Task.create(title: 'A'));

        final next = service.reports.first;
        await service.syncNow();
        final report = await next;

        expect(report.unreachableCause, UnreachableCause.receivingOff);
        expect(report.unreachableReason, 'Receiving is off on your PC');
        expect(uploader.calls, isEmpty);
        expect(await queue.pendingCount(), 1);
      },
    );

    test('asks for a background retry when the PC cannot be reached, '
        'and not when everything was sent', () async {
      final background = _FakeBackground();
      final checker = FakeConnectionChecker();
      final service = SyncService(
        checker,
        processor,
        _noFiles(database),
        FakeChangePuller(),
        background: background,
      );
      addTearDown(service.dispose);
      await app.save(Task.create(title: 'A'));

      await service.syncNow(); // everything goes through
      expect(background.requests, 0);

      checker.block(UnreachableCause.cannotReach, 'Cannot reach DeskPlan');
      await service.syncNow();
      expect(background.requests, 1);
    });

    test('pulls after sending, and reports what changed', () async {
      final puller = FakeChangePuller()
        ..outcome = const PullOutcome(changed: 3);
      final service = SyncService(
        FakeConnectionChecker(),
        processor,
        _noFiles(database),
        puller,
      );
      addTearDown(service.dispose);
      await app.save(Task.create(title: 'A'));

      final next = service.reports.first;
      await service.syncNow();
      final report = await next;

      expect(uploader.calls, hasLength(1)); // pushed first
      expect(puller.pulls, 1);
      expect(report.pulled, 3);
    });

    test('a PC that is too old is reported, not treated as an error', () async {
      final puller = FakeChangePuller()
        ..outcome = const PullOutcome(unsupported: true);
      final service = SyncService(
        FakeConnectionChecker(),
        processor,
        _noFiles(database),
        puller,
      );
      addTearDown(service.dispose);

      final next = service.reports.first;
      await service.syncNow();
      final report = await next;

      expect(report.pullUnsupported, true);
      expect(report.unreachableReason, isNull);
    });

    test('no pull when the PC cannot be reached', () async {
      final puller = FakeChangePuller();
      final checker = FakeConnectionChecker()
        ..block(UnreachableCause.cannotReach, 'off');
      final service = SyncService(
        checker,
        processor,
        _noFiles(database),
        puller,
      );
      addTearDown(service.dispose);
      await service.syncNow();
      expect(puller.pulls, 0);
    });

    test('being blocked during the pull shows the reason', () async {
      final puller = FakeChangePuller()
        ..outcome = const PullOutcome(
          blocked: NoReply(UnreachableCause.unpaired, 'Pair again'),
        );
      final service = SyncService(
        FakeConnectionChecker(),
        processor,
        _noFiles(database),
        puller,
      );
      addTearDown(service.dispose);

      final next = service.reports.first;
      await service.syncNow();
      final report = await next;
      expect(report.unreachableCause, UnreachableCause.unpaired);
    });

    test(
      'a change made during a run is picked up by the same syncNow',
      () async {
        final service = SyncService(
          FakeConnectionChecker(),
          processor,
          _noFiles(database),
          FakeChangePuller(),
        );
        addTearDown(service.dispose);
        final first = Task.create(title: 'first');
        final second = Task.create(title: 'second');
        await app.save(first);

        uploader.next = (call) {
          if (call == 'save ${first.id}') {
            // While 'first' uploads, the user saves another task and a new
            // sync is requested. It must not be lost.
            app.save(second).then((_) => service.syncNow());
          }
          return const Confirmed();
        };
        await service.syncNow();
        // Give the nested save + request time to land, then check.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await service.syncNow();

        expect(uploader.calls, contains('save ${second.id}'));
        expect(await queue.pendingCount(), 0);
      },
    );
  });
}
