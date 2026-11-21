import 'dart:async';

import 'notification_target.dart';

/// Tapped notifications, for the screen to open what each is about. A tap
/// that started the app (before any screen listened) waits in [takeLaunch].
class NotificationTaps {
  final _taps = StreamController<NotificationTarget>.broadcast();
  NotificationTarget? _launch;

  /// Taps while the app is running (in front or in the background).
  Stream<NotificationTarget> get stream => _taps.stream;

  /// Called by the notification plugin with the tapped one's payload.
  void tapped(String? payload) {
    final target = NotificationTarget.parse(payload);
    if (target != null) _taps.add(target);
  }

  /// The app was started by tapping a notification with [payload].
  void launchedBy(String? payload) =>
      _launch = NotificationTarget.parse(payload);

  /// The tap that started the app, once: null afterwards.
  NotificationTarget? takeLaunch() {
    final target = _launch;
    _launch = null;
    return target;
  }
}
