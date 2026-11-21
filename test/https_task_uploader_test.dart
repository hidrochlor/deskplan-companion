import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:deskplan_companion/features/connection/deskplan_client.dart';
import 'package:deskplan_companion/features/connection/unreachable_cause.dart';
import 'package:deskplan_companion/features/discovery/hint_discovery.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:deskplan_companion/features/upload/device_name_provider.dart';
import 'package:deskplan_companion/features/upload/https_task_uploader.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';
import 'package:deskplan_companion/core/task.dart';

import 'fakes/fake_deskplan_server.dart';
import 'fakes/in_memory_pairing_store.dart';

final _token = base64.encode(List.filled(32, 7));

class _FixedName implements DeviceNameProvider {
  final String value;
  _FixedName(this.value);
  @override
  Future<String?> name() async => value;
}

PairingData _pairing(int port, {String certName = 'test', String? hint}) =>
    PairingData(
      name: 'Test PC',
      port: port,
      token: _token,
      fingerprint: FakeDeskPlanServer.fingerprintOf(certName),
      hint: hint ?? '127.0.0.1',
    );

HttpsTaskUploader _uploaderFor(
  InMemoryPairingStore store, {
  DeviceNameProvider? deviceName,
}) => HttpsTaskUploader(
  DeskPlanClient(store, HintDiscovery(), deviceName: deviceName),
);

