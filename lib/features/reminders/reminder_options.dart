import 'reminder_kind.dart';

/// A warning before something is due, on top of the "Due now" reminder. Any
/// number of them can be on at once. Listed shortest first, as the screen
/// shows them.
enum DueWarning {
  minutes30(
    Duration(minutes: 30),
    '30 mins',
    'Due in 30 minutes',
    ReminderKind.minutes30Before,
  ),
  hour1(Duration(hours: 1), '1 hr', 'Due in 1 hour', ReminderKind.hourBefore),
  hours3(
    Duration(hours: 3),
    '3 hrs',
    'Due in 3 hours',
    ReminderKind.hours3Before,
  ),
  hours5(
    Duration(hours: 5),
    '5 hrs',
    'Due in 5 hours',
    ReminderKind.hours5Before,
  ),
  day1(Duration(days: 1), '1 day', 'Due tomorrow', ReminderKind.dayBefore);

  /// How long before the due time it reminds.
  final Duration before;

  /// The text on its toggle in Reminders.
  final String label;

  /// The notification's title: "Due in 1 hour".
  final String title;

  /// The title before a task's start instead: "Starts in 1 hour".
  String get startTitle => title.replaceFirst('Due', 'Starts');
  final ReminderKind kind;

  const DueWarning(this.before, this.label, this.title, this.kind);
}

/// The user's choices for task and exam reminders. The defaults are how the
/// app behaved before these could be changed.
class ReminderOptions {
  /// The warnings that are on. None means only "Due now".
  final Set<DueWarning> warnings;

  /// Exams get a reminder a day and an hour before they start.
  final bool exams;

  const ReminderOptions({this.warnings = const {}, this.exams = true});

  ReminderOptions copyWith({Set<DueWarning>? warnings, bool? exams}) =>
      ReminderOptions(
        warnings: warnings ?? this.warnings,
        exams: exams ?? this.exams,
      );

  /// The same options with [warning] switched on or off.
  ReminderOptions toggled(DueWarning warning) => copyWith(
    warnings: warnings.contains(warning)
        ? ({...warnings}..remove(warning))
        : {...warnings, warning},
  );
}
