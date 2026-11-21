import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../connection/client_reply.dart';
import '../connection/deskplan_client.dart';
import '../upload/upload_result.dart';
import 'file_uploader.dart';
import 'queued_upload.dart';

/// Sends files to DeskPlan with `PUT /v1/received-files/{uploadId}`
/// (docs/protocol.md section 4).
class HttpsFileUploader implements FileUploader {
  /// DeskPlan refuses files over 100 MB.
  static const maxBytes = 100 * 1024 * 1024;

  /// A damaged transfer is retried once; after that the user is told.
  static const _checksumTries = 2;

  final DeskPlanClient _client;

  HttpsFileUploader(this._client);

  @override
  Future<UploadResult> upload(QueuedUpload file) async {
    final stored = File(file.localPath);
    if (!await stored.exists()) {
      return const Rejected('the saved copy of the file is gone');
    }
    final size = await stored.length();
    if (size > maxBytes) return const Rejected('it is over 100 MB');

    // DeskPlan checks this against what it received, before it says "got it".
    final hash = (await sha256.bind(stored.openRead()).first).toString();

    final reply = await _client.send(
      'PUT',
      ['v1', 'received-files', file.uploadId],
      headers: {
        'X-File-Name': Uri.encodeComponent(file.displayName),
        'X-File-Sha256': hash,
        'X-Dest-Id': file.destId,
      },
      bodyStream: stored.openRead,
      contentLength: size,
      // At least a minute, plus time for a slow link (about 100 KB a second).
      timeout: Duration(seconds: 60 + size ~/ 100000),
    );
    return _interpret(reply, hash);
  }

  UploadResult _interpret(ClientReply reply, String sentHash) {
    if (reply is NoReply) {
      return Unreachable(
        reply.message,
        cause: reply.cause,
        retrySoon: reply.retrySoon,
      );
    }
    final Reply(:status, :body) = reply as Reply;
    final code = DeskPlanClient.errorCode(body);

    final blocked = NoReply.fromStatus(status, code);
    if (blocked != null) {
      return Unreachable(
        blocked.message,
        cause: blocked.cause,
        retrySoon: blocked.retrySoon,
      );
    }
    switch (status) {
      case 200 || 201:
        return _confirmed(body, sentHash);
      case 413:
        return const Rejected('it is over 100 MB');
      case 422:
        return switch (code) {
          'unsupported-type' => const Rejected(
            'DeskPlan only takes documents, images and links',
          ),
          'unknown-destination' => const Rejected(
            'that folder no longer exists on your PC. Delete this and '
            'share it again',
          ),
          'checksum-mismatch' => const RetryLater(
            'the file was damaged on the way',
            maxAttempts: _checksumTries,
          ),
          _ => Rejected('DeskPlan did not accept it (${code ?? 'invalid'})'),
        };
      case 404 || 405:
        return Rejected('the app and DeskPlan disagree ($status, a bug)');
      case 503:
        return const RetryLater('DeskPlan is busy or starting');
      default:
        return RetryLater('Unexpected reply from DeskPlan ($status)');
    }
  }

  /// Only a reply that echoes the same SHA-256 proves the file arrived intact.
  UploadResult _confirmed(String body, String sentHash) {
    try {
      final json = jsonDecode(body);
      final echoed = json is Map ? json['sha256'] : null;
      if (echoed is String && echoed.toLowerCase() == sentHash) {
        return const Confirmed();
      }
      return const RetryLater(
        'DeskPlan\'s reply did not match the file',
        maxAttempts: _checksumTries,
      );
    } on FormatException {
      return const RetryLater('DeskPlan sent an unreadable reply');
    }
  }
}
