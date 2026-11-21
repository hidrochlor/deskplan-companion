import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_options.dart';

/// Remembers the reminder options between app runs. The background worker
/// reads them too, so a task it changes gets the same reminders.
class ReminderOptionsStore {
  static const _warnings = 'reminders.dueWarnings';
  static const _exams = 'reminders.exams';

  /// Before several warnings could be on: one choice of off, 1 hour before,
  /// 1 day before, or both. Read once, when nothing newer is saved.
  static const _oldWarning = 'reminders.dueWarning';

  Future<ReminderOptions> load() async {
    final prefs = await SharedPreferences.getInstance();
    const fallback = ReminderOptions();
    final saved = prefs.getStringList(_warnings);
    return ReminderOptions(
      warnings: saved != null
          ? {
              for (final w in DueWarning.values)
                if (saved.contains(w.name)) w,
            }
          : _fromOld(prefs.getString(_oldWarning)),
      exams: prefs.getBool(_exams) ?? fallback.exams,
    );
  }

  static Set<DueWarning> _fromOld(String? old) => switch (old) {
    'hourBefore' => {DueWarning.hour1},
    'dayBefore' => {DueWarning.day1},
    'both' => {DueWarning.day1, DueWarning.hour1},
    _ => const {},
  };

  Future<void> save(ReminderOptions options) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_warnings, [
      for (final w in options.warnings) w.name,
    ]);
    await prefs.setBool(_exams, options.exams);
  }
}
