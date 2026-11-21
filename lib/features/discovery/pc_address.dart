/// Where to try to reach the PC: an address and a port.
class PcAddress {
  final String host;
  final int port;

  const PcAddress(this.host, this.port);

  /// Reads what the user typed: `192.168.1.5`, `192.168.1.5:47801` or a name
  /// like `my-pc.local`. Without a port, [defaultPort] is used. Throws
  /// [FormatException] with a plain message when it is not usable.
  factory PcAddress.parse(String text, {required int defaultPort}) {
    var value = text.trim();
    if (value.isEmpty) throw const FormatException('Enter an address');
    value = value.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    value = value.replaceFirst(RegExp(r'/+$'), '');

    var host = value;
    var port = defaultPort;
    final colon = value.lastIndexOf(':');
    // A colon with only digits after it is a port (IPv6 is not supported).
    if (colon > 0 && RegExp(r'^\d+$').hasMatch(value.substring(colon + 1))) {
      host = value.substring(0, colon);
      port = int.parse(value.substring(colon + 1));
    }
    if (port < 1 || port > 65535) {
      throw const FormatException('The port must be between 1 and 65535');
    }
    final valid = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$');
    if (!valid.hasMatch(host)) {
      throw const FormatException(
        'Enter an address like 192.168.1.5 or 192.168.1.5:47801',
      );
    }
    return PcAddress(host, port);
  }

  @override
  bool operator ==(Object other) =>
      other is PcAddress && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => '$host:$port';
}
