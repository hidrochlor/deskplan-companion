import 'package:workmanager/workmanager.dart';

import 'background_sync.dart';
import 'background_sync_entry.dart';

/// [BackgroundSync] on Android's WorkManager, which runs the work even when
/// the app is closed and survives a restart of the phone.
class WorkmanagerBackgroundSync implements BackgroundSync {
  static const taskName = 'deskplan-sync';
  static const _periodicId = 'deskplan-sync-periodic';
  static const _onWifiId = 'deskplan-sync-on-wifi';

  /// Android does not allow periodic work more often than this.
  static const _every = Duration(minutes: 15);

  /// How long to wait before a Wi-Fi retry, so a PC that is simply switched
  /// off is not tried again every few seconds.
  static const _retryAfter = Duration(minutes: 5);

  final Workmanager _workmanager = Workmanager();

  @override
  Future<void> start() async {
    await _workmanager.initialize(backgroundSyncDispatcher);
    await _workmanager.registerPeriodicTask(
      _periodicId,
      taskName,
      frequency: _every,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  @override
  Future<void> requestSoon() => _workmanager.registerOneOffTask(
    _onWifiId,
    taskName,
    initialDelay: _retryAfter,
    // "Unmetered" is, in practice, Wi-Fi: it runs as soon as the phone joins
    // one (after the delay), even if the app has been closed.
    constraints: Constraints(networkType: NetworkType.unmetered),
    // A request already waiting keeps its place instead of starting over.
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}
