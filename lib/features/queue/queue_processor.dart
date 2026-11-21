import 'package:uuid/uuid.dart';

import '../../core/task.dart';
import '../../core/task_repository.dart';
import '../notes/json_equality.dart';
import '../upload/task_uploader.dart';
import '../upload/upload_result.dart';
import 'action_queue.dart';
import 'backoff.dart';
import 'parents_first_order.dart';
import 'sync_action.dart';
import 'sync_report.dart';

/// Works through the due actions, oldest first, and reports what happened.
/// Call [run] when the app opens, when Wi-Fi connects, or on a timer.
///
/// [repository] must be the plain storage, not the one that queues actions,
/// so applying DeskPlan's version doesn't queue a new save.
class QueueProcessor {
  final ActionQueue _queue;
  final TaskRepository _repository;
  final TaskUploader _uploader;
  final ParentsFirstOrder _order;
  final DateTime Function() _now;
  bool _running = false;

  QueueProcessor({
    required this._queue,
    required this._repository,
    required this._uploader,
    DateTime Function()? now,
  }) : _order = ParentsFirstOrder(_repository),
       _now = now ?? DateTime.now;

  /// [syncNotes] is true when DeskPlan syncs notes (its ping lists `notes`).
  /// Otherwise a note's save waits in the queue until it does.
  Future<SyncReport> run({bool syncNotes = false}) async {
    final report = SyncReport();
    if (_running) return report..skipped = true;
    _running = true;
    try {
      final due = await _order.order(await _queue.due(_now()));
      for (final action in due) {
        final keepGoing = await _process(action, report, syncNotes);
        if (!keepGoing) break;
      }
    } finally {
      _running = false;
    }
    return report;
  }

  /// Returns false when the run should stop.
  Future<bool> _process(
    SyncAction action,
    SyncReport report,
    bool syncNotes,
  ) async {
    Task? sent;
    final UploadResult result;
    switch (action.type) {
      case ActionType.save:
        sent = await _repository.get(action.taskId);
        if (sent == null) {
          // Deleted locally since; a delete action replaced this one or is
          // not needed. Nothing to send.
          await _queue.complete(action);
          return true;
        }
        // This DeskPlan does not take notes (now): keep it for later.
        if (sent.isNote && !syncNotes) return true;
        // Wait for the parent to reach DeskPlan first, or DeskPlan would
        // refuse this one for sitting in something that does not exist yet.
        final parent = sent.parentId;
        if (parent != null && await _queue.hasPending(parent)) return true;
        result = await _uploader.save(sent);
      case ActionType.delete:
        result = await _uploader.delete(action.taskId);
    }

    switch (result) {
      case Confirmed(:final pcVersion, :final stored):
        await _queue.complete(action);
        report.sent++;
        if (pcVersion != null) {
          await _applyPcVersion(sent, pcVersion);
        } else {
          await _markDetailsSent(sent, stored);
        }
        return true;
      case Rejected(:final reason):
        await _queue.complete(action);
        final what = sent == null ? 'A deleted task' : '"${sent.title}"';
        report.rejections.add('DeskPlan refused $what: $reason');
        return true;
      case RetryLater(:final reason):
        await _queue.reschedule(
          action,
          nextAttemptAt: _now().add(Backoff.delayFor(action.attempts + 1)),
          error: reason,
        );
        report.retryLater++;
        return true;
      case Unreachable(:final reason, :final cause, :final retrySoon):
        report.unreachableReason = reason;
        report.unreachableCause = cause;
        report.retrySoon = retrySoon;
        return false;
    }
  }

  /// DeskPlan kept a newer version: copy it here, unless the user has edited
  /// the task again since we sent it (that edit is queued and will be sent).
  ///
  /// A note's text is never thrown away (protocol.md section 4, rule 5): if
  /// DeskPlan's text differs from what was sent, the phone's text becomes a
  /// new "(phone copy)" note, queued like any other.
  Future<void> _applyPcVersion(Task? sent, Task pcVersion) async {
    if (sent == null) return;
    if (sent.isNote && !JsonEquality.equals(sent.doc, pcVersion.doc)) {
      await _keepPhoneCopy(sent);
    }
    final current = await _repository.get(sent.id);
    if (current == null || current.updatedAt != sent.updatedAt) return;
    await _repository.save(pcVersion.withMissingFieldsFrom(current));
  }

  /// DeskPlan's title limit, which the copy's title must stay within.
  static const _maxTitle = 500;
  static const _copySuffix = ' (phone copy)';

  Future<void> _keepPhoneCopy(Task sent) async {
    final room = _maxTitle - _copySuffix.length;
    final title = sent.title.length > room
        ? sent.title.substring(0, room)
        : sent.title;
    final now = _now();
    final copy = Task(
      id: const Uuid().v4(),
      title: '$title$_copySuffix',
      updatedAt: now,
      kind: sent.kind,
      parentId: sent.parentId,
      createdAt: now,
      details: sent.details,
      doc: sent.doc,
    );
    await _repository.save(copy);
    await _queue.enqueue(copy.id, ActionType.save);
  }

  /// DeskPlan has the details we sent, so the next save must not send them
  /// again: it could then overwrite a newer description typed on the PC. If
  /// the task was edited again meanwhile, that newer save carries its own.
  /// The fields only DeskPlan decides are taken from its reply, [stored].
  Future<void> _markDetailsSent(Task? sent, Task? stored) async {
    if (sent == null || (!sent.detailsEdited && stored == null)) return;
    final current = await _repository.get(sent.id);
    if (current == null || current.updatedAt != sent.updatedAt) return;
    var next = current;
    if (sent.detailsEdited) {
      next = next.copyWith(updatedAt: next.updatedAt, detailsEdited: false);
    }
    if (stored != null) next = stored.serverFieldsOnto(next);
    await _repository.save(next);
  }
}
