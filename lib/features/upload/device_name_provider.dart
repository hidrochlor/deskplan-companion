/// The name this phone calls itself, shown by DeskPlan in its list of
/// paired phones and in Received files.
abstract class DeviceNameProvider {
  /// Null if no name could be found.
  Future<String?> name();
}
