/// The user's daily personal-goal reminder: one notification a day at a
/// fixed time with their own text.
class GoalReminder {
  /// Shown as the field's hint, and used in the notification when the user
  /// has not written their own goal.
  static const defaultText = 'What is your goal today?';

  final bool enabled;
  final int hour;
  final int minute;
  final String text;

  const GoalReminder({
    this.enabled = false,
    this.hour = 8,
    this.minute = 0,
    this.text = '',
  });

  GoalReminder copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    String? text,
  }) => GoalReminder(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    text: text ?? this.text,
  );
}
