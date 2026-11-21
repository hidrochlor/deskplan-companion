import 'pull_outcome.dart';

/// Brings DeskPlan's changes to the phone. Behind an interface so the sync
/// can be tested with a fake.
abstract class ChangePuller {
  /// Never throws: any problem comes back in the [PullOutcome]. [notes] is
  /// true when DeskPlan's ping lists `notes`: notes are asked for too.
  Future<PullOutcome> pull({bool notes = false});
}
