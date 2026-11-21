import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:deskplan_companion/features/pairing/pairing_store.dart';

class InMemoryPairingStore implements PairingStore {
  PairingData? data;

  InMemoryPairingStore([this.data]);

  @override
  Future<PairingData?> load() async => data;
  @override
  Future<void> save(PairingData d) async => data = d;
  @override
  Future<void> clear() async => data = null;
}
