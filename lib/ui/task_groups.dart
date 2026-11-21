import '../core/task.dart';

enum TaskGroupKind { overdue, day, noDate }

/// One heading of the Tasks list and the tasks under it.
class TaskGroup {
  final TaskGroupKind kind;

  /// For a [TaskGroupKind.day] group: the day, at local midnight.
  final DateTime? day;
  final List<Task> tasks;

  const TaskGroup(this.kind, this.tasks, {this.day});
}

/// Splits the open tasks into the Tasks list's headings: Overdue (its end
/// has passed) first, oldest first; then one heading per day, soonest
/// first; then those with no time. A task sits on the day it next needs you:
/// the day it starts, or today while it runs.
class TaskGroups {
  static List<TaskGroup> of(List<Task> open, DateTime now) {
    final overdue = <Task>[];
    final noDate = <Task>[];
    final byDay = <DateTime, List<Task>>{};
    for (final t in open) {
      final end = t.end;
      final at = t.start ?? end;
      if (end != null && end.isBefore(now)) {
        overdue.add(t);
      } else if (at == null) {
        noDate.add(t);
      } else {
        final next = (at.isAfter(now) ? at : now).toLocal();
        byDay
            .putIfAbsent(DateTime(next.year, next.month, next.day), () => [])
            .add(t);
      }
    }
    overdue.sort((a, b) => a.end!.compareTo(b.end!));
    final days = byDay.keys.toList()..sort();
    return [
      if (overdue.isNotEmpty) TaskGroup(TaskGroupKind.overdue, overdue),
      for (final day in days)
        TaskGroup(
          TaskGroupKind.day,
          byDay[day]!
            ..sort((a, b) => (a.start ?? a.end!).compareTo(b.start ?? b.end!)),
          day: day,
        ),
      if (noDate.isNotEmpty) TaskGroup(TaskGroupKind.noDate, noDate),
    ];
  }
}
