/// One `_deskplan._tcp` service seen on the network.
class FoundService {
  /// IPv4 addresses of the machine announcing it.
  final List<String> addresses;
  final int port;

  /// The `id` in its TXT record: the first 8 characters of the PC's
  /// certificate fingerprint. Null if it had none.
  final String? id;

  const FoundService({required this.addresses, required this.port, this.id});
}
