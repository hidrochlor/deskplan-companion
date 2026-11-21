import 'pairing_data.dart';

/// Remembers which PC this phone is paired with. Survives app restarts.
abstract class PairingStore {
  /// The saved pairing, or null if the phone isn't paired.
  Future<PairingData?> load();
  Future<void> save(PairingData data);

  /// Forget the pairing (the token is erased).
  Future<void> clear();
}
