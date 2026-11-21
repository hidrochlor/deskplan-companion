import 'dart:convert';

import 'client_reply.dart';
import 'deskplan_client.dart';
import 'pc_info.dart';
import 'ping_result.dart';
import 'unreachable_cause.dart';

/// `GET /v1/ping`: tests the connection, learns the PC name and lists
/// where files can go and which file types it takes.
class PingService {
  final DeskPlanClient _client;

  PingService(this._client);

  Future<PingResult> ping() async {
    final reply = await _client.send('GET', ['v1', 'ping']);
    if (reply is NoReply) return PingBlocked(reply);
    final Reply(:status, :body) = reply as Reply;

    final blocked = NoReply.fromStatus(status, DeskPlanClient.errorCode(body));
    if (blocked != null) return PingBlocked(blocked);

    if (status == 200) {
      try {
        return PingOk(PcInfo.fromJson(jsonDecode(body)));
      } on FormatException {
        return const PingBlocked(
          NoReply(UnreachableCause.other, 'DeskPlan sent an unreadable reply'),
        );
      }
    }
    if (status == 503) {
      return const PingBlocked(
        NoReply(UnreachableCause.other, 'DeskPlan is busy or starting'),
      );
    }
    return PingBlocked(
      NoReply(
        UnreachableCause.other,
        'Unexpected reply from DeskPlan ($status)',
      ),
    );
  }
}
