import 'push_action.dart';
import 'reminder_kind.dart';

/// One notification we want to show: what, and when (an instant in time).
class PlannedReminder {
  final String taskId;
  final ReminderKind kind;
  final DateTime at;

  /// The item's name: "30min task".
  final String title;

  /// What is happening: "Time to start", "Due in 1 hour".
  final String body;

  /// What the item is, shown after the app name: "Task" or "Assignment".
  final String label;

  /// The buttons that push the item back; empty for none.
  final List<PushAction> actions;

  const PlannedReminder({
    required this.taskId,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.label = 'Task',
    this.actions = const [],
  });
}
