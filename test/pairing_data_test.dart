import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';

final _token = base64.encode(List.filled(32, 1));
final _fp = 'AB' * 32;

Map<String, Object?> _valid() => {
  'v': 1,
  'name': 'My PC',
  'port': 47800,
  'token': _token,
  'fp': _fp,
  'hint': '192.168.1.20',
};

void _expectRejected(Map<String, Object?> json) =>
    expect(() => PairingData.parse(jsonEncode(json)), throwsFormatException);

void main() {
  test('accepts a valid code and normalises the fingerprint', () {
    final d = PairingData.parse(jsonEncode(_valid()));
    expect(d.name, 'My PC');
    expect(d.port, 47800);
    expect(d.token, _token);
    expect(d.fingerprint, 'ab' * 32);
    expect(d.hint, '192.168.1.20');
  });

  test('the hint is optional', () {
    expect(
      PairingData.parse(jsonEncode(_valid()..remove('hint'))).hint,
      isNull,
    );
    expect(
      PairingData.parse(jsonEncode(_valid()..['hint'] = null)).hint,
      isNull,
    );
  });

  test('survives saving and loading', () {
    final d = PairingData.parse(jsonEncode(_valid()));
    final back = PairingData.fromJson(d.toJson().cast<String, dynamic>());
    expect(back.fingerprint, d.fingerprint);
    expect(back.token, d.token);
    expect(back.hint, d.hint);
  });

  test('rejects text that is not JSON, or not an object', () {
    expect(() => PairingData.parse('hello'), throwsFormatException);
    expect(() => PairingData.parse('[1,2]'), throwsFormatException);
    expect(() => PairingData.parse(''), throwsFormatException);
  });

  test('rejects a wrong or missing version', () {
    _expectRejected(_valid()..['v'] = 2);
    _expectRejected(_valid()..remove('v'));
  });

  test('rejects a bad name', () {
    _expectRejected(_valid()..['name'] = '');
    _expectRejected(_valid()..['name'] = 5);
    _expectRejected(_valid()..remove('name'));
  });

  test('rejects a bad port', () {
    _expectRejected(_valid()..['port'] = 0);
    _expectRejected(_valid()..['port'] = 70000);
    _expectRejected(_valid()..['port'] = '47800');
  });

  test('rejects a token that is not 32 bytes of base64', () {
    _expectRejected(_valid()..['token'] = 'not base64!!');
    _expectRejected(_valid()..['token'] = base64.encode(List.filled(16, 1)));
    _expectRejected(_valid()..remove('token'));
  });

  test('rejects a fingerprint that is not 64 hex characters', () {
    _expectRejected(_valid()..['fp'] = 'abcd');
    _expectRejected(_valid()..['fp'] = 'zz' * 32);
    _expectRejected(_valid()..['fp'] = '${'ab' * 32}00');
  });

  test('rejects a hint that is not an IP address', () {
    _expectRejected(_valid()..['hint'] = 'evil.example.com');
    _expectRejected(_valid()..['hint'] = 42);
  });
}
