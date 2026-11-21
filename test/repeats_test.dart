import 'package:deskplan_companion/core/repeat_advancer.dart';
import 'package:deskplan_companion/core/repeat_rule.dart';
import 'package:deskplan_companion/core/repeating_task_repository.dart';
import 'package:deskplan_companion/core/repeats.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/core/task_remover.dart';
import 'package:deskplan_companion/core/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mon Nov 2, 2026, 12:00 local (the same moment the PC's tests use).
final _now = DateTime(2026, 11, 2, 12);
final _weekly = RepeatRule(RepeatEvery.week);

class _MemoryRepository implements TaskRepository {
  final tasks = <String, Task>{};

  @override
  Future<List<Task>> all() async => tasks.values.toList();

  @override
  Future<Task?> get(String id) async => tasks[id];

  @override
  Future<void> save(Task task) async => tasks[task.id] = task;

  @override
  Future<void> delete(String id) async => tasks.remove(id);
}

Task _gym({RepeatRule? repeat, bool done = false}) => Task(
  id: 'gym',
  title: 'Gym',
  start: DateTime(2026, 11, 3, 8),
  end: DateTime(2026, 11, 3, 9),
  done: done,
  updatedAt: _now,
  details: 'legs',
  repeat: repeat,
);

void main() {
  group('Repeats (the same answers as DeskPlan)', () {
    test('nextId counts copies and always fits 64 characters', () {
      expect(Repeats.nextId('abc'), 'abc.r1');
      expect(Repeats.nextId('abc.r1'), 'abc.r2');
      expect(Repeats.nextId('abc.r9'), 'abc.r10');
      final long = 'x' * 64;
      expect(Repeats.nextId(long), '${'x' * 52}.r1');
      expect(
        Repeats.nextId(Repeats.nextId(long)).length,
        lessThanOrEqualTo(64),
      );
    });

    test('start and end move together, skipping missed weeks', () {
      final next = Repeats.nextTimes(
        start: DateTime(2026, 10, 13, 8),
        end: DateTime(2026, 10, 13, 9),
        rule: _weekly,
        now: _now,
      )!;
      expect(next.start, DateTime(2026, 11, 3, 8).toUtc());
      expect(next.end, DateTime(2026, 11, 3, 9).toUtc());
    });

    test('monthly keeps its day, on the last day of a shorter month', () {
      final next = Repeats.nextTimes(
        end: DateTime(2027, 1, 31, 9),
        rule: RepeatRule(RepeatEvery.month),
        now: DateTime(2027, 1, 31, 9, 1),
      )!;
      expect(next.end, DateTime(2027, 2, 28, 9).toUtc());
    });

    test('until ends the series', () {
      final rule = RepeatRule(
        RepeatEvery.week,
        until: DateTime(2026, 11, 5, 9),
      );
      expect(
        Repeats.nextTimes(end: DateTime(2026, 11, 3, 9), rule: rule, now: _now),
        isNull,
      );
    });
  });

  group('RepeatingTaskRepository', () {
    test('ticking a repeating task adds its next copy, once', () async {
      final inner = _MemoryRepository();
      final repo = RepeatingTaskRepository(inner, now: () => _now);
      await repo.save(_gym(repeat: _weekly));
      await repo.save(_gym(repeat: _weekly, done: true));
      final copy = inner.tasks['gym.r1']!;
      expect(copy.title, 'Gym');
      expect(copy.done, isFalse);
      expect(copy.details, 'legs');
      expect(copy.detailsEdited, isTrue); // a new item: its details go along
      expect(copy.start, DateTime(2026, 11, 10, 8).toUtc());
      expect(copy.end, DateTime(2026, 11, 10, 9).toUtc());
      expect(copy.repeat, _weekly);

      // Saving it done again, or unticking and ticking, adds no second copy.
      await repo.save(_gym(repeat: _weekly, done: true));
      await repo.save(_gym(repeat: _weekly));
      await repo.save(_gym(repeat: _weekly, done: true));
      expect(inner.tasks, hasLength(2));
    });

    test('no rule, a note, or an imported item: no copy', () async {
      final inner = _MemoryRepository();
      final repo = RepeatingTaskRepository(inner, now: () => _now);
      await repo.save(_gym(done: true));
      final imported = Task(
        id: 'hw',
        title: 'HW',
        end: DateTime(2026, 11, 3, 9),
        done: true,
        updatedAt: _now,
        kind: TaskKind.assignment,
        source: {'label': 'Moodle'},
        repeat: _weekly,
      );
      await repo.save(imported);
      expect(inner.tasks.keys, unorderedEquals(['gym', 'hw']));
    });
  });

  group('sync', () {
    test('the rule is sent once known, and read back', () {
      final json = _gym(repeat: _weekly).toSyncJson();
      expect(json['repeat'], {'every': 'week', 'interval': 1, 'until': null});
      final back = Task.fromSyncJson({...json, 'kind': 'task'});
      expect(back.repeat, _weekly);
      expect(back.repeatKnown, isTrue);
    });

    test('an item from a DeskPlan without repeats sends none', () {
      final old = Task.fromSyncJson({
        'id': 'a',
        'title': 'x',
        'done': false,
        'updatedAt': '2026-11-01T00:00:00.000Z',
        'kind': 'task',
      });
      expect(old.repeatKnown, isFalse);
      expect(old.toSyncJson().containsKey('repeat'), isFalse);
      // Clearing it on the phone makes it known: null is sent.
      expect(old.copyWith(clearRepeat: true).toSyncJson()['repeat'], isNull);
      expect(
        old.copyWith(clearRepeat: true).toSyncJson().containsKey('repeat'),
        isTrue,
      );
    });

    test('a bad rule from DeskPlan is refused', () {
      expect(
        () => Task.fromSyncJson({
          'id': 'a',
          'title': 'x',
          'done': false,
          'updatedAt': '2026-11-01T00:00:00.000Z',
          'kind': 'task',
          'repeat': {'every': 'fortnight'},
        }),
        throwsFormatException,
      );
    });

    test('Task.syncFields includes repeat, so the next pull reads it', () {
      expect(Task.syncFields, contains('repeat'));
    });
  });

  group('series and auto-advance', () {
    /// German class, Mon 16:00-17:30, last week's copy [n] of the series.
    Task german(
      String id,
      DateTime day, {
      bool done = false,
      RepeatRule? rule,
    }) => Task(
      id: id,
      title: 'German',
      start: DateTime(day.year, day.month, day.day, 16),
      end: DateTime(day.year, day.month, day.day, 17, 30),
      done: done,
      updatedAt: _now,
      repeat: rule ?? _weekly,
    );

    test('rootOf and numberOf read the copy id', () {
      expect(Repeats.rootOf('abc.r3'), 'abc');
      expect(Repeats.rootOf('abc'), 'abc');
      expect(Repeats.numberOf('abc.r12'), 12);
      expect(Repeats.numberOf('abc'), 0);
    });

    test('an occurrence that ended unticked gets its next copy; it stays '
        'not done', () async {
      final repo = _MemoryRepository();
      final past = german('de', DateTime(2026, 10, 26));
      repo.tasks['de'] = past;
      expect(await RepeatAdvancer(repo, now: () => _now).run(), isTrue);
      expect(repo.tasks['de']!.done, isFalse);
      final next = repo.tasks['de.r1']!;
      expect(next.start, DateTime(2026, 11, 2, 16).toUtc());
      expect(next.done, isFalse);
      // Run again: nothing more until that one ends too.
      expect(await RepeatAdvancer(repo, now: () => _now).run(), isFalse);
      expect(repo.tasks.length, 2);
    });

    test('only the latest copy advances, and never past until', () {
      final ended = RepeatRule(RepeatEvery.week, until: DateTime(2026, 11, 1));
      expect(
        Repeats.dueCopies([
          german('de', DateTime(2026, 10, 19)),
          german('de.r1', DateTime(2026, 10, 26)),
        ], _now).map((t) => t.id),
        ['de.r2'],
      );
      expect(
        Repeats.dueCopies([
          german('x', DateTime(2026, 10, 26), rule: ended),
        ], _now),
        isEmpty,
      );
      // Not over yet, or done (the tick made the copy): nothing.
      expect(
        Repeats.dueCopies([german('y', DateTime(2026, 11, 9))], _now),
        isEmpty,
      );
      expect(
        Repeats.dueCopies([
          german('z', DateTime(2026, 10, 26), done: true),
        ], _now),
        isEmpty,
      );
    });

    test('ticking a missed one later makes nothing new', () async {
      final repo = RepeatingTaskRepository(
        _MemoryRepository(),
        now: () => _now,
      );
      final missed = german('de', DateTime(2026, 10, 26));
      await repo.save(missed);
      await RepeatAdvancer(repo, now: () => _now).run();
      await repo.save(missed.copyWith(done: true));
      expect((await repo.all()).map((t) => t.id).toSet(), {'de', 'de.r1'});
    });

    test('seriesOf groups the copies, latest last, and plain tasks are not '
        'series', () {
      final series = Repeats.seriesOf([
        german('de.r1', DateTime(2026, 11, 9)),
        german('de', DateTime(2026, 11, 2), done: true),
        _gym(),
      ]);
      expect(series, hasLength(1));
      expect(series.single.members.map((t) => t.id), ['de', 'de.r1']);
      expect(series.single.latest.id, 'de.r1');
      expect(series.single.past.map((t) => t.id), ['de']);
      expect(series.single.ended(_now), isFalse);
    });

    test('upcoming lists the coming dates up to until', () {
      final rule = RepeatRule(
        RepeatEvery.week,
        until: DateTime(2026, 11, 30, 23),
      );
      final series = Repeats.seriesOf([
        german('de', DateTime(2026, 11, 2), rule: rule),
      ]).single;
      expect(series.upcoming().map((t) => t.start!.toLocal().day), [
        9,
        16,
        23,
        30,
      ]);
    });

    test('deleting any copy deletes the whole series', () async {
      final repo = _MemoryRepository();
      for (final t in [
        german('de', DateTime(2026, 10, 26)),
        german('de.r1', DateTime(2026, 11, 2)),
        _gym(),
      ]) {
        repo.tasks[t.id] = t;
      }
      await TaskRemover(repo).remove(repo.tasks['de']!);
      expect(repo.tasks.keys, ['gym']);
    });
  });

  group('unticking takes the copy back', () {
    Task deutsch(String id, int day, {bool done = false}) => Task(
      id: id,
      title: 'Deutsch lernen',
      start: DateTime(2026, 11, day, 16),
      end: DateTime(2026, 11, day, 17, 30),
      done: done,
      updatedAt: _now,
      repeat: _weekly,
    );

    test(
      'tick the 9th and the 16th, untick both: the 9th is next again',
      () async {
        final inner = _MemoryRepository();
        final repo = RepeatingTaskRepository(inner, now: () => _now);
        await repo.save(deutsch('de', 9));
        await repo.save(deutsch('de', 9, done: true));
        await repo.save(deutsch('de.r1', 16, done: true));
        expect(inner.tasks.keys.toSet(), {'de', 'de.r1', 'de.r2'});

        await repo.save(deutsch('de.r1', 16)); // untick the 16th
        expect(inner.tasks.keys.toSet(), {'de', 'de.r1'});
        await repo.save(deutsch('de', 9)); // untick the 9th
        expect(inner.tasks.keys.toSet(), {'de'});
        expect(
          Repeats.seriesOf(await repo.all()).single.latest.end,
          DateTime(2026, 11, 9, 17, 30).toUtc(),
        );
      },
    );

    test(
      'nothing is taken back when the copy is done, or the time passed',
      () async {
        final inner = _MemoryRepository();
        final repo = RepeatingTaskRepository(inner, now: () => _now);
        inner.tasks['de'] = deutsch('de', 9, done: true);
        inner.tasks['de.r1'] = deutsch('de.r1', 16, done: true);
        inner.tasks['de.r2'] = deutsch('de.r2', 23);
        await repo.save(deutsch('de', 9)); // its copy is done: kept
        expect(inner.tasks.length, 3);

        final past = _MemoryRepository();
        final repo2 = RepeatingTaskRepository(past, now: () => _now);
        past.tasks['old'] = Task(
          id: 'old',
          title: 'Old',
          end: DateTime(2026, 10, 26, 9),
          done: true,
          updatedAt: _now,
          repeat: _weekly,
        );
        past.tasks['old.r1'] = Task(
          id: 'old.r1',
          title: 'Old',
          end: DateTime(2026, 11, 9, 9),
          updatedAt: _now,
          repeat: _weekly,
        );
        await repo2.save(past.tasks['old']!.copyWith(done: false));
        expect(past.tasks.length, 2); // missed, the next one stays
      },
    );
  });

  test('an edit of the series reaches the copies still ahead, not the past '
      'ones', () async {
    Task at(String id, int month, int day, int hour, {bool done = false}) =>
        Task(
          id: id,
          title: 'Deutsch',
          start: DateTime(2026, month, day, hour),
          end: DateTime(2026, month, day, hour, 30),
          done: done,
          updatedAt: _now,
          repeat: _weekly,
        );
    final inner = _MemoryRepository();
    final repo = RepeatingTaskRepository(inner, now: () => _now);
    for (final t in [
      at('de', 10, 26, 14), // past: history
      at('de.r1', 11, 9, 14, done: true), // ticked early
      at('de.r2', 11, 16, 14),
    ]) {
      inner.tasks[t.id] = t;
    }
    // The pen edits the latest: 15:00 instead of 14:00, and a new title.
    await repo.save(at('de.r2', 11, 16, 15).copyWith(title: 'Deutsch lernen'));
    final r1 = inner.tasks['de.r1']!;
    expect(r1.start, DateTime(2026, 11, 9, 15).toUtc());
    expect(r1.title, 'Deutsch lernen');
    expect(r1.done, isTrue);
    expect(inner.tasks['de']!.start, DateTime(2026, 10, 26, 14).toUtc());
    expect(inner.tasks['de']!.title, 'Deutsch');
  });
}
