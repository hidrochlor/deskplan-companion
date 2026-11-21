import '../pairing/pairing_data.dart';
import 'pc_address.dart';

/// Finds addresses where the paired PC might be right now, best guess first.
/// The client tries them in order (docs/protocol.md section 3).
abstract class Discovery {
  Future<List<PcAddress>> candidates(PairingData pairing);
}
