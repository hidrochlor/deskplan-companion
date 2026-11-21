import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// One request the fake server received.
class SeenRequest {
  final String method;
  final String path;
  final String? authorization;
  final String? contentType;
  final String body;
  final String? deviceNameHeader;

  /// Every header, with lowercase names.
  final Map<String, String> headers;

  /// The URL's query, decoded (`since`, `kinds`...).
  final Map<String, String> query;

  SeenRequest(
    this.method,
    this.path,
    this.authorization,
    this.contentType,
    this.body,
    this.deviceNameHeader, [
    this.headers = const {},
    this.query = const {},
  ]);

  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

/// A stand-in for DeskPlan's listener: real HTTPS on 127.0.0.1 with a
/// self-signed certificate from test/fixtures. Tests set [status] and [reply]
/// to make it answer however they need.
class FakeDeskPlanServer {
  final HttpServer _server;
  final List<SeenRequest> requests = [];

  int status = 200;

  /// The JSON body to answer with. `null` answers with an empty body.
  Object? reply;

  FakeDeskPlanServer._(this._server) {
    _server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add(
        SeenRequest(
          request.method,
          request.uri.path,
          request.headers.value(HttpHeaders.authorizationHeader),
          request.headers.contentType?.mimeType,
          body,
          request.headers.value('x-device-name'),
          {
            for (final name in _names(request.headers))
              name: request.headers.value(name)!,
          },
          request.uri.queryParameters,
        ),
      );
      request.response.statusCode = status;
      if (reply != null) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(reply));
      }
      await request.response.close();
    });
  }

  static List<String> _names(HttpHeaders headers) {
    final names = <String>[];
    headers.forEach((name, _) => names.add(name));
    return names;
  }

  /// [certName] picks the fixture files: `test` or `other`.
  static Future<FakeDeskPlanServer> start({String certName = 'test'}) async {
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/${certName}_cert.pem')
      ..usePrivateKey('test/fixtures/${certName}_key.pem');
    final server = await HttpServer.bindSecure('127.0.0.1', 0, context);
    return FakeDeskPlanServer._(server);
  }

  int get port => _server.port;

  Future<void> stop() => _server.close(force: true);

  /// SHA-256 of a fixture certificate, the way DeskPlan would put it in the QR.
  static String fingerprintOf(String certName) {
    final pem = File('test/fixtures/${certName}_cert.pem').readAsStringSync();
    final base64Body = pem
        .split('\n')
        .map((l) => l.trim()) // files may have Windows line endings
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join();
    return sha256.convert(base64.decode(base64Body)).toString();
  }
}
