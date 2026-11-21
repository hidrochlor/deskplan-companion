import '../../core/task_repository.dart';
import 'sync_action.dart';

/// Puts the waiting actions in the order DeskPlan needs them.
///
/// A step can only be saved once its assignment exists on DeskPlan, so saves
/// go parents first. The queue keeps only the newest action per task, so
/// editing an assignment after adding steps would otherwise move it behind
/// them. Deletes come last, in the order they were queued: the phone queues a
/// step's delete before its assignment's, and DeskPlan refuses to delete an
/// assignment that still has steps.
class ParentsFirstOrder {
  /// More levels than DeskPlan allows (folder, assignment, step), a guard
  /// against a damaged loop of parents.
  static const _maxDepth = 6;

  final TaskRepository _repository;

  ParentsFirstOrder(this._repository);

  Future<List<SyncAction>> order(List<SyncAction> actions) async {
    final saves = <(SyncAction, int)>[];
    final deletes = <SyncAction>[];
    for (final action in actions) {
      if (action.type == ActionType.save) {
        saves.add((action, await _depth(action.taskId)));
      } else {
        deletes.add(action);
      }
    }
    // Dart's sort is not stable, so the original position breaks ties.
    final position = {for (final a in actions) a.seq: actions.indexOf(a)};
    saves.sort((a, b) {
      final byDepth = a.$2.compareTo(b.$2);
      return byDepth != 0
          ? byDepth
          : position[a.$1.seq]!.compareTo(position[b.$1.seq]!);
    });
    return [...saves.map((s) => s.$1), ...deletes];
  }

  /// How many parents the task has on the phone (0 = top level of Home).
  Future<int> _depth(String taskId) async {
    var depth = 0;
    var current = await _repository.get(taskId);
    while (current?.parentId != null && depth < _maxDepth) {
      depth++;
      current = await _repository.get(current!.parentId!);
    }
    return depth;
  }
}
