import 'repeats.dart';
import 'task_repository.dart';

/// Moves repeating items on by themselves: when an occurrence ends without
/// being ticked off, its next copy is saved through [_repository] (so it is
/// queued for DeskPlan and gets its reminders), and the past one stays not
/// done. See [Repeats.dueCopies].
class RepeatAdvancer {
  final TaskRepository _repository;

  /// For tests: the moment taken as now.
  final DateTime Function() _now;

  RepeatAdvancer(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Saves the copies due now. True when there were any.
  Future<bool> run() async {
    final copies = Repeats.dueCopies(await _repository.all(), _now());
    for (final c in copies) {
      // Pulled from DeskPlan meanwhile: never twice.
      if (await _repository.get(c.id) == null) await _repository.save(c);
    }
    return copies.isNotEmpty;
  }
}
