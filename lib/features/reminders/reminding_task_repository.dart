import '../../core/task.dart';
import '../../core/task_repository.dart';
import 'reminder_scheduler.dart';

/// Wraps a [TaskRepository] so every save or delete also updates that task's
/// reminders. Wrap both the screens' repository and the sync one, so a task
/// that DeskPlan changed gets its reminders fixed too.
///
/// A reminder problem (say, notifications are blocked) never stops a task
/// from being saved: the save has already happened.
class RemindingTaskRepository implements TaskRepository {
  final TaskRepository _inner;
  final ReminderScheduler _reminders;

  RemindingTaskRepository(this._inner, this._reminders);

  @override
  Future<List<Task>> all() => _inner.all();

  @override
  Future<Task?> get(String id) => _inner.get(id);

  @override
  Future<void> save(Task task) async {
    await _inner.save(task);
    try {
      await _reminders.scheduleTask(task);
    } catch (_) {}
  }

  @override
  Future<void> delete(String id) async {
    await _inner.delete(id);
    try {
      await _reminders.cancelTask(id);
    } catch (_) {}
  }
}
