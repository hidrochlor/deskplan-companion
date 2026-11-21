import '../../core/task.dart';
import 'goal_reminder.dart';

/// Puts reminders on the phone's clock. The app talks to this interface, so
/// tests can use a fake and the Android part stays in one place.
abstract class ReminderScheduler {
  /// Replaces the task's reminders with the ones it needs now.
  Future<void> scheduleTask(Task task);

  Future<void> cancelTask(String taskId);

  /// Replaces everything: used when the app opens (for example after the
  /// phone restarted) so no reminder is missing.
  Future<void> rescheduleAll(List<Task> tasks);

  /// Sets the daily goal reminder, or removes it when [goal] is off.
  Future<void> setDailyGoal(GoalReminder goal);
}
