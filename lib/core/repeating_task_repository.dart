import 'repeats.dart';
import 'task.dart';
import 'task_repository.dart';

/// Wraps the screens' [TaskRepository]: when a save ticks off a repeating
/// item (it was not done before), the next copy is saved too, through the
/// same repository, so it is queued for DeskPlan and gets its reminders.
/// Unticking one whose time is still ahead takes that copy back, and an edit
/// of the latest copy reaches the copies still ahead.
///
/// Only the user's own ticks go through here. When DeskPlan reports an item
/// done, DeskPlan has made the copy itself and the next pull brings it.
class RepeatingTaskRepository implements TaskRepository {
  final TaskRepository _inner;

  /// For tests: the moment taken as now.
  final DateTime Function() _now;

  RepeatingTaskRepository(this._inner, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<List<Task>> all() => _inner.all();

  @override
  Future<Task?> get(String id) => _inner.get(id);

  @override
  Future<void> save(Task task) async {
    final before = task.repeat != null ? await _inner.get(task.id) : null;
    await _inner.save(task);
    await _follow(task);
    if (!task.done && (before?.done ?? false)) return _takeBack(task);
    if (!task.done || task.repeat == null || (before?.done ?? false)) return;
    final copy = Repeats.nextCopy(task, _now());
    // Already there (made before, or pulled from DeskPlan): never twice.
    if (copy == null || await _inner.get(copy.id) != null) return;
    await _inner.save(copy);
  }

  /// An edit of a series' latest copy (time, rule, title, details) reaches
  /// its copies still ahead too, so the calendar shows no stale ones. See
  /// [TaskSeries.followers].
  Future<void> _follow(Task task) async {
    if (task.repeat == null) return;
    if (await _inner.get(Repeats.nextId(task.id)) != null) return;
    final series = Repeats.seriesOf(
      await _inner.all(),
    ).where((s) => s.contains(task.id)).firstOrNull;
    if (series == null) return;
    for (final f in series.followers(_now())) {
      await _inner.save(f);
    }
  }

  /// Unticked while its time is still ahead: the copy its tick made goes
  /// again (deleted on DeskPlan too), so it is the next one once more. Only
  /// while that copy is the series' latest and not done; a past one just
  /// counts as missed.
  Future<void> _takeBack(Task task) async {
    final end = task.end;
    if (end == null || !end.isAfter(_now())) return;
    final copy = await _inner.get(Repeats.nextId(task.id));
    if (copy == null || copy.done) return;
    if (await _inner.get(Repeats.nextId(copy.id)) != null) return;
    await _inner.delete(copy.id);
  }

  @override
  Future<void> delete(String id) => _inner.delete(id);
}
