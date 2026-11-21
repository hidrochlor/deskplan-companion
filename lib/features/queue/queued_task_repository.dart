import '../../core/task.dart';
import '../../core/app_database.dart';
import '../../core/task_repository.dart';
import '../../core/task_storage.dart';
import 'sqlite_action_queue.dart';
import 'sync_action.dart';

/// The repository the screens use. Every save or delete is stored normally
/// and also added to the action queue, so it will reach DeskPlan later.
///
/// Both writes happen in one database transaction: either the task change
/// and its queued action are both saved, or neither is. A crash in between
/// can't leave a change that never gets synced.
class QueuedTaskRepository implements TaskRepository {
  final AppDatabase _database;
  final TaskStorage _tasks;
  final SqliteActionQueue _queue;

  QueuedTaskRepository(this._database, this._tasks, this._queue);

  @override
  Future<List<Task>> all() => _tasks.all();

  @override
  Future<Task?> get(String id) => _tasks.get(id);

  @override
  Future<void> save(Task task) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await _tasks.saveIn(txn, task);
      await _queue.enqueueIn(txn, task.id, ActionType.save);
    });
  }

  @override
  Future<void> delete(String id) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await _tasks.deleteIn(txn, id);
      await _queue.enqueueIn(txn, id, ActionType.delete);
    });
  }
}
