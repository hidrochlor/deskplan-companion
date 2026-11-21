/// What a synced item is on DeskPlan (docs/protocol.md section 4).
enum TaskKind {
  /// A to-do. Inside an assignment it is called a step.
  task,

  /// A to-do with a due time that lives in a folder and holds steps. It has
  /// no tick: it shows its progress and is submitted instead.
  assignment,

  /// Formatted text (DeskPlan's `doc`), with no times and no tick. Synced
  /// only with a DeskPlan whose ping lists `notes`.
  note;

  /// The text used on the wire (`"task"`, `"assignment"` or `"note"`).
  String get wireName => name;

  /// Reads the wire text. Throws [FormatException] for anything else, which
  /// DeskPlan would refuse too.
  static TaskKind fromWire(Object? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    throw FormatException('Unknown kind: $value');
  }
}
