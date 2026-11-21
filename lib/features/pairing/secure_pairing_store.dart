import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pairing_data.dart';
import 'pairing_store.dart';

/// Keeps the pairing in Android's encrypted storage, because it contains
/// the secret token. (The normal database is readable by backups.)
class SecurePairingStore implements PairingStore {
  static const _key = 'pairing_v1';
  final FlutterSecureStorage _storage;

  SecurePairingStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<PairingData?> load() async {
    final text = await _storage.read(key: _key);
    if (text == null) return null;
    try {
      return PairingData.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on Object {
      // Damaged or unreadable: treat as not paired rather than crash.
      return null;
    }
  }

  @override
  Future<void> save(PairingData data) =>
      _storage.write(key: _key, value: jsonEncode(data.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
