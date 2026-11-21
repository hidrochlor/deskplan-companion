import '../upload/upload_result.dart';
import 'queued_upload.dart';

/// Sends one queued file to DeskPlan. Implementations must not throw for
/// network problems: return [Unreachable] or [RetryLater] instead.
abstract class FileUploader {
  /// `PUT /v1/received-files/{uploadId}`
  Future<UploadResult> upload(QueuedUpload file);
}
