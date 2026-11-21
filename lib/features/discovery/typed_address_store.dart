/// Remembers an address the user typed by hand, the last way of finding the
/// PC when mDNS is blocked and the QR hint is out of date.
abstract class TypedAddressStore {
  /// What the user typed (for example `192.168.1.5:47801`), or null.
  Future<String?> load();
  Future<void> save(String text);
  Future<void> clear();
}
