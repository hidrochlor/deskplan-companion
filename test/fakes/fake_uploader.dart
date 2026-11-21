import 'package:deskplan_companion/features/upload/task_uploader.dart';
import 'package:deskplan_companion/features/upload/upload_result.dart';
import 'package:deskplan_companion/core/task.dart';

/// Records every call and answers from [next] (default: Confirmed).
class FakeUploader implements TaskUploader {
  final List<String> calls = [];
  UploadResult Function(String call) next = (_) => const Confirmed();

  @override
  Future<UploadResult> save(Task task) async {
    calls.add('save ${task.id}');
    return next('save ${task.id}');
  }

  @override
  Future<UploadResult> delete(String taskId) async {
    calls.add('delete $taskId');
    return next('delete $taskId');
  }
}
