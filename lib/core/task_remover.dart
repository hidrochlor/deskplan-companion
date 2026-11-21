import 'repeats.dart';
import 'task.dart';
import 'task_repository.dart';
import 'task_tree.dart';

/// Deletes a task together with everything inside it, steps first.
///
/// DeskPlan keeps an assignment that still has steps, so the phone has to
/// queue the steps' deletes before the assignment's. [repository] should be
/// the one that queues changes for DeskPlan.
class TaskRemover {
  final TaskRepository _repository;

  TaskRemover(this._repository);

  /// How many steps and notes go with [task] (0 for a plain task).
  Future<int> countInside(Task task) async {
    final tree = TaskTree(await _repository.all());
    return tree.withDescendantsChildrenFirst(task).length - 1;
  }

  /// A repeating task goes with all its occurrences: deleting only the
  /// latest would have the one before it make it again (auto-advance).
  Future<void> remove(Task task) async {
    final all = await _repository.all();
    final tree = TaskTree(all);
    final series = Repeats.seriesOf(
      all,
    ).where((s) => s.contains(task.id)).firstOrNull;
    for (final member in series?.members ?? [task]) {
      for (final t in tree.withDescendantsChildrenFirst(member)) {
        await _repository.delete(t.id);
      }
    }
  }
}
