import 'package:deskplan_companion/features/files/file_uploader.dart';
import 'package:deskplan_companion/features/files/local_file_store.dart';
import 'package:deskplan_companion/features/files/queued_upload.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';

/// Records which files were sent and answers from [next] (default: Confirmed).
class FakeFileUploader implements FileUploader {
  final List<String> sent = [];
  UploadResult Function(QueuedUpload file) next = (_) => const Confirmed();

  @override
  Future<UploadResult> upload(QueuedUpload file) async {
    sent.add(file.uploadId);
    return next(file);
  }
}

/// Keeps track of stored copies without touching the disk.
class FakeLocalFileStore implements LocalFileStore {
  final List<String> deleted = [];

  @override
  Future<String> adopt(String sourcePath, String uploadId) async => sourcePath;

  @override
  Future<String> writeText(String uploadId, String content) async =>
      'text-$uploadId';

  @override
  Future<void> delete(String path) async => deleted.add(path);
}
