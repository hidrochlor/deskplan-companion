import '../../core/task.dart';
import '../../core/task_kind.dart';
import '../../core/task_repository.dart';
import '../notes/json_equality.dart';
import '../queue/action_queue.dart';
import 'pull_reply.dart';
import 'pulled_item.dart';

/// Applies DeskPlan's changes to the phone's tasks, following
/// docs/protocol.md section 5:
///
/// - A task with a change the phone has not sent yet is left alone: that
///   change is sent first and the usual conflict rules decide.
/// - Otherwise DeskPlan's version replaces the phone's if its `updatedAt` is
///   newer **or equal** (DeskPlan wins ties). A task the phone lacks is added.
/// - A deletion removes the task.
/// - After a full resync, any item of the kinds asked for that is not in the
///   list is removed. Other kinds are left alone (a pull without notes
///   never wipes the phone's notes).
///
/// [repository] must be the plain one, not the one that queues changes, so a
/// pulled change never becomes something to send back.
class PullApplier {
  final TaskRepository _repository;
  final ActionQueue _queue;

  PullApplier(this._repository, this._queue);

  /// What a pull asks for when nothing else is said.
  static const defaultKinds = {TaskKind.task, TaskKind.assignment};

  /// Applies [reply], which DeskPlan built for [kinds]. Returns how many
  /// items actually changed here. Safe to run twice on the same answer:
  /// DeskPlan repeats items on purpose.
  Future<int> apply(
    PullReply reply, {
    Set<TaskKind> kinds = defaultKinds,
  }) async {
    var changed = 0;
    final listed = <String>{};

    for (final item in reply.items) {
      switch (item) {
        case PulledTask(:final task):
          listed.add(task.id);
          if (await _applyTask(task)) changed++;
        case PulledDeletion(:final id):
          if (await _applyDeletion(id)) changed++;
      }
    }

    if (reply.fullResync) {
      for (final local in await _repository.all()) {
        if (!kinds.contains(local.kind)) continue; // not asked for
        if (listed.contains(local.id)) continue;
        if (await _queue.hasPending(local.id)) continue; // still to be sent
        await _repository.delete(local.id);
        changed++;
      }
    }
    return changed;
  }

  Future<bool> _applyTask(Task pulled) async {
    if (await _queue.hasPending(pulled.id)) return false;
    final local = await _repository.get(pulled.id);
    if (local == null) {
      await _repository.save(pulled);
      return true;
    }
    // The phone's copy is newer: it wins (and has been, or will be, sent).
    if (pulled.updatedAt.isBefore(local.updatedAt)) return false;
    if (_same(pulled, local)) return false;
    await _repository.save(pulled.withMissingFieldsFrom(local));
    return true;
  }

  Future<bool> _applyDeletion(String id) async {
    if (await _queue.hasPending(id)) return false;
    var removed = false;
    if (await _repository.get(id) != null) {
      await _repository.delete(id);
      removed = true;
    }
    // DeskPlan deletes everything inside a folder or assignment with it and
    // reports each one, but the phone also clears the children it knows about.
    if (await _removeChildrenOf(id)) removed = true;
    return removed;
  }

  /// Removes tasks inside [parentId], and inside those, unless one has a
  /// change still to be sent. Returns true if anything was removed.
  Future<bool> _removeChildrenOf(String parentId) async {
    var removed = false;
    final children = (await _repository.all())
        .where((t) => t.parentId == parentId)
        .toList();
    for (final child in children) {
      if (await _queue.hasPending(child.id)) continue;
      await _removeChildrenOf(child.id);
      await _repository.delete(child.id);
      removed = true;
    }
    return removed;
  }

  /// Whether DeskPlan's [pulled] version says nothing new compared with our
  /// [local] copy. Details and creation time only count when DeskPlan sent
  /// them: the stand-in time of a task first seen here is different every time.
  bool _same(Task pulled, Task local) =>
      pulled.title == local.title &&
      pulled.start == local.start &&
      pulled.end == local.end &&
      pulled.done == local.done &&
      pulled.kind == local.kind &&
      pulled.parentId == local.parentId &&
      pulled.placeKnown == local.placeKnown &&
      (!pulled.detailsKnown ||
          (local.detailsKnown && pulled.details == local.details)) &&
      (!pulled.createdKnown ||
          (local.createdKnown && pulled.createdAt == local.createdAt)) &&
      (pulled.doc == null || JsonEquality.equals(pulled.doc, local.doc)) &&
      (!pulled.courseKnown ||
          (local.courseKnown && pulled.course == local.course)) &&
      (pulled.source == null ||
          JsonEquality.equals(pulled.source, local.source)) &&
      pulled.updatedAt == local.updatedAt;
}
