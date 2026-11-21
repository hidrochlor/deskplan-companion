import 'sync_action.dart';

/// The waiting list of actions. Survives app restarts.
abstract class ActionQueue {
  /// Add an action for [taskId], replacing any older one for the same task.
  /// The new action is due immediately.
  Future<void> enqueue(String taskId, ActionType type);

  /// Actions whose retry time has come, oldest first.
  Future<List<SyncAction>> due(DateTime now);

  /// Remove [action] after DeskPlan confirmed it. Does nothing if the task
  /// has since been given a newer action.
  Future<void> complete(SyncAction action);

  /// Count the failed try, remember why, and try again at [nextAttemptAt].
  /// Does nothing if the task has since been given a newer action.
  Future<void> reschedule(
    SyncAction action, {
    required DateTime nextAttemptAt,
    required String error,
  });

  /// True if [taskId] has a change that has not reached DeskPlan yet. A
  /// change pulled from DeskPlan must not overwrite it.
  Future<bool> hasPending(String taskId);

  /// How many actions are waiting (due or not).
  Future<int> pendingCount();
}
