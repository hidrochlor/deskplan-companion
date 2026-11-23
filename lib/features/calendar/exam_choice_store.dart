import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which exam date the user registered for, per course (course
/// key → event id; see ExamDates). Kept on this phone only: the feed and
/// DeskPlan do not know it. Readable from the background worker too, so
/// exam reminders can skip the other dates.
class ExamChoiceStore {
  static const _key = 'exams.registered';

  const ExamChoiceStore();

  Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in map.entries)
          if (key is String && value is String) key: value,
      };
    } on FormatException {
      return {};
    }
  }

  /// Marks [eventId] as the date registered for in [course], or clears the
  /// course's mark when [eventId] is null.
  Future<void> choose(String course, String? eventId) async {
    final all = await load();
    if (eventId == null) {
      all.remove(course);
    } else {
      all[course] = eventId;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }
}
