import '../../core/task.dart';
import 'reminder_kind.dart';

/// A button on a reminder that pushes a one-off task or assignment back by
/// 30 minutes or an hour, without opening the app.
///
/// On the "Time to start" reminder it moves the whole time block (start and
/// end, so it keeps its length): "Start 30 min later". On the due reminders
/// it moves the end only: "Extend 30 min". Repeating items, imported
/// assignments (their due date is set by Moodle) and notes get no buttons.
class PushAction {
  static const _prefix = 'push';
  static const amounts = [Duration(minutes: 30), Duration(hours: 1)];

  final Duration by;

  /// True: start and end move. False: the end moves.
  final bool wholeBlock;

  const PushAction(this.by, {required this.wholeBlock});

  /// The buttons for a reminder of [kind].
  static List<PushAction> forKind(ReminderKind kind) => [
    for (final by in amounts)
      PushAction(by, wholeBlock: kind == ReminderKind.start),
  ];

  /// Whether [task]'s reminders get the buttons.
  static bool offeredFor(Task task) =>
      !task.done &&
      task.repeat == null &&
      !task.isImported &&
      !task.isNote &&
      task.end != null;

  /// The notification action's id: "push:later:30", "push:extend:60".
  String get id =>
      '$_prefix:${wholeBlock ? 'later' : 'extend'}:${by.inMinutes}';

  /// The button text: "Start 30 min later", "Extend 1 hr".
  String get label {
    final amount = by.inMinutes % 60 == 0
        ? '${by.inHours} hr'
        : '${by.inMinutes} min';
    return wholeBlock ? 'Start $amount later' : 'Extend $amount';
  }

  /// Reads an action id. Null for anything else (a plain tap).
  static PushAction? parse(String? id) {
    final parts = id?.split(':');
    if (parts == null || parts.length != 3 || parts[0] != _prefix) return null;
    final minutes = int.tryParse(parts[2]);
    if (minutes == null || minutes <= 0) return null;
    return switch (parts[1]) {
      'later' => PushAction(Duration(minutes: minutes), wholeBlock: true),
      'extend' => PushAction(Duration(minutes: minutes), wholeBlock: false),
      _ => null,
    };
  }

  /// [task] pushed back. A due time already past is extended from [now], so
  /// "Extend 1 hr" on a late reminder still gives a full hour.
  Task applyTo(Task task, DateTime now) {
    final start = task.start, end = task.end;
    if (end == null) return task;
    if (wholeBlock && start != null) {
      return task.copyWith(start: start.add(by), end: end.add(by));
    }
    final from = end.isBefore(now) ? now : end;
    return task.copyWith(end: from.add(by));
  }

  @override
  bool operator ==(Object other) =>
      other is PushAction && other.by == by && other.wholeBlock == wholeBlock;

  @override
  int get hashCode => Object.hash(by, wholeBlock);
}
