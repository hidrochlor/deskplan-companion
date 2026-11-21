import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app_services.dart';
import 'notification_target.dart';
import 'push_action.dart';
import 'pushed_items.dart';

/// Where a reminder's "Start 30 min later" / "Extend 1 hr" button runs.
/// Android starts it in a fresh Dart isolate (the app may be closed), so it
/// builds its own copy of the services, saves the pushed item (queued for
/// DeskPlan, its reminders set again), tells the open app, and syncs.
///
/// It must be a top-level function, kept by the `entry-point` marker.
@pragma('vm:entry-point')
Future<void> notificationActionInBackground(NotificationResponse r) async {
  final action = PushAction.parse(r.actionId);
  final target = NotificationTarget.parse(r.payload);
  if (action == null || target is! ItemTarget) return;
  try {
    final services = await AppServices.create(inBackground: true);
    if (!await services.pushItem(target.id, action)) return;
    PushedItems.announce();
    await services.sync.syncNow();
  } catch (_) {
    // Nothing to show from here: the reminder is gone either way.
  }
}
