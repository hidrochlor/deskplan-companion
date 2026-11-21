/// Keeps the phone syncing with DeskPlan when the app is closed.
abstract class BackgroundSync {
  /// Sets up the regular check (about every 15 minutes, when there is a
  /// network). Safe to call every time the app opens.
  Future<void> start();

  /// Asks for another try soon: when the phone is next on Wi-Fi, but not
  /// sooner than a few minutes from now. Called when something is still
  /// waiting to be sent.
  Future<void> requestSoon();
}

/// Does nothing. Used where background work is not wanted (tests, and the
/// background worker itself, which must not schedule more work from inside).
class NoBackgroundSync implements BackgroundSync {
  const NoBackgroundSync();

  @override
  Future<void> start() async {}

  @override
  Future<void> requestSoon() async {}
}
