import 'dart:convert';

import 'package:deskplan_companion/features/connection/deskplan_client.dart';
import 'package:deskplan_companion/features/connection/destination.dart';
import 'package:deskplan_companion/features/connection/pc_info.dart';
import 'package:deskplan_companion/features/connection/ping_result.dart';
import 'package:deskplan_companion/features/connection/ping_service.dart';
import 'package:deskplan_companion/features/connection/unreachable_cause.dart';
import 'package:deskplan_companion/features/discovery/hint_discovery.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_deskplan_server.dart';
import 'fakes/in_memory_pairing_store.dart';

final _token = base64.encode(List.filled(32, 7));

const _pingBody = {
  'name': 'DESKTOP-ABC',
  'version': '0.1.0',
  'receiving': true,
  'destinations': [
    {'id': 'received-files', 'label': 'Received files'},
    {'id': 'folder:7c1e', 'label': 'CSC101', 'name': 'CSC101', 'depth': 0},
    {
      'id': 'folder:2b9a',
      'label': 'CSC101 › Week 1',
      'name': 'Week 1',
      'depth': 1,
    },
  ],
  'allowedExtensions': ['pdf', 'png', 'url'],
};

void main() {
  group('PcInfo', () {
    test('reads destinations and allowed extensions', () {
      final info = PcInfo.fromJson(_pingBody);
      expect(info.name, 'DESKTOP-ABC');
      expect(info.destinations.map((d) => d.id), [
        'received-files',
        'folder:7c1e',
        'folder:2b9a',
      ]);
      expect(info.destinations.last.depth, 1);
      expect(info.allowedExtensions, {'pdf', 'png', 'url'});
    });

    test('always has Received files, and skips unreadable destinations', () {
      final info = PcInfo.fromJson({
        'name': 'PC',
        'destinations': [
          {'id': 'folder:1', 'label': 'A'},
          {'nonsense': true},
          42,
        ],
      });
      expect(info.destinations.map((d) => d.id), [
        'received-files',
        'folder:1',
      ]);
      // Until the PC says its own label, the phone says "Received files".
      expect(info.destinations.first.label, 'Received files');
    });

    test('the label of Received files is the one the PC sends', () {
      final info = PcInfo.fromJson({
        'name': 'PC',
        'destinations': [
          {'id': 'received-files', 'label': 'Received files'},
        ],
      });
      expect(info.destinations.single.label, 'Received files');
      expect(info.destinations.single.isReceivedFiles, true);
    });

    test(
      'an older PC that still lists "inbox" gets no second Received files',
      () {
        final info = PcInfo.fromJson({
          'name': 'PC',
          'destinations': [
            {'id': 'inbox', 'label': 'Received files'},
            {'id': 'folder:1', 'label': 'A'},
          ],
        });
        expect(info.destinations.map((d) => d.id), ['inbox', 'folder:1']);
        expect(info.destinations.first.isReceivedFiles, true);
      },
    );

    test('accepts judges by extension, any letter case', () {
      final info = PcInfo.fromJson(_pingBody);
      expect(info.accepts('notes.PDF'), true);
      expect(info.accepts('photo.png'), true);
      expect(info.accepts('setup.exe'), false);
      expect(info.accepts('README'), false);
      expect(info.accepts('trailing.'), false);
    });

    test('an old DeskPlan with no list refuses nothing', () {
      final info = PcInfo.fromJson({'name': 'PC'});
      expect(info.allowedExtensions, isNull);
      expect(info.accepts('setup.exe'), true);
    });

    test('survives a trip through JSON', () {
      final copy = PcInfo.fromJson(
        jsonDecode(jsonEncode(PcInfo.fromJson(_pingBody).toJson())),
      );
      expect(copy.allowedExtensions, {'pdf', 'png', 'url'});
      expect(copy.destinations.length, 3);
    });

    test('rejects something that is not a ping reply', () {
      expect(() => PcInfo.fromJson('hello'), throwsFormatException);
      expect(() => PcInfo.fromJson({'version': '1'}), throwsFormatException);
    });
  });

  group('PingService', () {
    late FakeDeskPlanServer server;
    late PingService service;

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
      service = PingService(DeskPlanClient(store, HintDiscovery()));
    });

    tearDown(() => server.stop());

    test('GET /v1/ping with the token, then reads the answer', () async {
      server.reply = _pingBody;
      final result = await service.ping();

      expect(result, isA<PingOk>());
      expect((result as PingOk).info.name, 'DESKTOP-ABC');
      final seen = server.requests.single;
      expect(seen.method, 'GET');
      expect(seen.path, '/v1/ping');
      expect(seen.authorization, 'Bearer $_token');
    });

    Future<UnreachableCause> blockedCause(int status, Object? body) async {
      server.status = status;
      server.reply = body;
      final result = await service.ping();
      return ((result as PingBlocked).problem).cause;
    }

    test('each blocking answer gets its own cause', () async {
      expect(
        await blockedCause(401, {'error': 'bad-token'}),
        UnreachableCause.unpaired,
      );
      expect(
        await blockedCause(403, {'error': 'receiving-off'}),
        UnreachableCause.receivingOff,
      );
      expect(
        await blockedCause(403, {'error': 'awaiting-approval'}),
        UnreachableCause.awaitingApproval,
      );
    });

    test('busy or odd answers are "other", not a crash', () async {
      expect(await blockedCause(503, null), UnreachableCause.other);
      expect(await blockedCause(500, null), UnreachableCause.other);
      expect(await blockedCause(200, {'nope': 1}), UnreachableCause.other);
    });

    test('Destination has the Received files constant', () {
      expect(Destination.receivedFiles.isReceivedFiles, true);
    });
  });
}
