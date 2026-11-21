import 'unreachable_cause.dart';

/// What came back from one call to DeskPlan: either an HTTP answer or a
/// reason there was none.
sealed class ClientReply {
  const ClientReply();
}

/// DeskPlan answered with [status] and the body text.
class Reply extends ClientReply {
  final int status;
  final String body;
  const Reply(this.status, this.body);
}

/// No usable answer: it could not be reached, or the answer means the phone
/// is blocked as a whole (not paired, not approved, receiving off).
class NoReply extends ClientReply {
  final UnreachableCause cause;
  final String message;

  /// Should clear up within seconds (the user is about to approve this phone).
  final bool retrySoon;

  const NoReply(this.cause, this.message, {this.retrySoon = false});

  /// Turns a `401` or `403` answer into the matching state, or null for any
  /// other answer. These apply to every endpoint, so they are handled once.
  static NoReply? fromStatus(int status, String? errorCode) {
    if (status == 401) {
      return const NoReply(
        UnreachableCause.unpaired,
        'This phone is no longer paired with DeskPlan. Pair again',
      );
    }
    if (status == 403) {
      return errorCode == 'awaiting-approval'
          ? const NoReply(
              UnreachableCause.awaitingApproval,
              'Waiting for approval on your PC',
              retrySoon: true,
            )
          : const NoReply(
              UnreachableCause.receivingOff,
              'Receiving is off on your PC',
            );
    }
    return null;
  }
}
