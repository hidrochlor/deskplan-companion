import 'queued_upload.dart';

/// The waiting list of files. Survives app restarts.
abstract class UploadQueue {
  Future<void> add(QueuedUpload upload);

  /// Waiting files whose retry time has come, oldest first.
  Future<List<QueuedUpload>> due(DateTime now);

  /// Everything, newest first: waiting, failed and recently sent.
  Future<List<QueuedUpload>> all();

  /// DeskPlan has the file.
  Future<void> markSent(String uploadId, DateTime at);

  /// Give up on this file (refused, or out of tries), keeping [reason].
  Future<void> markFailed(String uploadId, String reason);

  /// Count the failed try, remember why, and try again at [nextAttemptAt].
  Future<void> reschedule(
    String uploadId, {
    required DateTime nextAttemptAt,
    required String error,
  });

  /// Put a failed file back in the queue, due now, with a fresh try count.
  Future<void> retry(String uploadId, DateTime now);

  /// Forget the file (the caller deletes the stored copy).
  Future<void> remove(String uploadId);

  /// Removes every sent file from the history. Waiting and failed files stay.
  Future<void> clearSent();

  Future<QueuedUpload?> find(String uploadId);

  /// How many files are waiting to be sent.
  Future<int> waitingCount();
}
