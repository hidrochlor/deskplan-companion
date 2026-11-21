import '../../core/task.dart';
import 'planned_reminder.dart';
import 'push_action.dart';
import 'reminder_kind.dart';
import 'reminder_options.dart';

/// Decides which reminders a task needs. Pure logic, no Android, so it is
/// easy to test. A done task has none, and times already past are skipped.
/// The chosen warnings come before a task's start, or before the due time
/// when it has no start.
class ReminderPlanner {
  static List<PlannedReminder> forTask(
    Task task,
    DateTime now, {
    Set<DueWarning> warnings = const {},
  }) {
    if (task.done) return const [];
    final plan = <PlannedReminder>[];
    final canPush = PushAction.offeredFor(task);
    void add(ReminderKind kind, DateTime at, String title) {
      if (at.isAfter(now)) {
        plan.add(
          PlannedReminder(
            taskId: task.id,
            kind: kind,
            at: at,
            title: task.title,
            body: title,
            label: task.isAssignment ? 'Assignment' : 'Task',
            actions: canPush ? PushAction.forKind(kind) : const [],
          ),
        );
      }
    }

    final start = task.start;
    final end = task.end;
    // The warnings lead up to what needs you first: a time block's start
    // (From), or the due time of something with only that (an assignment).
    final anchor = start ?? end;
    if (anchor != null) {
      // Longest warning first, so the plan is in time order.
      for (final w in DueWarning.values.reversed) {
        if (warnings.contains(w)) {
          add(
            w.kind,
            anchor.subtract(w.before),
            start != null ? w.startTitle : w.title,
          );
        }
      }
    }
    if (start != null) add(ReminderKind.start, start, 'Time to start');
    if (end != null) add(ReminderKind.end, end, 'Due now');
    return plan;
  }
}
