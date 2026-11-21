import 'package:deskplan_companion/features/connection/client_reply.dart';
import 'package:deskplan_companion/features/connection/connection_checker.dart';
import 'package:deskplan_companion/features/connection/pc_info.dart';
import 'package:deskplan_companion/features/connection/ping_result.dart';
import 'package:deskplan_companion/features/connection/unreachable_cause.dart';

/// A [ConnectionChecker] that answers with whatever the test sets.
/// By default DeskPlan answers fine.
class FakeConnectionChecker implements ConnectionChecker {
  PingResult result = const PingOk(
    PcInfo(name: 'Test PC', version: '0.1.0', destinations: []),
  );
  int checks = 0;

  void block(UnreachableCause cause, String message) =>
      result = PingBlocked(NoReply(cause, message));

  @override
  Future<PingResult> check() async {
    checks++;
    return result;
  }
}
