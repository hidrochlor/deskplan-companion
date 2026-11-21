import '../pairing/pairing_data.dart';
import 'discovery.dart';
import 'pc_address.dart';

/// The address stored in the QR code. It breaks if the PC's address changes,
/// which is why it is only the second choice, after mDNS.
class HintDiscovery implements Discovery {
  @override
  Future<List<PcAddress>> candidates(PairingData pairing) async => [
    if (pairing.hint != null) PcAddress(pairing.hint!, pairing.port),
  ];
}
