import 'dart:convert';
import 'dart:io';

/// What the phone learns from DeskPlan's pairing QR code (protocol v1).
/// Parsing is strict: anything unexpected is rejected, because this data
/// decides which computer receives your tasks and which certificate we trust.
class PairingData {
  final String name;
  final int port;

  /// Shared secret, base64 of 32 random bytes. Sent as `Bearer <token>`.
  final String token;

  /// SHA-256 of DeskPlan's certificate, 64 lowercase hex characters.
  /// The phone only talks to a server whose certificate matches this.
  final String fingerprint;

  /// Last known IP address of the PC. Only a hint, it may be out of date.
  final String? hint;

  const PairingData({
    required this.name,
    required this.port,
    required this.token,
    required this.fingerprint,
    this.hint,
  });

  /// Reads the QR text. Throws [FormatException] with a plain message
  /// if it is not valid DeskPlan pairing data.
  factory PairingData.parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Not a DeskPlan pairing code');
    }
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Not a DeskPlan pairing code');
    }
    return PairingData._fromMap(json);
  }

  /// Reads data we saved ourselves (same rules as [parse]).
  factory PairingData.fromJson(Map<String, dynamic> json) =>
      PairingData._fromMap(json);

  Map<String, Object?> toJson() => {
    'v': 1,
    'name': name,
    'port': port,
    'token': token,
    'fp': fingerprint,
    'hint': hint,
  };

  static PairingData _fromMap(Map<String, dynamic> m) {
    if (m['v'] != 1) {
      throw const FormatException('Unsupported pairing code version');
    }

    final name = m['name'];
    if (name is! String || name.trim().isEmpty || name.length > 100) {
      throw const FormatException('Pairing code has no valid PC name');
    }

    final port = m['port'];
    if (port is! int || port < 1 || port > 65535) {
      throw const FormatException('Pairing code has an invalid port');
    }

    final token = m['token'];
    if (token is! String || !_isBase64Of32Bytes(token)) {
      throw const FormatException('Pairing code has an invalid token');
    }

    final fp = m['fp'];
    if (fp is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(fp)) {
      throw const FormatException('Pairing code has an invalid fingerprint');
    }

    final hint = m['hint'];
    if (hint != null &&
        (hint is! String || InternetAddress.tryParse(hint) == null)) {
      throw const FormatException('Pairing code has an invalid address');
    }

    return PairingData(
      name: name.trim(),
      port: port,
      token: token,
      fingerprint: fp.toLowerCase(),
      hint: hint as String?,
    );
  }

  static bool _isBase64Of32Bytes(String s) {
    try {
      return base64.decode(s).length == 32;
    } on FormatException {
      return false;
    }
  }
}
