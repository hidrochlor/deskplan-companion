import '../connection/client_reply.dart';
import 'pull_reply.dart';

/// What came of asking DeskPlan "what changed?".
sealed class PullResult {
  const PullResult();
}

class PullOk extends PullResult {
  final PullReply reply;
  const PullOk(this.reply);
}

/// `404`: this DeskPlan is too old to answer. The phone keeps working as a
/// push-only phone.
class PullUnsupported extends PullResult {
  const PullUnsupported();
}

/// The phone is blocked as a whole (not approved, receiving off, no longer
/// paired, cannot be reached).
class PullBlocked extends PullResult {
  final NoReply problem;
  const PullBlocked(this.problem);
}

/// Something went wrong that may clear up; try again at the next sync. When
/// [resetPlace] is true the saved "since" is no good and is forgotten, so the
/// next pull asks for everything.
class PullFailed extends PullResult {
  final String reason;
  final bool resetPlace;
  const PullFailed(this.reason, {this.resetPlace = false});
}
