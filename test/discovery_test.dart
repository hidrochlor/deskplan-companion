import 'dart:convert';

import 'package:deskplan_companion/features/discovery/composite_discovery.dart';
import 'package:deskplan_companion/features/discovery/discovery.dart';
import 'package:deskplan_companion/features/discovery/found_service.dart';
import 'package:deskplan_companion/features/discovery/hint_discovery.dart';
import 'package:deskplan_companion/features/discovery/mdns_discovery.dart';
import 'package:deskplan_companion/features/discovery/pc_address.dart';
import 'package:deskplan_companion/features/discovery/service_finder.dart';
import 'package:deskplan_companion/features/discovery/typed_address_discovery.dart';
import 'package:deskplan_companion/features/discovery/typed_address_store.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:flutter_test/flutter_test.dart';

final _fingerprint = 'abcdef12${'0' * 56}';

PairingData _pairing({String? hint = '10.0.0.5', int port = 47800}) =>
    PairingData(
      name: 'PC',
      port: port,
      token: base64.encode(List.filled(32, 1)),
      fingerprint: _fingerprint,
      hint: hint,
    );

/// A network with the given announcements, counting how often it is searched.
class _FakeFinder implements ServiceFinder {
  final List<FoundService> onNetwork;
  int searches = 0;
  _FakeFinder(this.onNetwork);

  @override
  Future<List<FoundService>> find({
    required bool Function(FoundService) accept,
    required Duration timeout,
  }) async {
    searches++;
    return onNetwork.where(accept).toList();
  }
}

class _MemoryAddressStore implements TypedAddressStore {
  String? value;
  _MemoryAddressStore([this.value]);
  @override
  Future<String?> load() async => value;
  @override
  Future<void> save(String text) async => value = text;
  @override
  Future<void> clear() async => value = null;
}

class _Failing implements Discovery {
  @override
  Future<List<PcAddress>> candidates(PairingData pairing) =>
      throw StateError('boom');
}

void main() {
  group('PcAddress.parse', () {
    test('address alone uses the default port', () {
      final a = PcAddress.parse('192.168.1.5', defaultPort: 47800);
      expect(a, const PcAddress('192.168.1.5', 47800));
    });

    test('an address with a port, a name, and a pasted URL', () {
      expect(
        PcAddress.parse('192.168.1.5:47801', defaultPort: 47800),
        const PcAddress('192.168.1.5', 47801),
      );
      expect(
        PcAddress.parse('my-pc.local', defaultPort: 47800).host,
        'my-pc.local',
      );
      expect(
        PcAddress.parse(' https://10.0.0.2:47802/ ', defaultPort: 1),
        const PcAddress('10.0.0.2', 47802),
      );
    });

    test('rejects nonsense with a plain message', () {
      for (final bad in [
        '',
        '   ',
        'not an address',
        '1.2.3.4:0',
        '1.2.3.4:70000',
        'a b',
      ]) {
        expect(
          () => PcAddress.parse(bad, defaultPort: 47800),
          throwsFormatException,
          reason: '"$bad"',
        );
      }
    });
  });

  group('MdnsDiscovery', () {
    const announced = FoundService(
      addresses: ['192.168.1.9'],
      port: 47803,
      id: 'abcdef12',
    );

    test('uses the announced address and port', () async {
      final d = MdnsDiscovery(_FakeFinder([announced]));
      expect(await d.candidates(_pairing()), [
        const PcAddress('192.168.1.9', 47803),
      ]);
    });

    test('ignores another DeskPlan on the network (different id)', () async {
      const other = FoundService(
        addresses: ['192.168.1.77'],
        port: 47800,
        id: '99999999',
      );
      final d = MdnsDiscovery(_FakeFinder([other]));
      expect(await d.candidates(_pairing()), isEmpty);
    });

    test(
      'remembers an answer instead of searching before every request',
      () async {
        var clock = DateTime.utc(2026, 11, 1, 12);
        final finder = _FakeFinder([announced]);
        final d = MdnsDiscovery(finder, now: () => clock);

        await d.candidates(_pairing());
        await d.candidates(_pairing());
        expect(finder.searches, 1);

        clock = clock.add(const Duration(minutes: 3));
        await d.candidates(_pairing());
        expect(finder.searches, 2);
      },
    );

    test(
      'a miss is remembered only briefly, so a PC that turns on is found',
      () async {
        var clock = DateTime.utc(2026, 11, 1, 12);
        final finder = _FakeFinder([]);
        final d = MdnsDiscovery(finder, now: () => clock);

        await d.candidates(_pairing());
        await d.candidates(_pairing());
        expect(finder.searches, 1);

        clock = clock.add(const Duration(seconds: 30));
        await d.candidates(_pairing());
        expect(finder.searches, 2);
      },
    );
  });

  group('CompositeDiscovery', () {
    test('mDNS first, then the QR hint, then the typed address', () async {
      final d = CompositeDiscovery([
        MdnsDiscovery(
          _FakeFinder([
            const FoundService(
              addresses: ['192.168.1.9'],
              port: 47800,
              id: 'abcdef12',
            ),
          ]),
        ),
        HintDiscovery(),
        TypedAddressDiscovery(_MemoryAddressStore('172.16.0.4:47805')),
      ]);
      expect(await d.candidates(_pairing()), [
        const PcAddress('192.168.1.9', 47800),
        const PcAddress('10.0.0.5', 47800),
        const PcAddress('172.16.0.4', 47805),
      ]);
    });

    test('the same address from two sources is tried once', () async {
      final d = CompositeDiscovery([
        MdnsDiscovery(
          _FakeFinder([
            const FoundService(
              addresses: ['10.0.0.5'],
              port: 47800,
              id: 'abcdef12',
            ),
          ]),
        ),
        HintDiscovery(),
      ]);
      expect(await d.candidates(_pairing()), [
        const PcAddress('10.0.0.5', 47800),
      ]);
    });

    test('one source failing does not stop the others', () async {
      final d = CompositeDiscovery([_Failing(), HintDiscovery()]);
      expect(await d.candidates(_pairing()), [
        const PcAddress('10.0.0.5', 47800),
      ]);
    });
  });

  group('TypedAddressDiscovery', () {
    test('nothing typed, or something unusable, gives no address', () async {
      expect(
        await TypedAddressDiscovery(
          _MemoryAddressStore(),
        ).candidates(_pairing()),
        isEmpty,
      );
      expect(
        await TypedAddressDiscovery(
          _MemoryAddressStore('???'),
        ).candidates(_pairing()),
        isEmpty,
      );
    });

    test('a typed address without a port uses the paired port', () async {
      final d = TypedAddressDiscovery(_MemoryAddressStore('192.168.0.8'));
      expect(await d.candidates(_pairing(port: 47802)), [
        const PcAddress('192.168.0.8', 47802),
      ]);
    });
  });
}
