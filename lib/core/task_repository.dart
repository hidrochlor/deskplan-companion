import 'task.dart';

/// What the rest of the app needs from task storage.
abstract class TaskRepository {
  Future<List<Task>> all();
  Future<Task?> get(String id);

  /// Insert or replace by id.
  Future<void> save(Task task);
  Future<void> delete(String id);
}
