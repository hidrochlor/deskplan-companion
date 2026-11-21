import 'dart:io';

import 'package:uuid/uuid.dart';

import 'local_file_store.dart';
import 'queued_upload.dart';
import 'upload_queue.dart';

/// Puts a file in the upload queue: gives it a fresh `uploadId`, copies it
/// into the app's own storage at once, and records it. Sending happens later.
class FileQueuer {
  final UploadQueue _queue;
  final LocalFileStore _files;
  final DateTime Function() _now;

  FileQueuer(this._queue, this._files, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Queues the file at [sourcePath], to be sent as [displayName] to [destId].
  Future<QueuedUpload> addFile({
    required String sourcePath,
    required String displayName,
    required String destId,
  }) async {
    final uploadId = const Uuid().v4();
    final stored = await _files.adopt(sourcePath, uploadId);
    return _record(uploadId, stored, displayName, destId);
  }

  /// Queues [content] (a `.url` link file) as [displayName].
  Future<QueuedUpload> addText({
    required String content,
    required String displayName,
    required String destId,
  }) async {
    final uploadId = const Uuid().v4();
    final stored = await _files.writeText(uploadId, content);
    return _record(uploadId, stored, displayName, destId);
  }

  Future<QueuedUpload> _record(
    String uploadId,
    String stored,
    String displayName,
    String destId,
  ) async {
    final now = _now();
    final upload = QueuedUpload(
      uploadId: uploadId,
      localPath: stored,
      displayName: displayName,
      destId: destId,
      sizeBytes: await File(stored).length(),
      nextAttemptAt: now,
      createdAt: now,
    );
    await _queue.add(upload);
    return upload;
  }
}
