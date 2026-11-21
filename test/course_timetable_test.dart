import 'package:deskplan_companion/features/calendar/calendar_event.dart';
import 'package:deskplan_companion/ui/calendar/calendar_entry.dart';
import 'package:deskplan_companion/ui/calendar/calendar_view.dart';
import 'package:deskplan_companion/ui/calendar/course_sessions.dart';
import 'package:deskplan_companion/ui/calendar/course_timetable_screen.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Midday local time on Oct 30, 2026 (a Friday).
final _now = DateTime(2026, 10, 30, 12);

CalendarEvent _event(
  String id, {
  String kind = 'lecture',
  String title = 'Climate Change and Dynamics',
  String? course = 'Climate Change and Dynamics',
  required DateTime start,
  required DateTime end,
}) => CalendarEvent.fromJson({
  'id': id,
  'kind': kind,
  'title': title,
  'context': 'VO · WS46a.02.212',
  'course': course,
  'start': start.toUtc().toIso8601String(),
  'end': end.toUtc().toIso8601String(),
});

/// Tuesdays 09:00-12:15 (Oct 20 to Nov 10), one Thursday 13:00-14:30, an
/// exam, and a lecture of another course.
final _events = [
  for (final d in [20, 27])
    _event(
      'tue$d',
      start: DateTime(2026, 10, d, 9),
      end: DateTime(2026, 10, d, 12, 15),
    ),
  for (final d in [3, 10])
    _event(
      'tue-n$d',
      start: DateTime(2026, 11, d, 9),
      end: DateTime(2026, 11, d, 12, 15),
    ),
  _event(
    'thu',
    start: DateTime(2026, 11, 5, 13),
    end: DateTime(2026, 11, 5, 14, 30),
  ),
  _event(
    'exam',
    kind: 'exam',
    title: 'Exam: Climate Change and Dynamics',
    start: DateTime(2026, 12, 2, 9),
    end: DateTime(2026, 12, 2, 10, 30),
  ),
  _event(
    'other',
    title: 'Renewable Energy Generation',
    course: 'Renewable Energy Generation',
    start: DateTime(2026, 11, 4, 9),
    end: DateTime(2026, 11, 4, 11),
  ),
];

void main() {
  group('CourseSessions', () {
    test('collects lectures and exams of one course, soonest first', () {
      final c = CourseSessions.of('climate change and dynamics', _events);
      expect(c.sessions.map((e) => e.id), [
        'tue20',
        'tue27',
        'tue-n3',
        'thu',
        'tue-n10',
        'exam',
      ]);
      expect(c.lectures, hasLength(5));
      expect(c.exams, hasLength(1));
      expect(c.next(_now)!.id, 'tue-n3');
    });

    test('finds the weekly slot; one-off lectures count as irregular', () {
      final c = CourseSessions.of('Climate Change and Dynamics', _events);
      expect(c.weekly.map((s) => s.label), ['Tue 09:00–12:15']);
      expect(c.weekly.single.count, 4);
      expect(c.irregular, 1);
    });

    test('without a course name, the title (minus "Exam: ") stands in', () {
      final old = [
        _event(
          'a',
          course: null,
          start: DateTime(2026, 11, 3, 9),
          end: DateTime(2026, 11, 3, 10),
        ),
        _event(
          'b',
          kind: 'exam',
          course: null,
          title: 'Exam: Climate Change and Dynamics',
          start: DateTime(2026, 12, 2, 9),
          end: DateTime(2026, 12, 2, 10),
        ),
      ];
      final c = CourseSessions.of(old.first.courseName, old);
      expect(c.sessions, hasLength(2));
    });
  });

  testWidgets('a lecture\'s sheet opens the whole course timetable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CalendarView(
            entries: _events.map(CalendarEntry.ofEvent).toList(),
            asOf: _now,
            onOpenTask: (_) {},
            onRefresh: () async {},
            now: () => _now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Agenda lists everything from today on; the first is Tuesday Nov 3.
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Climate Change and Dynamics').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all 6 sessions'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseTimetableScreen), findsOneWidget);
    expect(find.text('Tue 09:00–12:15  ×4'), findsOneWidget);
    expect(find.text('+ 1 at other times'), findsOneWidget);
    expect(find.textContaining('5 lectures · 1 exam'), findsOneWidget);
  });
}
