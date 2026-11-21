import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../discovery/discovery.dart';
import '../discovery/pc_address.dart';
import '../pairing/pairing_data.dart';
import '../pairing/pairing_store.dart';
import '../upload/device_name_provider.dart';
import '../upload/pinned_http_client.dart';
import 'client_reply.dart';
import 'unreachable_cause.dart';

/// The one place that talks HTTPS to DeskPlan: loads the pairing, finds the
/// PC, pins its certificate, adds the token and `X-Device-Name`, and tries
/// each known address. Everything else (tasks, ping, files) builds on it.
///
/// Never throws for network trouble: returns a [NoReply] instead.
class DeskPlanClient {
  final PairingStore _store;
  final Discovery _discovery;
  final DeviceNameProvider? _deviceName;
  final Duration _requestTimeout;

  // protocol.md section 2: a pinning failure is shown, never ignored.
  static const _identityChanged =
      'The PC\'s identity changed (or this is not your PC). Pair again';

  DeskPlanClient(
    this._store,
    this._discovery, {
    this._deviceName,
    this._requestTimeout = const Duration(seconds: 15),
  });

  /// Sends one request. [path] is the URL path segments, for example
  /// `['v1', 'items', id]`. [query] values are URL-encoded for you.
  ///
  /// Send a small JSON body with [jsonBody], or a big one (a file) with
  /// [bodyStream] and its exact [contentLength]. [bodyStream] is a function
  /// because each address that is tried needs a fresh stream. [timeout]
  /// replaces the default for the whole request, which a big file needs.
  Future<ClientReply> send(
    String method,
    List<String> path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Map<String, Object?>? jsonBody,
    Stream<List<int>> Function()? bodyStream,
    int? contentLength,
    Duration? timeout,
  }) async {
    final pairing = await _store.load();
    if (pairing == null) {
      return const NoReply(
        UnreachableCause.notPaired,
        'Not paired with DeskPlan',
      );
    }
    final deviceName = await _deviceName?.name();
    final addresses = await _discovery.candidates(pairing);
    if (addresses.isEmpty) {
      return const NoReply(
        UnreachableCause.noAddress,
        'No address known for DeskPlan',
      );
    }

    // Try each address; the first one that answers decides the result.
    var failure = const NoReply(
      UnreachableCause.cannotReach,
      'Can\'t reach DeskPlan',
    );
    for (final address in addresses) {
      try {
        return await _request(
          pairing,
          address,
          method,
          path,
          query,
          headers,
          jsonBody,
          bodyStream,
          contentLength,
          deviceName,
        ).timeout(timeout ?? _requestTimeout);
      } on HandshakeException {
        failure = const NoReply(
          UnreachableCause.identityChanged,
          _identityChanged,
        );
      } on TlsException {
        failure = const NoReply(
          UnreachableCause.identityChanged,
          _identityChanged,
        );
      } on TimeoutException {
        failure = NoReply(
          UnreachableCause.cannotReach,
          'DeskPlan did not answer at ${address.host}',
        );
      } on SocketException {
        failure = NoReply(
          UnreachableCause.cannotReach,
          'Can\'t reach DeskPlan at ${address.host}',
        );
      } on HttpException {
        failure = NoReply(
          UnreachableCause.cannotReach,
          'Connection to DeskPlan at ${address.host} was interrupted',
        );
      }
    }
    return failure;
  }

  Future<Reply> _request(
    PairingData pairing,
    PcAddress address,
    String method,
    List<String> path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Map<String, Object?>? jsonBody,
    Stream<List<int>> Function()? bodyStream,
    int? contentLength,
    String? deviceName,
  ) async {
    final client = PinnedHttpClient.create(pairing.fingerprint);
    try {
      final uri = Uri(
        scheme: 'https',
        host: address.host,
        port: address.port,
        pathSegments: path,
        queryParameters: query,
      );
      final request = await client.openUrl(method, uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${pairing.token}',
      );
      if (deviceName != null && deviceName.isNotEmpty) {
        // URL-encoded, and DeskPlan keeps at most 80 characters.
        final short = deviceName.length > 80
            ? deviceName.substring(0, 80)
            : deviceName;
        request.headers.set('X-Device-Name', Uri.encodeComponent(short));
      }
      headers?.forEach(request.headers.set);
      if (jsonBody != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(jsonBody)));
      } else if (bodyStream != null) {
        // An exact Content-Length is required: DeskPlan takes no chunked
        // uploads (protocol.md section 10).
        request.contentLength = contentLength!;
        await request.addStream(bodyStream());
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return Reply(response.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }

  /// The `error` code in an error body such as `{"error":"bad-token"}`.
  static String? errorCode(String body) {
    try {
      final json = jsonDecode(body);
      final error = json is Map ? json['error'] : null;
      return error is String && error.isNotEmpty ? error : null;
    } on FormatException {
      return null;
    }
  }
}
