import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/task.dart';
import 'goal_reminder.dart';
import 'notification_target.dart';
import 'notification_taps.dart';
import 'planned_reminder.dart';
import 'push_action.dart';
import 'reminder_ids.dart';
import 'reminder_kind.dart';
import 'reminder_options.dart';
import 'reminder_options_store.dart';
import 'reminder_planner.dart';
import 'reminder_scheduler.dart';

/// [ReminderScheduler] built on flutter_local_notifications. Android only.
/// Call [init] once before anything else.
class LocalNotificationScheduler implements ReminderScheduler {
  /// The task channel, with the reminder's buttons (none for most).
  /// [label] ("Task", "Assignment") shows after the app name.
  static AndroidNotificationDetails _taskChannel(
    List<PushAction> actions,
    String label,
  ) => AndroidNotificationDetails(
    'task_reminders',
    'Task reminders',
    channelDescription: 'When a task starts or is due',
    subText: label,
    importance: Importance.high,
    priority: Priority.high,
    actions: [
      for (final a in actions) AndroidNotificationAction(a.id, a.label),
    ],
  );
  static const _goalChannel = AndroidNotificationDetails(
    'daily_goal',
    'Daily goal',
    channelDescription: 'Your personal goal reminder, once a day',
    importance: Importance.defaultImportance,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final ReminderOptionsStore _options;
  final DateTime Function() _now;

  LocalNotificationScheduler(
    this._plugin,
    this._options, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// [taps] hears every tapped notification, so the app can open what it is
  /// about, including the one that started the app. [onAction] runs a
  /// reminder's button (it pushes the item back) in a background isolate: a
  /// top-level function marked `@pragma('vm:entry-point')`.
  Future<void> init({
    NotificationTaps? taps,
    DidReceiveBackgroundNotificationResponseCallback? onAction,
  }) async {
    // Times for tasks are exact moments, but the daily goal repeats at a wall
    // clock time, so the plugin needs to know the phone's time zone.
    // If the phone's zone can't be read or is unknown, task reminders still
    // work (they are exact moments); only the daily goal would be off. So a
    // failure here must never stop the plugin from starting below.
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(_zoneFromOffset(DateTime.now().timeZoneOffset));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) => taps?.tapped(r.payload),
      onDidReceiveBackgroundNotificationResponse: onAction,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      taps?.launchedBy(launch!.notificationResponse?.payload);
    }
  }

  /// A fixed-offset zone ("Etc/GMT-1" is UTC+1: the sign is reversed),
  /// or UTC when no whole-hour one matches.
  static tz.Location _zoneFromOffset(Duration offset) {
    if (offset.inMinutes % 60 != 0 || offset.inHours == 0) return tz.UTC;
    final h = -offset.inHours;
    try {
      return tz.getLocation('Etc/GMT${h > 0 ? '+' : ''}$h');
    } catch (_) {
      return tz.UTC;
    }
  }

  /// Exact if Android allows it, otherwise "about on time": still delivered
  /// while the phone sleeps, but Android may shift it by a few minutes.
  Future<AndroidScheduleMode> _mode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> scheduleTask(Task task) async =>
      _schedule(task, (await _options.load()).warnings, await _mode());

  Future<void> _schedule(
    Task task,
    Set<DueWarning> warnings,
    AndroidScheduleMode mode,
  ) async {
    await cancelTask(task.id);
    for (final r in ReminderPlanner.forTask(task, _now(), warnings: warnings)) {
      await _show(r, mode);
    }
  }

  Future<void> _show(PlannedReminder r, AndroidScheduleMode mode) =>
      _plugin.zonedSchedule(
        id: ReminderIds.forTask(r.taskId, r.kind),
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: NotificationDetails(
          android: _taskChannel(r.actions, r.label),
        ),
        androidScheduleMode: mode,
        payload: NotificationTarget.forItem(r.taskId),
      );

  @override
  Future<void> cancelTask(String taskId) async {
    for (final kind in ReminderKind.values) {
      await _plugin.cancel(id: ReminderIds.forTask(taskId, kind));
    }
  }

  @override
  Future<void> rescheduleAll(List<Task> tasks) async {
    final warnings = (await _options.load()).warnings;
    final mode = await _mode();
    for (final task in tasks) {
      await _schedule(task, warnings, mode);
    }
  }

  @override
  Future<void> setDailyGoal(GoalReminder goal) async {
    await _plugin.cancel(id: ReminderIds.dailyGoal);
    if (!goal.enabled) return;

    final now = tz.TZDateTime.from(_now(), tz.local);
    var first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      goal.hour,
      goal.minute,
    );
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: ReminderIds.dailyGoal,
      title: 'Your goal for today',
      body: goal.text.trim().isEmpty ? GoalReminder.defaultText : goal.text,
      scheduledDate: first,
      notificationDetails: const NotificationDetails(android: _goalChannel),
      androidScheduleMode: await _mode(),
      // Repeat every day at this hour and minute.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
