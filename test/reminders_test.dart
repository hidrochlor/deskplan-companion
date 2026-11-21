import 'package:deskplan_companion/core/due_urgency.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/core/task_repository.dart';
import 'package:deskplan_companion/features/reminders/goal_reminder.dart';
import 'package:deskplan_companion/features/reminders/reminder_ids.dart';
import 'package:deskplan_companion/features/reminders/reminder_kind.dart';
import 'package:deskplan_companion/features/reminders/reminder_options.dart';
import 'package:deskplan_companion/features/reminders/reminder_options_store.dart';
import 'package:deskplan_companion/features/reminders/reminder_planner.dart';
import 'package:deskplan_companion/features/reminders/reminder_scheduler.dart';
import 'package:deskplan_companion/features/reminders/reminding_task_repository.dart';
import 'package:deskplan_companion/ui/settings_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 11, 1, 12);

Task _task({DateTime? start, DateTime? end, bool done = false}) => Task(
  id: 't1',
  title: 'Read chapter 3',
  start: start,
  end: end,
  done: done,
  updatedAt: _now,
);

class _FakeScheduler implements ReminderScheduler {
  final calls = <String>[];
  bool failing = false;

  void _record(String call) {
    calls.add(call);
    if (failing) throw StateError('notifications blocked');
  }

  @override
  Future<void> scheduleTask(Task task) async => _record('schedule ${task.id}');
  @override
  Future<void> cancelTask(String taskId) async => _record('cancel $taskId');
  @override
  Future<void> rescheduleAll(List<Task> tasks) async => _record('all');
  @override
  Future<void> setDailyGoal(GoalReminder goal) async => _record('goal');
}

class _MemoryRepository implements TaskRepository {
  final saved = <String, Task>{};
  @override
  Future<List<Task>> all() async => saved.values.toList();
  @override
  Future<Task?> get(String id) async => saved[id];
  @override
  Future<void> save(Task task) async => saved[task.id] = task;
  @override
  Future<void> delete(String id) async => saved.remove(id);
}

