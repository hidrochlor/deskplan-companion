import '../core/task.dart';

/// How pressing a task is: red when it is overdue or comes within the hour,
/// amber within a day, grey later.
enum TaskTone { red, amber, grey }

/// The short text at the right of a task card: "Starts in 3hrs" until a time
/// block starts, then "Due in 1hr" until its end (an item with only an end,
/// like an assignment, says "Due in" from the first), "Overdue 10hrs" once its
/// end has passed. One unit only, rounded down.
class TaskCountdown {
  final String text;
  final TaskTone tone;

  const TaskCountdown(this.text, this.tone);

  /// Null for a done task, or one with no time still to come.
  static TaskCountdown? of(Task task, DateTime now) {
    if (task.done) return null;
    final start = task.start, end = task.end;
    if (end != null && end.isBefore(now)) {
      return TaskCountdown('Overdue ${short(now.difference(end))}', .red);
    }
    final DateTime target;
    final String prefix;
    if (start != null && start.isAfter(now)) {
      (target, prefix) = (start, 'Starts in');
    } else if (end != null) {
      (target, prefix) = (end, 'Due in');
    } else {
      return null; // old data: a start in the past and no end
    }
    final left = target.difference(now);
    final tone = left < const Duration(hours: 1)
        ? TaskTone.red
        : left < const Duration(hours: 24)
        ? TaskTone.amber
        : TaskTone.grey;
    return TaskCountdown('$prefix ${short(left)}', tone);
  }

  /// "5d", "3hrs", "1hr" or "39m".
  static String short(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours == 1) return '1hr';
    if (d.inHours > 0) return '${d.inHours}hrs';
    return '${d.inMinutes}m';
  }
}
