import 'package:deskplan_companion/features/pull/change_puller.dart';
import 'package:deskplan_companion/features/pull/pull_outcome.dart';

/// A [ChangePuller] that answers with whatever the test sets and counts how
/// often it was asked. By default nothing changed.
class FakeChangePuller implements ChangePuller {
  PullOutcome outcome = const PullOutcome();
  int pulls = 0;

  /// Whether the last pull asked for notes.
  bool? askedForNotes;

  @override
  Future<PullOutcome> pull({bool notes = false}) async {
    pulls++;
    askedForNotes = notes;
    return outcome;
  }
}
