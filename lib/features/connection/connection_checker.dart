import 'pc_info_store.dart';
import 'ping_result.dart';
import 'ping_service.dart';

/// Pings DeskPlan and remembers what it said. Run at the start of every
/// sync: a failure here already tells the screen the exact reason
/// (not approved, receiving off, no longer paired), without trying the queue.
class ConnectionChecker {
  final PingService _ping;
  final PcInfoStore _store;

  ConnectionChecker(this._ping, this._store);

  Future<PingResult> check() async {
    final result = await _ping.ping();
    if (result is PingOk) {
      try {
        await _store.save(result.info);
      } catch (_) {
        // Not being able to remember it must not break a working connection.
      }
    }
    return result;
  }
}
