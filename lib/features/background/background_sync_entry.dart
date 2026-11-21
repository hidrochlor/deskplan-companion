import 'package:workmanager/workmanager.dart';

import '../../app_services.dart';

/// Where the background worker starts. Android calls this in a fresh Dart
/// isolate (the app itself may not be running), so it builds its own copy of
/// the services, syncs once, and returns.
///
/// It must be a top-level function, kept by the `entry-point` marker.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final services = await AppServices.create(inBackground: true);
      await services.sync.syncNow();
      return true;
    } catch (_) {
      return false; // WorkManager will try again later
    }
  });
}
