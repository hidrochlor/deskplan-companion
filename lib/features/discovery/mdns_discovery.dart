import '../pairing/pairing_data.dart';
import 'discovery.dart';
import 'pc_address.dart';
import 'service_finder.dart';

/// Finds the PC by its mDNS announcement (`_deskplan._tcp`). Matches the
/// announcement's `id` against the paired PC's fingerprint, so another
/// DeskPlan on the same network is never mistaken for it.
///
/// Searching takes a moment, so the answer is remembered for a while: a sync
/// makes several requests and should not search before each one.
class MdnsDiscovery implements Discovery {
  final ServiceFinder _finder;
  final Duration _searchTime;
  final Duration _rememberFound;
  final Duration _rememberMissing;
  final DateTime Function() _now;

  List<PcAddress> _last = const [];
  String? _lastFingerprint;
  DateTime? _lastAt;

  MdnsDiscovery(
    this._finder, {
    this._searchTime = const Duration(seconds: 3),
    this._rememberFound = const Duration(minutes: 2),
    this._rememberMissing = const Duration(seconds: 20),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<List<PcAddress>> candidates(PairingData pairing) async {
    final now = _now();
    final at = _lastAt;
    if (at != null && _lastFingerprint == pairing.fingerprint) {
      final keep = _last.isEmpty ? _rememberMissing : _rememberFound;
      if (now.difference(at) < keep) return _last;
    }

    // The announcement carries the first 8 characters of the fingerprint.
    final id = pairing.fingerprint.substring(0, 8);
    final services = await _finder.find(
      accept: (s) => s.id?.toLowerCase() == id,
      timeout: _searchTime,
    );
    _last = [
      for (final s in services)
        for (final a in s.addresses) PcAddress(a, s.port),
    ];
    _lastFingerprint = pairing.fingerprint;
    _lastAt = _now();
    return _last;
  }
}
