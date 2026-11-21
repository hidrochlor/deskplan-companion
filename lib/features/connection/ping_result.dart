import 'client_reply.dart';
import 'pc_info.dart';

/// The outcome of asking DeskPlan "are you there, and who are you?".
sealed class PingResult {
  const PingResult();
}

class PingOk extends PingResult {
  final PcInfo info;
  const PingOk(this.info);
}

/// DeskPlan did not give a usable answer; [problem] says why.
class PingBlocked extends PingResult {
  final NoReply problem;
  const PingBlocked(this.problem);
}
