import 'package:shared_preferences/shared_preferences.dart';

import 'goal_reminder.dart';

/// Remembers the daily goal reminder between app runs.
class GoalReminderStore {
  static const _enabled = 'goal.enabled';
  static const _hour = 'goal.hour';
  static const _minute = 'goal.minute';
  static const _text = 'goal.text';

  Future<GoalReminder> load() async {
    final prefs = await SharedPreferences.getInstance();
    const fallback = GoalReminder();
    // Earlier versions saved the prompt itself as if the user had typed it.
    // It is a hint now, not content.
    final saved = prefs.getString(_text);
    final isOldPrompt =
        saved == 'What is your goal for today?' ||
        saved == GoalReminder.defaultText;
    return GoalReminder(
      enabled: prefs.getBool(_enabled) ?? fallback.enabled,
      hour: prefs.getInt(_hour) ?? fallback.hour,
      minute: prefs.getInt(_minute) ?? fallback.minute,
      text: (saved == null || isOldPrompt) ? fallback.text : saved,
    );
  }

  Future<void> save(GoalReminder goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabled, goal.enabled);
    await prefs.setInt(_hour, goal.hour);
    await prefs.setInt(_minute, goal.minute);
    await prefs.setString(_text, goal.text);
  }
}
