import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/features/notes/note_format.dart';
import 'package:deskplan_companion/ui/notes/note_tile.dart';
import 'package:deskplan_companion/ui/task_countdown.dart';
import 'package:deskplan_companion/ui/task_groups.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:deskplan_companion/ui/theme/deskplan_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 31, 10, 31);

Task _task(String id, {DateTime? start, DateTime? end}) =>
    Task(id: id, title: id, start: start, end: end, updatedAt: _now);

void main() {
  group('TaskCountdown', () {
    TaskCountdown? of(Task t) => TaskCountdown.of(t, _now);

    test('counts to the start, red within the hour', () {
      final c = of(
        _task(
          's',
          start: _now.add(const Duration(minutes: 39)),
          end: _now.add(const Duration(minutes: 59)),
        ),
      )!;
      expect((c.text, c.tone), ('Starts in 39m', TaskTone.red));
    });

    test('amber within a day, grey later', () {
      final soon = of(_task('a', end: _now.add(const Duration(hours: 7))))!;
      expect((soon.text, soon.tone), ('Due in 7hrs', TaskTone.amber));
      final later = of(_task('b', end: _now.add(const Duration(days: 5))))!;
      expect((later.text, later.tone), ('Due in 5d', TaskTone.grey));
    });

    test('a running block counts to its end; a past end is overdue', () {
      expect(
        of(
          _task(
            'r',
            start: _now.subtract(const Duration(minutes: 10)),
            end: _now.add(const Duration(minutes: 20)),
          ),
        )!.text,
        'Due in 20m',
      );
      final late = of(
        _task('o', end: _now.subtract(const Duration(hours: 10, minutes: 5))),
      )!;
      expect((late.text, late.tone), ('Overdue 10hrs', TaskTone.red));
    });

    test('nothing for a done task or one with no time', () {
      expect(of(_task('n')), isNull);
      expect(
        TaskCountdown.of(
          _task(
            'd',
            end: _now.add(const Duration(hours: 1)),
          ).copyWith(done: true),
          _now,
        ),
        isNull,
      );
    });
  });

  test('groups: overdue oldest first, then each day, then no date', () {
    final groups = TaskGroups.of([
      _task('none'),
      _task('thu', end: DateTime(2026, 11, 5, 23, 59)),
      _task('late', end: _now.subtract(const Duration(minutes: 31))),
      _task('later today', end: DateTime(2026, 10, 31, 19)),
      _task('older', end: _now.subtract(const Duration(hours: 10))),
      _task(
        'running',
        start: DateTime(2026, 10, 30, 9),
        end: DateTime(2026, 11, 1, 9),
      ),
      _task('tomorrow', start: DateTime(2026, 11, 1, 9)),
      _task('stand-up', start: DateTime(2026, 10, 31, 11, 10)),
    ], _now);
    expect(
      [
        for (final g in groups)
          (g.kind, g.day, g.tasks.map((t) => t.id).join(', ')),
      ],
      [
        (TaskGroupKind.overdue, null, 'older, late'),
        (
          TaskGroupKind.day,
          DateTime(2026, 10, 31),
          'running, stand-up, later today',
        ),
        (TaskGroupKind.day, DateTime(2026, 11, 1), 'tomorrow'),
        (TaskGroupKind.day, DateTime(2026, 11, 5), 'thu'),
        (TaskGroupKind.noDate, null, 'none'),
      ],
    );
  });

  group('NoteTile', () {
    Future<Text> count(WidgetTester tester, String text) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: NoteTile(
              note: Task(
                id: 'n1',
                title: 'List',
                kind: TaskKind.note,
                updatedAt: _now,
                doc: NoteFormat.fromPlainText(text),
              ),
              place: 'Learn Basics › CSC101',
              onTap: () {},
            ),
          ),
        ),
      );
      return tester.widget<Text>(find.textContaining('/'));
    }

    testWidgets('the checklist count turns green once all are ticked', (
      tester,
    ) async {
      final some = await count(tester, '[x] one\n[] two');
      expect(some.data, '1/2');
      expect(some.style!.color, isNot(DeskPlanColors.dark.ok));
      expect(find.textContaining('CSC101', findRichText: true), findsOneWidget);

      final all = await count(tester, '[x] one\n[x] two');
      expect(all.data, '2/2');
      expect(all.style!.color, DeskPlanColors.dark.ok);
    });
  });
}
