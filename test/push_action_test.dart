import 'package:deskplan_companion/core/repeat_rule.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/features/reminders/push_action.dart';
import 'package:deskplan_companion/features/reminders/reminder_kind.dart';
import 'package:deskplan_companion/features/reminders/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 19, 12);

Task _task({DateTime? start, DateTime? end, RepeatRule? repeat}) => Task(
  id: 't',
  title: 'Read chapter 3',
  start: start,
  end: end,
  repeat: repeat,
  updatedAt: _now,
);

void main() {
  const later30 = PushAction(Duration(minutes: 30), wholeBlock: true);
  const extend60 = PushAction(Duration(hours: 1), wholeBlock: false);

  test('ids read back, labels say what happens', () {
    for (final a in [later30, extend60]) {
      expect(PushAction.parse(a.id), a);
    }
    expect(later30.label, 'Start 30 min later');
    expect(extend60.label, 'Extend 1 hr');
    expect(PushAction.parse(null), isNull);
    expect(PushAction.parse('push:sideways:30'), isNull);
  });

  test('the start reminder moves the whole block', () {
    final t = _task(
      start: _now.add(const Duration(hours: 1)),
      end: _now.add(const Duration(hours: 2)),
    );
    final pushed = later30.applyTo(t, _now);
    expect(pushed.start, t.start!.add(const Duration(minutes: 30)));
    expect(pushed.end, t.end!.add(const Duration(minutes: 30)));
  });

  test('a due reminder extends the end only, from now once past', () {
    final t = _task(
      start: _now.subtract(const Duration(hours: 1)),
      end: _now.add(const Duration(minutes: 10)),
    );
    final pushed = extend60.applyTo(t, _now);
    expect(pushed.start, t.start);
    expect(pushed.end, t.end!.add(const Duration(hours: 1)));

    final late = _task(end: _now.subtract(const Duration(minutes: 5)));
    expect(
      extend60.applyTo(late, _now).end,
      _now.add(const Duration(hours: 1)),
    );
  });

  test('only one-off items with a due time get the buttons', () {
    final oneOff = _task(
      start: _now.add(const Duration(hours: 1)),
      end: _now.add(const Duration(hours: 2)),
    );
    final plan = ReminderPlanner.forTask(oneOff, _now);
    expect(plan.first.kind, ReminderKind.start);
    expect(plan.first.actions.map((a) => a.wholeBlock), [true, true]);
    expect(plan.last.actions.map((a) => a.wholeBlock), [false, false]);

    final repeating = _task(
      end: _now.add(const Duration(hours: 2)),
      repeat: RepeatRule(RepeatEvery.week),
    );
    expect(PushAction.offeredFor(repeating), isFalse);
    expect(
      ReminderPlanner.forTask(repeating, _now).every((r) => r.actions.isEmpty),
      isTrue,
    );
    expect(PushAction.offeredFor(_task()), isFalse);
    expect(PushAction.offeredFor(oneOff.copyWith(done: true)), isFalse);
    expect(
      PushAction.offeredFor(
        oneOff.copyWith(kind: TaskKind.assignment, clearStart: true),
      ),
      isTrue,
    );
  });
}
