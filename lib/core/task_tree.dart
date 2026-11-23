import 'progress.dart';
import 'task.dart';
import 'task_kind.dart';

/// Who sits inside whom, for a list of tasks: which are steps of which
/// assignment. Pure logic, no storage, so it is easy to test.
class TaskTree {
  final List<Task> _all;
  late final Map<String, Task> _byId = {for (final t in _all) t.id: t};

  TaskTree(List<Task> tasks) : _all = List.unmodifiable(tasks);

  /// True for a task that sits directly inside an assignment.
  bool isStep(Task task) =>
      task.kind == TaskKind.task &&
      task.parentId != null &&
      _byId[task.parentId]?.kind == TaskKind.assignment;

  /// The assignment [task] is a step of, or null.
  Task? parentOf(Task task) => isStep(task) ? _byId[task.parentId] : null;

  /// What the main list shows: everything that is not a step. Steps are
  /// shown inside their assignment.
  List<Task> get listed => _all.where((t) => !isStep(t)).toList();

  /// The steps of [assignmentId], in the order they were given. Only tasks
  /// are steps: a note inside an assignment is not one.
  List<Task> stepsOf(String assignmentId) => _all
      .where((t) => t.parentId == assignmentId && t.kind == TaskKind.task)
      .toList();

  /// Everything directly inside [parentId]: steps and notes.
  List<Task> childrenOf(String parentId) =>
      _all.where((t) => t.parentId == parentId).toList();

  /// Every note, wherever it sits.
  List<Task> get notes => _all.where((t) => t.isNote).toList();

  /// Finished steps out of all steps of [assignmentId]. Only tasks directly
  /// inside it count, as on DeskPlan.
  Progress progressOf(String assignmentId) {
    final steps = stepsOf(assignmentId);
    return Progress(steps.where((s) => s.done).length, steps.length);
  }

  /// [task] and everything inside it, children before parents: the order to
  /// delete them in, because DeskPlan keeps an assignment that still has
  /// steps or notes inside.
  List<Task> withDescendantsChildrenFirst(Task task) {
    final result = <Task>[];
    void visit(Task t) {
      for (final child in childrenOf(t.id)) {
        visit(child);
      }
      result.add(t);
    }

    visit(task);
    return result;
  }
}
