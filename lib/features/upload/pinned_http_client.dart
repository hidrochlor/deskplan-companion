import 'dart:io';

import 'package:crypto/crypto.dart';

/// Builds an HTTPS client that trusts exactly one certificate: the one whose
/// SHA-256 fingerprint was in the pairing QR code ("certificate pinning").
///
/// DeskPlan's certificate is self-signed, so no public authority vouches for
/// it. We start with an empty list of trusted authorities, which makes every
/// certificate "bad" in the normal sense, then accept only the pinned one.
/// If the fingerprint differs, the connection fails during the handshake,
/// before any request (and so before the token) is sent.
class PinnedHttpClient {
  static HttpClient create(
    String fingerprint, {
    Duration connectionTimeout = const Duration(seconds: 5),
  }) {
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = connectionTimeout;
    client.badCertificateCallback = (cert, host, port) =>
        sha256.convert(cert.der).toString() == fingerprint.toLowerCase();
    return client;
  }
}
