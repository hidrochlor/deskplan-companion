import 'dart:convert';

import '../connection/client_reply.dart';
import '../connection/deskplan_client.dart';
import 'calendar_reply.dart';
import 'calendar_result.dart';

/// `GET /v1/calendar` with no `from` or `to`: DeskPlan's default window, 14
/// days back to 180 days ahead of its own clock (protocol.md section 5).
class CalendarService {
  final DeskPlanClient _client;

  CalendarService(this._client);

  Future<CalendarResult> fetch() async {
    final reply = await _client.send('GET', ['v1', 'calendar']);
    if (reply is NoReply) return CalendarBlocked(reply);
    final Reply(:status, :body) = reply as Reply;

    final blocked = NoReply.fromStatus(status, DeskPlanClient.errorCode(body));
    if (blocked != null) return CalendarBlocked(blocked);

    switch (status) {
      case 200:
        try {
          return CalendarOk(CalendarReply.fromJson(jsonDecode(body)));
        } on FormatException catch (e) {
          return CalendarFailed(
            'DeskPlan sent a calendar the phone cannot read (${e.message})',
          );
        }
      case 404:
        return const CalendarUnsupported();
      case 503:
        return const CalendarFailed('DeskPlan is busy or starting');
      default:
        return CalendarFailed(
          'Unexpected calendar reply from DeskPlan ($status)',
        );
    }
  }
}
