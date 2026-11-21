import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The three Android settings that decide whether a reminder shows on time.
/// Each can be checked and then asked for (which opens Android's own screen).
class ReminderPermissions {
  final FlutterLocalNotificationsPlugin _plugin;

  ReminderPermissions(this._plugin);

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Android 13+ asks before an app may show notifications at all.
  Future<bool> notificationsAllowed() async =>
      await _android?.areNotificationsEnabled() ?? false;

  Future<bool> requestNotifications() async =>
      await _android?.requestNotificationsPermission() ?? false;

  /// Android 12+ lets the user forbid exact alarms. Without them a reminder
  /// may be a few minutes late, but it still comes.
  Future<bool> exactAlarmsAllowed() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  Future<void> requestExactAlarms() async =>
      _android?.requestExactAlarmsPermission();

  /// Battery optimisation can delay or drop reminders on some phones
  /// (Samsung especially). This opens the list where the user picks
  /// "Unrestricted" for this app. It can't be read back, so there is no
  /// "is it on" check.
  Future<void> openBatterySettings() => const AndroidIntent(
    action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
  ).launch();
}
