import 'pc_info.dart';

/// Remembers the last successful ping, so the share sheet can still check
/// file types and show folders when the PC cannot be reached right now.
abstract class PcInfoStore {
  Future<PcInfo?> load();
  Future<void> save(PcInfo info);

  /// Forget it (when the phone is paired with a different PC).
  Future<void> clear();
}
