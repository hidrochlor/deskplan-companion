enum ActionType { save, delete }

/// One thing waiting to be told to DeskPlan: "save this task" or "delete it".
/// The queue keeps at most one action per task (the newest one wins).
class SyncAction {
  /// Order number from the database. A newer action for the same task gets a
  /// new `seq`, so finishing an old action can never erase a newer edit.
  final int seq;
  final String taskId;
  final ActionType type;
  final int attempts;
  final DateTime nextAttemptAt;
  final String? lastError;

  const SyncAction({
    required this.seq,
    required this.taskId,
    required this.type,
    required this.attempts,
    required this.nextAttemptAt,
    this.lastError,
  });
}