void main() {
  group('DueUrgency', () {
    test('overdue, within 24 hours, within a week, later', () {
      expect(
        DueUrgency.of(_now.subtract(const Duration(minutes: 1)), _now),
        DueUrgency.overdue,
      );
      expect(
        DueUrgency.of(_now.add(const Duration(hours: 24)), _now),
        DueUrgency.within24Hours,
      );
      expect(
        DueUrgency.of(_now.add(const Duration(days: 3)), _now),
        DueUrgency.withinWeek,
      );
      expect(
        DueUrgency.of(_now.add(const Duration(days: 8)), _now),
        DueUrgency.later,
      );
    });
  });

  group('ReminderPlanner', () {
    test('plans a reminder at start and at end', () {
      final plan = ReminderPlanner.forTask(
        _task(
          start: _now.add(const Duration(hours: 1)),
          end: _now.add(const Duration(hours: 3)),
        ),
        _now,
      );
      expect(plan.map((r) => r.kind), [ReminderKind.start, ReminderKind.end]);
      expect(plan[0].at, _now.add(const Duration(hours: 1)));
      expect(plan[1].at, _now.add(const Duration(hours: 3)));
      expect(plan[0].title, 'Read chapter 3');
      expect(plan[0].body, 'Time to start');
      expect(plan[0].label, 'Task');
    });

    test('an assignment is labelled as one', () {
      final plan = ReminderPlanner.forTask(
        _task(
          end: _now.add(const Duration(hours: 3)),
        ).copyWith(kind: TaskKind.assignment),
        _now,
      );
      expect(plan.single.label, 'Assignment');
      expect(plan.single.body, 'Due now');
    });

    test('skips times already past, and tasks with no times', () {
      final past = _task(
        start: _now.subtract(const Duration(hours: 1)),
        end: _now.add(const Duration(hours: 1)),
      );
      expect(ReminderPlanner.forTask(past, _now).map((r) => r.kind), [
        ReminderKind.end,
      ]);
      expect(ReminderPlanner.forTask(_task(), _now), isEmpty);
    });

    test('a done task has no reminders', () {
      final done = _task(end: _now.add(const Duration(hours: 1)), done: true);
      expect(ReminderPlanner.forTask(done, _now), isEmpty);
    });

    test('warns a day and an hour before it is due when asked', () {
      final due = _now.add(const Duration(days: 2));
      final plan = ReminderPlanner.forTask(
        _task(end: due),
        _now,
        warnings: {DueWarning.day1, DueWarning.hour1},
      );
      expect(plan.map((r) => r.kind), [
        ReminderKind.dayBefore,
        ReminderKind.hourBefore,
        ReminderKind.end,
      ]);
      expect(plan[0].at, due.subtract(const Duration(days: 1)));
      expect(plan[0].body, 'Due tomorrow');
      expect(plan[1].at, due.subtract(const Duration(hours: 1)));
      expect(plan[1].body, 'Due in 1 hour');
    });

    test('a warning already past is skipped, and off adds none', () {
      final soon = _task(end: _now.add(const Duration(hours: 3)));
      expect(
        ReminderPlanner.forTask(
          soon,
          _now,
          warnings: {DueWarning.day1, DueWarning.hour1},
        ).map((r) => r.kind),
        [ReminderKind.hourBefore, ReminderKind.end],
      );
      expect(ReminderPlanner.forTask(soon, _now).map((r) => r.kind), [
        ReminderKind.end,
      ]);
      expect(
        ReminderPlanner.forTask(
          _task(start: _now.add(const Duration(days: 3))),
          _now,
          warnings: {DueWarning.day1, DueWarning.hour1},
        ).map((r) => r.kind),
        [ReminderKind.dayBefore, ReminderKind.hourBefore, ReminderKind.start],
      );
    });

    test('a time block warns before its start, not its end', () {
      final from = _now.add(const Duration(hours: 3));
      final to = from.add(const Duration(hours: 1));
      final plan = ReminderPlanner.forTask(
        _task(start: from, end: to),
        _now,
        warnings: {DueWarning.hour1, DueWarning.minutes30},
      );
      expect(plan.map((r) => r.kind), [
        ReminderKind.hourBefore,
        ReminderKind.minutes30Before,
        ReminderKind.start,
        ReminderKind.end,
      ]);
      expect(plan[0].at, from.subtract(const Duration(hours: 1)));
      expect(plan[0].body, 'Starts in 1 hour');
      expect(plan[1].at, from.subtract(const Duration(minutes: 30)));
      expect(plan[1].body, 'Starts in 30 minutes');
    });
  });

  group('Due warnings', () {
    test('any mix can be on, and each fires its own time before', () {
      final due = _now.add(const Duration(days: 2));
      final plan = ReminderPlanner.forTask(
        _task(end: due),
        _now,
        warnings: DueWarning.values.toSet(),
      );
      expect(plan.map((r) => r.at), [
        due.subtract(const Duration(days: 1)),
        due.subtract(const Duration(hours: 5)),
        due.subtract(const Duration(hours: 3)),
        due.subtract(const Duration(hours: 1)),
        due.subtract(const Duration(minutes: 30)),
        due,
      ]);
      expect(plan[4].body, 'Due in 30 minutes');
      expect(
        ReminderPlanner.forTask(
          _task(end: due),
          _now,
          warnings: {DueWarning.hours3},
        ).map((r) => r.kind),
        [ReminderKind.hours3Before, ReminderKind.end],
      );
    });

    test('toggling switches one warning only', () {
      const off = ReminderOptions();
      final on = off.toggled(DueWarning.hours5).toggled(DueWarning.minutes30);
      expect(on.warnings, {DueWarning.hours5, DueWarning.minutes30});
      expect(on.toggled(DueWarning.hours5).warnings, {DueWarning.minutes30});
      expect(off.warnings, isEmpty);
    });
  });

  group('ReminderOptionsStore', () {
    test('keeps the old single choice, then saves the new toggles', () async {
      SharedPreferences.setMockInitialValues({'reminders.dueWarning': 'both'});
      final store = ReminderOptionsStore();
      expect((await store.load()).warnings, {
        DueWarning.day1,
        DueWarning.hour1,
      });
      await store.save(
        const ReminderOptions(warnings: {DueWarning.hours3}, exams: false),
      );
      final loaded = await store.load();
      expect(loaded.warnings, {DueWarning.hours3});
      expect(loaded.exams, isFalse);
      await store.save(const ReminderOptions());
      expect((await store.load()).warnings, isEmpty);
    });
  });

  group('ReminderIds', () {
    test('are stable, differ by kind, fit Android, and avoid the goal id', () {
      final ids = [
        for (final kind in ReminderKind.values)
          ReminderIds.forTask('abc', kind),
      ];
      expect(ReminderIds.forTask('abc', ReminderKind.start), ids.first);
      expect(ids.toSet(), hasLength(ReminderKind.values.length));
      for (final id in ids) {
        expect(id, greaterThan(ReminderIds.dailyGoal));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });

  group('SettingsTab.syncedText', () {
    test('just now, minutes, hours', () {
      expect(SettingsTab.syncedText(_now, _now), 'synced just now');
      expect(
        SettingsTab.syncedText(_now.subtract(const Duration(minutes: 5)), _now),
        'synced 5 min ago',
      );
      expect(
        SettingsTab.syncedText(
          _now.subtract(const Duration(minutes: 130)),
          _now,
        ),
        'synced 2 h ago',
      );
    });
  });

  group('RemindingTaskRepository', () {
    test('saving and deleting also update reminders', () async {
      final fake = _FakeScheduler();
      final repo = RemindingTaskRepository(_MemoryRepository(), fake);
      await repo.save(_task());
      await repo.delete('t1');
      expect(fake.calls, ['schedule t1', 'cancel t1']);
    });

    test('a reminder failure never loses the saved task', () async {
      final fake = _FakeScheduler()..failing = true;
      final inner = _MemoryRepository();
      await RemindingTaskRepository(inner, fake).save(_task());
      expect(inner.saved.containsKey('t1'), true);
    });
  });
}
