import '../connection/pc_info.dart';
import '../connection/unreachable_cause.dart';

/// Summary of one queue run, for showing in the UI or logging.
class SyncReport {
  int sent = 0;

  /// Files DeskPlan received in this run.
  int filesSent = 0;

  /// Tasks changed on the phone by what DeskPlan sent back (the pull).
  int pulled = 0;

  /// DeskPlan is too old to send changes: the phone only pushes to it.
  bool pullUnsupported = false;

  /// Why the pull did not complete, if it did not (it is tried again next
  /// sync, so this is information, not an error to act on).
  String? pullFailure;
  int retryLater = 0;

  /// The calendar's events were fetched again in this run.
  bool calendarUpdated = false;

  /// Why the calendar fetch did not complete, if it did not (tried again at
  /// the next sync, like the pull).
  String? calendarFailure;

  /// One plain-language line per action DeskPlan refused for good.
  final List<String> rejections = [];

  /// Set when the run stopped early because DeskPlan couldn't be reached.
  String? unreachableReason;

  /// With [unreachableReason]: which kind of problem it is.
  UnreachableCause? unreachableCause;

  /// What DeskPlan said about itself in this run's ping, if it answered.
  PcInfo? pcInfo;

  /// With [unreachableReason]: it should clear up soon, so try again shortly.
  bool retrySoon = false;

  /// True when another run was already going, so this one did nothing.
  bool skipped = false;

  int get rejected => rejections.length;
}
