import '../connection/client_reply.dart';

/// The result of one pull, in the terms the sync report needs.
class PullOutcome {
  /// How many tasks changed on the phone.
  final int changed;

  /// DeskPlan is too old to send changes (`404`).
  final bool unsupported;

  /// The phone is blocked as a whole, with the reason.
  final NoReply? blocked;

  /// A problem that may clear up by itself, for the log or a quiet note.
  final String? failure;

  const PullOutcome({
    this.changed = 0,
    this.unsupported = false,
    this.blocked,
    this.failure,
  });
}
