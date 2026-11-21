import '../connection/pc_info.dart';
import '../queue/backoff.dart';
import '../queue/sync_report.dart';
import '../upload/upload_result.dart';
import 'file_uploader.dart';
import 'local_file_store.dart';
import 'queued_upload.dart';
import 'upload_queue.dart';

/// Sends the files that are due, oldest first, and records what happened in
/// the [SyncReport]. The file twin of the task QueueProcessor.
class UploadProcessor {
  final UploadQueue _queue;
  final FileUploader _uploader;
  final LocalFileStore _files;
  final DateTime Function() _now;

  UploadProcessor({
    required this._queue,
    required this._uploader,
    required this._files,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// [pc] is what DeskPlan just said about itself. A file queued before it was
  /// known (for example while the phone was not paired) may be a type DeskPlan
  /// refuses. DeskPlan hangs up on those before reading them, so the phone
  /// could never read the reason: such files are failed here instead of sent.
  ///
  /// Stops early (and fills in the report) when DeskPlan cannot be reached,
  /// because the other files would fail the same way.
  Future<void> run(SyncReport report, {PcInfo? pc}) async {
    for (final file in await _queue.due(_now())) {
      if (pc != null && !pc.accepts(file.displayName)) {
        await _queue.markFailed(file.uploadId, _notAccepted);
        report.rejections.add(
          'DeskPlan refused "${file.displayName}": $_notAccepted',
        );
        continue;
      }
      if (!await _process(file, report)) return;
    }
  }

  static const _notAccepted = 'DeskPlan only takes documents, images and links';

  /// Returns false when the run should stop.
  Future<bool> _process(QueuedUpload file, SyncReport report) async {
    final result = await _uploader.upload(file);
    switch (result) {
      case Confirmed():
        await _queue.markSent(file.uploadId, _now());
        await _deleteCopy(file);
        report.filesSent++;
        return true;
      case Rejected(:final reason):
        await _queue.markFailed(file.uploadId, reason);
        report.rejections.add(
          'DeskPlan refused "${file.displayName}": $reason',
        );
        return true;
      case RetryLater(:final reason, :final maxAttempts):
        if (maxAttempts != null && file.attempts + 1 >= maxAttempts) {
          await _queue.markFailed(file.uploadId, reason);
          report.rejections.add(
            'Could not send "${file.displayName}": $reason',
          );
        } else {
          await _queue.reschedule(
            file.uploadId,
            nextAttemptAt: _now().add(Backoff.delayFor(file.attempts + 1)),
            error: reason,
          );
          report.retryLater++;
        }
        return true;
      case Unreachable(:final reason, :final cause, :final retrySoon):
        report.unreachableReason = reason;
        report.unreachableCause = cause;
        report.retrySoon = retrySoon;
        return false;
    }
  }

  Future<void> _deleteCopy(QueuedUpload file) async {
    try {
      await _files.delete(file.localPath);
    } catch (_) {
      // A leftover copy wastes space but loses nothing.
    }
  }
}
