import '../../core/task.dart';
import 'upload_result.dart';

/// Sends task changes to DeskPlan. The real HTTPS version comes later;
/// tests use a fake. Implementations must not throw for network problems:
/// return [Unreachable] or [RetryLater] instead.
abstract class TaskUploader {
  /// `PUT /v1/items/{id}`
  Future<UploadResult> save(Task task);

  /// `DELETE /v1/items/{id}`
  Future<UploadResult> delete(String taskId);
}
