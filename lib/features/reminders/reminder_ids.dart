import 'reminder_kind.dart';

/// Android wants a whole number to identify each notification, but our task
/// ids are UUID text. This turns one into the other the same way every time,
/// so a task's reminders can be replaced or cancelled later.
class ReminderIds {
  /// Reserved for the daily goal reminder. Task reminders never use it.
  static const dailyGoal = 1;

  static int forTask(String taskId, ReminderKind kind) => switch (kind) {
    ReminderKind.start || ReminderKind.end => _hash(taskId, kind.index),
    // The lowest bit only has room for start and end, so the warnings hash a
    // prefixed id instead, as exam reminders do.
    _ => _hash('${kind.name}:$taskId', 1),
  };

  static int _hash(String text, int bit) {
    // FNV-1a hash of the text, squeezed into 30 bits and moved up by one so it
    // is never 0. The lowest bit then says start (0) or end (1), which keeps
    // the two reminders of one task apart and the result at least 2.
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    final base = (hash % 0x3FFFFFFF) + 1;
    return (base << 1) | bit;
  }
}
