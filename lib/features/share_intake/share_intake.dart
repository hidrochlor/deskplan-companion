import 'shared_item.dart';

/// Receives what other apps share with this one (Android's share sheet).
/// The app depends on this interface, so tests can use a fake.
abstract class ShareIntake {
  /// What the app was started with, if it was started by a share. Returns it
  /// once: a second call gives an empty list.
  Future<List<SharedItem>> initial();

  /// Shares that arrive while the app is already open.
  Stream<List<SharedItem>> get incoming;
}
