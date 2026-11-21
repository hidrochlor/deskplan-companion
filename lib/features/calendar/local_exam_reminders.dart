import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../reminders/notification_target.dart';
import '../reminders/reminder_options_store.dart';
import 'calendar_event.dart';
import 'exam_reminder_planner.dart';
import 'exam_reminders.dart';

/// [ExamReminders] built on flutter_local_notifications. Android only. Uses
/// the plugin after `LocalNotificationScheduler.init` has set it up.
class LocalExamReminders implements ExamReminders {
  static const _channel = AndroidNotificationDetails(
    'exam_reminders',
    'Exam reminders',
    channelDescription: 'A day and an hour before an exam',
    importance: Importance.high,
    priority: Priority.high,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final ReminderOptionsStore _options;
  final DateTime Function() _now;

  LocalExamReminders(this._plugin, this._options, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> replace(
    List<CalendarEvent> before,
    List<CalendarEvent> now,
  ) async {
    for (final e in before) {
      for (final id in ExamReminderPlanner.idsOf(e)) {
        await _plugin.cancel(id: id);
      }
    }
    // Switched off in Reminders: the old ones are gone, set none.
    if (!(await _options.load()).exams) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    for (final r in ExamReminderPlanner.forEvents(now, _now())) {
      await _plugin.zonedSchedule(
        id: r.notificationId,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationTarget.forEvent(r.eventId),
      );
    }
  }
}
