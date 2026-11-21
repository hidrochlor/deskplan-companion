import 'dart:convert';

import '../connection/client_reply.dart';
import '../connection/deskplan_client.dart';
import 'pull_reply.dart';
import 'pull_result.dart';

/// `GET /v1/items?since=<time>&kinds=...`: asks DeskPlan what changed since
/// [since] (nothing given means "everything", for the first sync after
/// pairing). [kinds] is sent only when it asks for more than DeskPlan's
/// default (tasks and assignments), so an older DeskPlan is asked exactly
/// what it always was.
class PullService {
  /// What DeskPlan sends when `kinds` is left out.
  static const defaultKinds = 'task,assignment';

  final DeskPlanClient _client;

  PullService(this._client);

  Future<PullResult> pull({String? since, String kinds = defaultKinds}) async {
    final query = {'since': ?since, if (kinds != defaultKinds) 'kinds': kinds};
    final reply = await _client.send('GET', [
      'v1',
      'items',
    ], query: query.isEmpty ? null : query);
    if (reply is NoReply) return PullBlocked(reply);
    final Reply(:status, :body) = reply as Reply;
    final code = DeskPlanClient.errorCode(body);

    final blocked = NoReply.fromStatus(status, code);
    if (blocked != null) return PullBlocked(blocked);

    switch (status) {
      case 200:
        try {
          return PullOk(PullReply.fromJson(jsonDecode(body)));
        } on FormatException catch (e) {
          return PullFailed(
            'DeskPlan sent changes the phone cannot read '
            '(${e.message})',
          );
        }
      case 404:
        return const PullUnsupported();
      case 422:
        // The saved place was refused: forget it and ask for everything.
        return const PullFailed(
          'DeskPlan did not accept the last sync time',
          resetPlace: true,
        );
      case 503:
        return const PullFailed('DeskPlan is busy or starting');
      default:
        return PullFailed('Unexpected reply from DeskPlan ($status)');
    }
  }
}
