import 'upload_status.dart';

/// One file waiting to go to DeskPlan (or already gone, or refused).
class QueuedUpload {
  /// A UUID made when the file was queued. DeskPlan uses it to recognise a
  /// retry, so one file never arrives twice. Never reuse it for another file.
  final String uploadId;

  /// The app's own copy of the file (the shared original may disappear).
  final String localPath;

  /// The name to send, as edited by the user.
  final String displayName;

  /// `received-files` or `folder:<id>` (sent as `X-Dest-Id`).
  final String destId;

  final int sizeBytes;
  final UploadStatus status;
  final int attempts;
  final DateTime nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? sentAt;

  QueuedUpload({
    required this.uploadId,
    required this.localPath,
    required this.displayName,
    required this.destId,
    required this.sizeBytes,
    this.status = UploadStatus.waiting,
    this.attempts = 0,
    required DateTime nextAttemptAt,
    this.lastError,
    required DateTime createdAt,
    DateTime? sentAt,
  }) : nextAttemptAt = nextAttemptAt.toUtc(),
       createdAt = createdAt.toUtc(),
       sentAt = sentAt?.toUtc();

  Map<String, Object?> toMap() => {
    'uploadId': uploadId,
    'localPath': localPath,
    'displayName': displayName,
    'destId': destId,
    'sizeBytes': sizeBytes,
    'status': status.name,
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt.millisecondsSinceEpoch,
    'lastError': lastError,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'sentAt': sentAt?.millisecondsSinceEpoch,
  };

  factory QueuedUpload.fromMap(Map<String, Object?> m) {
    DateTime time(Object? ms) =>
        DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
    return QueuedUpload(
      uploadId: m['uploadId'] as String,
      localPath: m['localPath'] as String,
      displayName: m['displayName'] as String,
      destId: m['destId'] as String,
      sizeBytes: m['sizeBytes'] as int,
      status: UploadStatus.values.byName(m['status'] as String),
      attempts: m['attempts'] as int,
      nextAttemptAt: time(m['nextAttemptAt']),
      lastError: m['lastError'] as String?,
      createdAt: time(m['createdAt']),
      sentAt: m['sentAt'] == null ? null : time(m['sentAt']),
    );
  }
}
