import 'dart:async';

import '../../core/task.dart';
import '../../core/task_repository.dart';

/// Saves a note while it is being written, like DeskPlan does on the PC:
/// there is no Save button.
///
/// - Each change is written to the phone's database (and so queued for
///   DeskPlan) after a short pause, so typing does not write on every key.
/// - About two seconds after the last change a sync starts, which sends it.
/// - [flush] writes and syncs at once; call it when the page closes.
///
/// The queue keeps one action per item, so only the newest save of a note
/// ever waits there.
class NoteAutosaver {
  /// The repository that queues changes for DeskPlan.
  final TaskRepository _repository;
  final void Function() _sync;
  final Duration _writeAfter;
  final Duration _sendAfter;

  Task? _pending;
  Timer? _writeTimer;
  Timer? _sendTimer;
  Future<void> _writing = Future.value();

  NoteAutosaver(
    this._repository,
    this._sync, {
    this._writeAfter = const Duration(milliseconds: 400),
    this._sendAfter = const Duration(seconds: 2),
  });

  /// True while a change has not been written yet.
  bool get hasUnsaved => _pending != null;

  /// The note as last changed: written soon.
  void change(Task note) {
    _pending = note;
    _writeTimer?.cancel();
    _writeTimer = Timer(_writeAfter, _write);
    _sendTimer?.cancel();
    _sendTimer = Timer(_sendAfter, () async {
      await _write();
      _sync();
    });
  }

  /// Writes what is waiting and starts a sync now.
  Future<void> flush() async {
    _writeTimer?.cancel();
    final hadChange = _pending != null || (_sendTimer?.isActive ?? false);
    _sendTimer?.cancel();
    await _write();
    if (hadChange) _sync();
  }

  /// Stops without writing (the note was deleted).
  void cancel() {
    _writeTimer?.cancel();
    _sendTimer?.cancel();
    _pending = null;
  }

  Future<void> _write() {
    final note = _pending;
    if (note == null) return _writing;
    _pending = null;
    // One write after the other, so an older version never lands last.
    return _writing = _writing.then((_) => _repository.save(note));
  }
}
