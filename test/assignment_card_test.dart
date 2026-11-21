import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/core/progress.dart';
import 'package:deskplan_companion/ui/assignment_card.dart';
import 'package:deskplan_companion/ui/countdown.dart';
import 'package:deskplan_companion/ui/source_badge.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:deskplan_companion/ui/theme/deskplan_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 31, 9, 25);

void main() {
  group('Countdown', () {
    String at(Duration d) => Countdown.of(_now.add(d), _now);

    test('says what is left, coarser the further away', () {
      expect(at(const Duration(minutes: 49)), 'Due in 49m');
      expect(at(const Duration(hours: 5, minutes: 49)), 'Due in 5hrs 49m');
      expect(
        at(const Duration(days: 1, hours: 14, minutes: 5)),
        'Due in 1d 14hrs',
      );
      expect(at(const Duration(days: 3, hours: 2)), 'Due in 3d');
    });

    test('says how late once past', () {
      expect(at(const Duration(hours: -7, minutes: -11)), 'Overdue 7hrs');
      expect(at(const Duration(minutes: -20)), 'Overdue 20m');
      expect(at(const Duration(days: -2, hours: -3)), 'Overdue 2d');
    });
  });

  Future<void> pump(WidgetTester tester, Task task, {Progress? steps}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: AssignmentCard(
              task: task,
              now: _now,
              course: 'Digital Signal Processing',
              progress: steps,
              onTap: () {},
            ),
          ),
        ),
      );

  Task assignment({
    required Duration dueIn,
    bool done = false,
    Map<String, Object?>? source,
  }) => Task(
    id: 'a1',
    title: 'Lab report 2',
    kind: TaskKind.assignment,
    end: _now.add(dueIn),
    done: done,
    updatedAt: _now,
    source: source,
  );

  testWidgets('shows the countdown, date, course, steps and source pill', (
    tester,
  ) async {
    await pump(
      tester,
      assignment(
        dueIn: const Duration(hours: 5, minutes: 49),
        source: {'label': 'Moodle'},
      ),
      steps: const Progress(2, 4),
    );
    expect(find.text('Due in 5hrs 49m'), findsOneWidget);
    expect(find.text('Sat, Oct 31 · 15:14'), findsOneWidget);
    expect(find.text('Lab report 2'), findsOneWidget);
    expect(find.text('Digital Signal Processing'), findsOneWidget);
    expect(find.text('2/4 steps done'), findsOneWidget);
    expect(find.byType(SourceBadge), findsOneWidget);
  });

  testWidgets('a submitted one says Submitted, with no pill if not imported', (
    tester,
  ) async {
    await pump(tester, assignment(dueIn: const Duration(days: -4), done: true));
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('No steps yet'), findsOneWidget);
    expect(find.byType(SourceBadge), findsNothing);
  });

  testWidgets('the steps turn green once all are done, submitted or not', (
    tester,
  ) async {
    Color? stepsColor() =>
        tester.widget<Text>(find.textContaining('steps done')).style!.color;

    await pump(
      tester,
      assignment(dueIn: const Duration(days: 2)),
      steps: const Progress(1, 3),
    );
    expect(stepsColor(), isNot(DeskPlanColors.dark.ok));

    await pump(
      tester,
      assignment(dueIn: const Duration(days: 2)),
      steps: const Progress(3, 3),
    );
    expect(find.text('3/3 steps done'), findsOneWidget);
    expect(stepsColor(), DeskPlanColors.dark.ok);
  });

  test('Progress is complete only when every one is done', () {
    expect(const Progress(3, 3).isComplete, isTrue);
    expect(const Progress(2, 3).isComplete, isFalse);
    expect(Progress.none.isComplete, isFalse);
    expect(const Progress(1, 4).fraction, 0.25);
  });
}
