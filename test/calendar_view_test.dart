import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/core/task_kind.dart';
import 'package:deskplan_companion/core/task_tree.dart';
import 'package:deskplan_companion/features/calendar/calendar_event.dart';
import 'package:deskplan_companion/ui/calendar/calendar_entry.dart';
import 'package:deskplan_companion/ui/calendar/calendar_entry_row.dart';
import 'package:deskplan_companion/ui/calendar/calendar_view.dart';
import 'package:deskplan_companion/ui/course_names.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Midday local time on Oct 30, 2026, so nothing slips a day in any zone.
final _now = DateTime(2026, 10, 30, 12);

CalendarEvent _event(
  String id, {
  String kind = 'lecture',
  String title = 'Storage and Power-to-X Technologies',
  String context = 'VO · Online · Sumereder Christof',
  required DateTime start,
  required DateTime end,
}) => CalendarEvent.fromJson({
  'id': id,
  'kind': kind,
  'title': title,
  'context': context,
  'start': start.toUtc().toIso8601String(),
  'end': end.toUtc().toIso8601String(),
});

Future<List<Task>> _pump(
  WidgetTester tester,
  List<CalendarEntry> entries, {
  DateTime? asOf,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final opened = <Task>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: CalendarView(
          entries: entries,
          asOf: asOf,
          onOpenTask: opened.add,
          onRefresh: () async {},
          now: () => _now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  final lecture = _event(
    'l',
    start: DateTime(2026, 10, 30, 14),
    end: DateTime(2026, 10, 30, 16),
  );

  testWidgets('shows cached events offline with "Timetable as of"', (
    tester,
  ) async {
    await _pump(tester, [
      CalendarEntry.ofEvent(lecture),
    ], asOf: DateTime(2026, 10, 30, 9));

    expect(find.text('Storage and Power-to-X Technologies'), findsOneWidget);
    expect(
      find.text('Lecture · VO · Online · Sumereder Christof'),
      findsOneWidget,
    );
    expect(find.textContaining('Timetable as of'), findsOneWidget);
  });

  testWidgets('without a fetched calendar there is no "as of" line', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(find.textContaining('Timetable as of'), findsNothing);
    expect(find.text('Nothing on this day'), findsOneWidget);
  });

  testWidgets('an unknown kind is shown as an event, in the event colour', (
    tester,
  ) async {
    final odd = _event(
      'w',
      kind: 'workshop',
      title: 'Career fair',
      context: 'Main hall',
      start: DateTime(2026, 10, 30, 13),
      end: DateTime(2026, 10, 30, 15),
    );
    final entry = CalendarEntry.ofEvent(odd);
    expect(entry.color, CalendarEntry.eventColor);
    await _pump(tester, [entry]);
    expect(find.text('Event · Main hall'), findsOneWidget);
  });

  testWidgets('tapping an event shows it read-only: no edit or delete', (
    tester,
  ) async {
    final opened = await _pump(tester, [CalendarEntry.ofEvent(lecture)]);
    await tester.tap(find.text('Storage and Power-to-X Technologies'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Read-only here'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(opened, isEmpty);
  });

  testWidgets('a past event is dimmed, a coming one is not', (tester) async {
    final past = _event(
      'p',
      title: 'Morning lecture',
      start: DateTime(2026, 10, 30, 8),
      end: DateTime(2026, 10, 30, 10),
    );
    await _pump(tester, [
      CalendarEntry.ofEvent(past),
      CalendarEntry.ofEvent(lecture),
    ]);
    double opacityOf(String title) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text(title), matching: find.byType(Opacity)),
        )
        .opacity;
    expect(opacityOf('Morning lecture'), lessThan(1));
    expect(opacityOf('Storage and Power-to-X Technologies'), 1);
  });

  testWidgets('tapping an item opens it', (tester) async {
    final a = Task(
      id: 'a',
      title: 'Essay 1',
      end: DateTime(2026, 10, 30, 23, 59),
      updatedAt: DateTime.utc(2026),
      kind: TaskKind.assignment,
      parentId: 'cc',
      course: 'Climate Change and Dynamics',
      courseKnown: true,
    );
    final entries = CalendarEntry.ofItems(
      [a],
      TaskTree([a]),
      CourseNames(const [], [a]),
    );
    final opened = await _pump(tester, entries);

    expect(
      find.text('Assignment · Climate Change and Dynamics'),
      findsOneWidget,
    );
    await tester.tap(find.text('Essay 1'));
    await tester.pumpAndSettle();
    expect(opened.single.id, 'a');
  });

  testWidgets('the agenda lists days from today on', (tester) async {
    final next = _event(
      'n',
      kind: 'exam',
      title: 'Exam: Climate Change and Dynamics',
      context: '',
      start: DateTime(2026, 11, 3, 9),
      end: DateTime(2026, 11, 3, 10, 30),
    );
    final old = _event(
      'o',
      title: 'Last week',
      start: DateTime(2026, 10, 20, 9),
      end: DateTime(2026, 10, 20, 10),
    );
    await _pump(tester, [
      CalendarEntry.ofEvent(lecture),
      CalendarEntry.ofEvent(next),
      CalendarEntry.ofEvent(old),
    ]);
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarEntryRow), findsNWidgets(2));
    expect(find.text('Last week'), findsNothing);
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.text('Exam'), findsOneWidget);
  });

  group('the phone\'s items on the calendar', () {
    test('time blocks and steps run from start to end; due times are '
        'moments; notes and items without an end are left out', () {
      final block = Task(
        id: 'b',
        title: 'Study',
        start: DateTime.utc(2026, 11, 1, 14),
        end: DateTime.utc(2026, 11, 1, 16),
        updatedAt: DateTime.utc(2026),
      );
      final asg = Task(
        id: 'a',
        title: 'Essay',
        end: DateTime.utc(2026, 11, 2, 22),
        updatedAt: DateTime.utc(2026),
        kind: TaskKind.assignment,
        parentId: 'f',
      );
      final step = Task(
        id: 's',
        title: 'Outline',
        start: DateTime.utc(2026, 11, 1, 9),
        end: DateTime.utc(2026, 11, 1, 10),
        updatedAt: DateTime.utc(2026),
        parentId: 'a',
      );
      final note = Task.createNote(title: 'Ideas');
      final undated = Task(
        id: 'u',
        title: 'Someday',
        updatedAt: DateTime(2026),
      );
      final all = [block, asg, step, note, undated];
      final entries = CalendarEntry.ofItems(
        all,
        TaskTree(all),
        CourseNames(const [], all),
      );

      expect(entries.map((e) => e.title), ['Study', 'Essay', 'Outline']);
      expect(entries[0].isDue, false);
      expect(entries[0].start, DateTime.utc(2026, 11, 1, 14));
      expect(entries[1].isDue, true);
      expect(entries[1].start, entries[1].end);
      expect(entries[1].color, CalendarEntry.assignmentColor);
      expect(entries[2].label, startsWith('Step'));
      expect(entries[2].color, CalendarEntry.taskColor);
    });

    test('the PC\'s colours', () {
      Color colourOf(String kind) => CalendarEntry.ofEvent(
        _event('x', kind: kind, start: _now, end: _now),
      ).color;
      expect(colourOf('lecture'), const Color(0xFF5C9CE6));
      expect(colourOf('exam'), const Color(0xFFFF5C7A));
      expect(colourOf('event'), const Color(0xFF8B90A3));
    });
  });
}
