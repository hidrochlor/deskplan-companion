import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/features/connection/deskplan_client.dart';
import 'package:deskplan_companion/features/connection/pc_info.dart';
import 'package:deskplan_companion/features/connection/unreachable_cause.dart';
import 'package:deskplan_companion/features/discovery/hint_discovery.dart';
import 'package:deskplan_companion/features/files/file_queuer.dart';
import 'package:deskplan_companion/features/files/https_file_uploader.dart';
import 'package:deskplan_companion/features/files/queued_upload.dart';
import 'package:deskplan_companion/features/files/sqlite_upload_queue.dart';
import 'package:deskplan_companion/features/files/upload_processor.dart';
import 'package:deskplan_companion/features/files/upload_status.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:deskplan_companion/features/queue/sync_report.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_deskplan_server.dart';
import 'fakes/fake_file_parts.dart';
import 'fakes/in_memory_pairing_store.dart';

final _token = base64.encode(List.filled(32, 7));

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('database version 3', () {
    test(
      'upgrading from version 2 adds the uploads table and keeps data',
      () async {
        final dir = await Directory.systemTemp.createTemp('deskplan_db');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/old.db';

        // A version 2 database, as the previous app version left it.
        final old = await openDatabase(
          path,
          version: 2,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE tasks (id TEXT PRIMARY KEY, '
              'title TEXT NOT NULL, start TEXT, end TEXT, '
              'done INTEGER NOT NULL DEFAULT 0, updatedAt TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE sync_queue (seq INTEGER PRIMARY KEY '
              'AUTOINCREMENT, taskId TEXT NOT NULL UNIQUE, type TEXT NOT NULL, '
              'attempts INTEGER NOT NULL DEFAULT 0, '
              'nextAttemptAt INTEGER NOT NULL, lastError TEXT)',
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
        final db = await database.open();

        expect(await db.query('tasks'), hasLength(1));
        expect(await SqliteUploadQueue(database).all(), isEmpty);
      },
    );
  });

  group('upload queue and processor', () {
    late AppDatabase database;
    late SqliteUploadQueue queue;
    late FakeFileUploader uploader;
    late FakeLocalFileStore store;
    late UploadProcessor processor;
    late FileQueuer queuer;
    var clock = DateTime.utc(2026, 11, 1, 12);

    setUp(() {
      clock = DateTime.utc(2026, 11, 1, 12);
      database = AppDatabase(path: inMemoryDatabasePath);
      queue = SqliteUploadQueue(database);
      uploader = FakeFileUploader();
      store = FakeLocalFileStore();
      processor = UploadProcessor(
        queue: queue,
        uploader: uploader,
        files: store,
        now: () => clock,
      );
      queuer = FileQueuer(queue, store, now: () => clock);
    });

    tearDown(() => database.close());

    Future<QueuedUpload> add(String name) async {
      final file = File('${Directory.systemTemp.path}/deskplan_$name');
      await file.writeAsString('hello');
      addTearDown(() => file.delete());
      return queuer.addFile(
        sourcePath: file.path,
        displayName: name,
        destId: 'received-files',
      );
    }

    test(
      'queuing gives each file its own uploadId and a waiting row',
      () async {
        final a = await add('a.pdf');
        final b = await add('b.pdf');
        expect(a.uploadId, isNot(b.uploadId));
        expect(await queue.waitingCount(), 2);
        expect((await queue.find(a.uploadId))!.sizeBytes, 5);
      },
    );

    test('a confirmed file is marked sent and its copy deleted', () async {
      final a = await add('a.pdf');
      final report = SyncReport();
      await processor.run(report);

      expect(report.filesSent, 1);
      expect((await queue.find(a.uploadId))!.status, UploadStatus.sent);
      expect(store.deleted, [a.localPath]);
      expect(await queue.waitingCount(), 0);
    });

    test('a refused file fails with the reason and keeps its copy', () async {
      final a = await add('a.exe');
      uploader.next = (_) => const Rejected('not accepted');
      final report = SyncReport();
      await processor.run(report);

      final row = (await queue.find(a.uploadId))!;
      expect(row.status, UploadStatus.failed);
      expect(row.lastError, 'not accepted');
      expect(report.rejections.single, contains('a.exe'));
      expect(store.deleted, isEmpty);
    });

    test('retry-later backs off, then is due again', () async {
      final a = await add('a.pdf');
      uploader.next = (_) => const RetryLater('busy');
      await processor.run(SyncReport());

      expect(await queue.due(clock), isEmpty);
      final later = await queue.due(clock.add(const Duration(minutes: 1)));
      expect(later.single.attempts, 1);
      expect(later.single.lastError, 'busy');
      expect(later.single.uploadId, a.uploadId);
    });

    test('a retry that is capped fails after its last try', () async {
      final a = await add('a.pdf');
      uploader.next = (_) => const RetryLater('damaged', maxAttempts: 2);
      await processor.run(SyncReport());
      expect((await queue.find(a.uploadId))!.status, UploadStatus.waiting);

      clock = clock.add(const Duration(hours: 2));
      await processor.run(SyncReport());
      expect((await queue.find(a.uploadId))!.status, UploadStatus.failed);
    });

    test('unreachable stops the run and leaves later files alone', () async {
      await add('a.pdf');
      await add('b.pdf');
      uploader.next = (_) =>
          const Unreachable('off', cause: UnreachableCause.cannotReach);
      final report = SyncReport();
      await processor.run(report);

      expect(uploader.sent, hasLength(1));
      expect(report.unreachableCause, UnreachableCause.cannotReach);
      expect(await queue.waitingCount(), 2);
    });

    test('a file queued before the PC was known is failed locally if its type '
        'is refused, and the others still go', () async {
      final exe = await add('setup.exe');
      final cbz = await add('Chapter 4.cbz');
      final pdf = await add('notes.pdf');
      const pc = PcInfo(
        name: 'PC',
        version: '',
        destinations: [],
        allowedExtensions: {'pdf', 'png'},
      );
      final report = SyncReport();
      await processor.run(report, pc: pc);

      expect((await queue.find(exe.uploadId))!.status, UploadStatus.failed);
      expect((await queue.find(cbz.uploadId))!.status, UploadStatus.failed);
      expect((await queue.find(pdf.uploadId))!.status, UploadStatus.sent);
      expect(uploader.sent, [pdf.uploadId]); // the refused ones never left
      expect(report.rejections, hasLength(2));
      expect(report.unreachableReason, isNull);
    });

    test('retry puts a failed file back, delete forgets it', () async {
      final a = await add('a.pdf');
      await queue.markFailed(a.uploadId, 'nope');
      await queue.retry(a.uploadId, clock);
      expect((await queue.find(a.uploadId))!.status, UploadStatus.waiting);

      await queue.remove(a.uploadId);
      expect(await queue.find(a.uploadId), isNull);
    });

    test('clearing history removes sent files and keeps the rest', () async {
      final sent = await add('done.pdf');
      final failed = await add('bad.exe');
      final waiting = await add('later.pdf');
      await queue.markSent(sent.uploadId, clock);
      await queue.markFailed(failed.uploadId, 'refused');
      await queue.clearSent();

      expect(await queue.find(sent.uploadId), isNull);
      expect(await queue.find(failed.uploadId), isNotNull);
      expect(await queue.find(waiting.uploadId), isNotNull);
    });

    test('only the newest sent files are kept as history', () async {
      for (var i = 0; i < SqliteUploadQueue.keepSent + 3; i++) {
        final u = await add('f$i.pdf');
        clock = clock.add(const Duration(seconds: 1));
        await queue.markSent(u.uploadId, clock);
      }
      expect((await queue.all()).length, SqliteUploadQueue.keepSent);
    });
  });

  group('HttpsFileUploader', () {
    late FakeDeskPlanServer server;
    late HttpsFileUploader uploader;
    late File file;
    late QueuedUpload upload;
    const content = 'hello deskplan';
    final hash = sha256.convert(utf8.encode(content)).toString();

    setUp(() async {
      server = await FakeDeskPlanServer.start();
      final store = InMemoryPairingStore(
        PairingData(
          name: 'Test PC',
          port: server.port,
          token: _token,
          fingerprint: FakeDeskPlanServer.fingerprintOf('test'),
          hint: '127.0.0.1',
        ),
      );
      uploader = HttpsFileUploader(DeskPlanClient(store, HintDiscovery()));
      file = File('${Directory.systemTemp.path}/deskplan_upload.txt');
      await file.writeAsString(content);
      upload = QueuedUpload(
        uploadId: 'u-1',
        localPath: file.path,
        displayName: 'Notes é.txt',
        destId: 'folder:7c1e',
        sizeBytes: content.length,
        nextAttemptAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
      );
    });

    tearDown(() async {
      await server.stop();
      if (await file.exists()) await file.delete();
    });

    test('PUTs the bytes with every required header', () async {
      server.status = 201;
      server.reply = {'received': true, 'sha256': hash, 'storedAs': 'x.txt'};

      final result = await uploader.upload(upload);

      expect(result, isA<Confirmed>());
      final seen = server.requests.single;
      expect(seen.method, 'PUT');
      expect(seen.path, '/v1/received-files/u-1');
      expect(seen.authorization, 'Bearer $_token');
      expect(seen.body, content);
      expect(seen.headers['content-length'], '${content.length}');
      expect(Uri.decodeComponent(seen.headers['x-file-name']!), 'Notes é.txt');
      expect(seen.headers['x-file-sha256'], hash);
      expect(seen.headers['x-dest-id'], 'folder:7c1e');
    });

    test('a reply with a different sha256 is not trusted', () async {
      server.status = 201;
      server.reply = {'received': true, 'sha256': 'f' * 64};
      final result = await uploader.upload(upload);
      expect(result, isA<RetryLater>());
      expect((result as RetryLater).maxAttempts, isNotNull);
    });

    test('each error code is handled as the protocol says', () async {
      Future<UploadResult> answer(int status, Object? body) {
        server.status = status;
        server.reply = body;
        return uploader.upload(upload);
      }

      expect(await answer(422, {'error': 'unsupported-type'}), isA<Rejected>());
      expect(
        await answer(422, {'error': 'unknown-destination'}),
        isA<Rejected>(),
      );
      expect(await answer(413, {'error': 'too-large'}), isA<Rejected>());
      expect(
        await answer(422, {'error': 'checksum-mismatch'}),
        isA<RetryLater>(),
      );
      expect(await answer(503, {'error': 'busy'}), isA<RetryLater>());
      expect(await answer(500, {'error': 'server-error'}), isA<RetryLater>());

      final off = await answer(403, {'error': 'receiving-off'});
      expect((off as Unreachable).cause, UnreachableCause.receivingOff);
      final gone = await answer(401, {'error': 'bad-token'});
      expect((gone as Unreachable).cause, UnreachableCause.unpaired);
    });

    test('a missing stored copy is refused, nothing is sent', () async {
      await file.delete();
      expect(await uploader.upload(upload), isA<Rejected>());
      expect(server.requests, isEmpty);
    });
  });
}
