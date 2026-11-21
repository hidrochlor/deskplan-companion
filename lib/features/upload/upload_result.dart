import '../../core/task.dart';
import '../connection/unreachable_cause.dart';

/// What happened when we told DeskPlan about one action.
sealed class UploadResult {
  const UploadResult();
}

/// DeskPlan accepted it (HTTP 200/201). If DeskPlan kept its own newer
/// version of a saved task (`"result": "kept-newer"`), it is in [pcVersion].
/// Otherwise [stored] is the task as DeskPlan now stores it, for the fields
/// only DeskPlan decides (`course`, `source`, an imported item's `end`).
class Confirmed extends UploadResult {
  final Task? pcVersion;
  final Task? stored;
  const Confirmed({this.pcVersion, this.stored});
}

/// This action failed but may work later (for example 503 busy).
/// It stays in the queue and is tried again after a delay.
class RetryLater extends UploadResult {
  final String reason;

  /// Give up after this many failed tries (null: keep trying). Used for
  /// problems that are unlikely to clear, such as a damaged transfer.
  final int? maxAttempts;

  const RetryLater(this.reason, {this.maxAttempts});
}

/// DeskPlan will never accept this action (HTTP 422). Retrying is pointless,
/// so the action is dropped.
class Rejected extends UploadResult {
  final String reason;
  const Rejected(this.reason);
}

/// DeskPlan can't be reached at all (PC off, wrong network, receiving off).
/// The whole run stops: trying the other actions would fail too.
class Unreachable extends UploadResult {
  final String reason;

  /// Which kind of problem it is, so the screen can show the right help.
  final UnreachableCause cause;

  /// True when it should clear up within seconds (for example the user is
  /// about to approve this phone on the PC), so the screen may try again soon.
  final bool retrySoon;

  const Unreachable(
    this.reason, {
    this.cause = UnreachableCause.other,
    this.retrySoon = false,
  });
}
