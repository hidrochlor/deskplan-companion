import 'found_service.dart';

/// Looks for `_deskplan._tcp` services on the local network. Behind an
/// interface so the logic that uses it can be tested without a network.
abstract class ServiceFinder {
  /// Searches until a service for which [accept] is true appears, or until
  /// [timeout]. Returns the accepted services (empty if none showed up).
  Future<List<FoundService>> find({
    required bool Function(FoundService) accept,
    required Duration timeout,
  });
}