void main() {
  late FakeDeskPlanServer server;
  late InMemoryPairingStore store;
  late HttpsTaskUploader uploader;

  setUp(() async {
    server = await FakeDeskPlanServer.start();
    store = InMemoryPairingStore(_pairing(server.port));
    uploader = _uploaderFor(store);
  });

  tearDown(() => server.stop());

  group('save', () {
    test('sends PUT with the token and the contract body', () async {
      final task = Task.create(
        title: 'Pay rent',
        end: DateTime.utc(2026, 11, 1, 9),
        start: null,
      );
      server.status = 201;
      server.reply = {...task.toSyncJson(), 'result': 'created'};

      final result = await uploader.save(task);

      expect(result, isA<Confirmed>());
      expect((result as Confirmed).pcVersion, isNull);
      final seen = server.requests.single;
      expect(seen.method, 'PUT');
      expect(seen.path, '/v1/items/${task.id}');
      expect(seen.authorization, 'Bearer $_token');
      expect(seen.contentType, 'application/json');
      expect(seen.json['title'], 'Pay rent');
      expect(seen.json['done'], false);
      expect(seen.json['end'], '2026-11-01T09:00:00.000Z');
      expect(seen.json['start'], isNull);
    });

    test('kept-newer returns the PC version', () async {
      final task = Task.create(title: 'phone');
      final pc = Task(
        id: task.id,
        title: 'pc',
        done: true,
        updatedAt: DateTime.now(),
      );
      server.reply = {...pc.toSyncJson(), 'result': 'kept-newer'};

      final result = await uploader.save(task) as Confirmed;
      expect(result.pcVersion!.title, 'pc');
      expect(result.pcVersion!.done, true);
    });

    test('an unreadable 200 reply is retried, not trusted', () async {
      server.reply = {'hello': 'world'};
      expect(await uploader.save(Task.create(title: 'A')), isA<RetryLater>());
    });

    test('422 not-syncable is rejected with a plain explanation', () async {
      server.status = 422;
      server.reply = {'error': 'not-syncable'};
      final result = await uploader.save(Task.create(title: 'A'));
      // Notes sync now: only folders and files stay on the PC.
      expect((result as Rejected).reason, contains('folder or file'));
    });

    test('a note over 1 MB is refused on the phone, never sent', () async {
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
      final result = await uploader.save(huge);
      expect((result as Rejected).reason, contains('too big to sync'));
      expect(server.requests, isEmpty);
    });

    test('422 invalid-request is rejected, not retried', () async {
      server.status = 422;
      server.reply = {'error': 'invalid-request'};
      expect(await uploader.save(Task.create(title: 'A')), isA<Rejected>());
    });

    test(
      '413 too-large and 404/405 are rejected, not retried forever',
      () async {
        for (final status in [413, 404, 405]) {
          server.status = status;
          server.reply = {'error': 'x'};
          expect(
            await uploader.save(Task.create(title: 'A')),
            isA<Rejected>(),
            reason: 'status $status',
          );
        }
      },
    );
  });

  group('device name', () {
    test('is sent URL-encoded and capped at 80 characters', () async {
      final named = _uploaderFor(
        store,
        deviceName: _FixedName('Galaxy S24 ${'x' * 100}'),
      );
      server.reply = {'id': 'abc', 'deleted': true};
      await named.delete('abc');
      final sent = Uri.decodeComponent(
        server.requests.single.deviceNameHeader!,
      );
      expect(sent, startsWith('Galaxy S24 '));
      expect(sent.length, 80);
    });

    test('non-ASCII names survive the encoding', () async {
      final named = _uploaderFor(
        store,
        deviceName: _FixedName('Téléphone d\'Ana'),
      );
      server.reply = {'id': 'abc', 'deleted': true};
      await named.delete('abc');
      expect(
        Uri.decodeComponent(server.requests.single.deviceNameHeader!),
        'Téléphone d\'Ana',
      );
    });

    test('no provider means no header', () async {
      server.reply = {'id': 'abc', 'deleted': true};
      await uploader.delete('abc');
      expect(server.requests.single.deviceNameHeader, isNull);
    });
  });

  group('delete', () {
    test('sends DELETE with the token and no body', () async {
      final result = await uploader.delete('abc');
      expect(result, isA<Confirmed>());
      final seen = server.requests.single;
      expect(seen.method, 'DELETE');
      expect(seen.path, '/v1/items/abc');
      expect(seen.authorization, 'Bearer $_token');
      expect(seen.body, isEmpty);
    });

    test('a task already gone is still a success', () async {
      server.reply = {'id': 'abc', 'deleted': true};
      expect(await uploader.delete('abc'), isA<Confirmed>());
    });

    test('kept-has-contents drops the delete and tells the user', () async {
      server.reply = {
        'id': 'abc',
        'deleted': false,
        'result': 'kept-has-contents',
      };
      final result = await uploader.delete('abc');
      expect((result as Rejected).reason, contains('filed inside'));
    });
  });

  group('error replies', () {
    final task = Task.create(title: 'A');

    test('401 bad-token stops the run and says to pair again', () async {
      server.status = 401;
      server.reply = {'error': 'bad-token'};
      final result = await uploader.save(task);
      expect(result, isA<Unreachable>());
      expect((result as Unreachable).reason, contains('no longer paired'));
      expect(result.cause, UnreachableCause.unpaired);
      expect(result.retrySoon, false);
    });

    test('403 receiving-off stops the run without a quick retry', () async {
      server.status = 403;
      server.reply = {'error': 'receiving-off'};
      final result = await uploader.save(task) as Unreachable;
      expect(result.reason, contains('Receiving is off'));
      expect(result.cause, UnreachableCause.receivingOff);
      expect(result.retrySoon, false);
    });

    test('403 awaiting-approval asks to look again soon', () async {
      server.status = 403;
      server.reply = {'error': 'awaiting-approval'};
      final result = await uploader.save(task) as Unreachable;
      expect(result.reason, contains('approval'));
      expect(result.cause, UnreachableCause.awaitingApproval);
      expect(result.retrySoon, true);
    });

    test('503 (busy) is retried later', () async {
      server.status = 503;
      expect(await uploader.save(task), isA<RetryLater>());
    });

    test('an unexpected status is retried later', () async {
      server.status = 500;
      expect(await uploader.save(task), isA<RetryLater>());
    });
  });

  group('pinning and reachability', () {
    test('a server with a different certificate is refused, and no token '
        'or data is ever sent to it', () async {
      final impostor = await FakeDeskPlanServer.start(certName: 'other');
      addTearDown(impostor.stop);
      // Paired with the real fingerprint, but talking to the impostor's port.
      store.data = _pairing(impostor.port);

      final result = await uploader.save(Task.create(title: 'secret'));

      expect(result, isA<Unreachable>());
      expect((result as Unreachable).reason, contains('identity changed'));
      expect(result.cause, UnreachableCause.identityChanged);
      expect(impostor.requests, isEmpty);
    });

    test('nothing listening: unreachable, not a crash', () async {
      final port = server.port;
      await server.stop();
      store.data = _pairing(port);
      expect(await uploader.save(Task.create(title: 'A')), isA<Unreachable>());
    });

    test('not paired: unreachable, and nothing is sent', () async {
      store.data = null;
      final result = await uploader.save(Task.create(title: 'A'));
      expect((result as Unreachable).reason, contains('Not paired'));
      expect(result.cause, UnreachableCause.notPaired);
      expect(server.requests, isEmpty);
    });

    test('no address known: unreachable', () async {
      store.data = PairingData(
        name: 'PC',
        port: server.port,
        token: _token,
        fingerprint: FakeDeskPlanServer.fingerprintOf('test'),
      );
      expect(await uploader.save(Task.create(title: 'A')), isA<Unreachable>());
    });
  });
}
