import '../pairing/pairing_data.dart';
import 'discovery.dart';
import 'pc_address.dart';

/// Tries several ways of finding the PC and puts their answers in one list, in
/// the order given, without repeats. The app uses mDNS, then the QR hint, then
/// the typed address (docs/protocol.md section 3).
class CompositeDiscovery implements Discovery {
  final List<Discovery> _sources;

  CompositeDiscovery(this._sources);

  @override
  Future<List<PcAddress>> candidates(PairingData pairing) async {
    final seen = <PcAddress>{};
    for (final source in _sources) {
      try {
        seen.addAll(await source.candidates(pairing));
      } catch (_) {
        // One way failing must not stop the others.
      }
    }
    return seen.toList(); // a Set keeps the order things were added in
  }
}
