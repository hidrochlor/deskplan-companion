import '../pairing/pairing_data.dart';
import 'discovery.dart';
import 'pc_address.dart';
import 'typed_address_store.dart';

/// The address the user typed by hand, if any. The last resort.
class TypedAddressDiscovery implements Discovery {
  final TypedAddressStore _store;

  TypedAddressDiscovery(this._store);

  @override
  Future<List<PcAddress>> candidates(PairingData pairing) async {
    final text = await _store.load();
    if (text == null) return const [];
    try {
      return [PcAddress.parse(text, defaultPort: pairing.port)];
    } on FormatException {
      return const []; // damaged or hand-edited: ignore it
    }
  }
}
