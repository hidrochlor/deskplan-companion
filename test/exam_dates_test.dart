import 'package:deskplan_companion/features/calendar/calendar_event.dart';
import 'package:deskplan_companion/features/calendar/calendar_event_kind.dart';
import 'package:deskplan_companion/features/calendar/exam_choice_store.dart';
import 'package:deskplan_companion/features/calendar/exam_dates.dart';
import 'package:deskplan_companion/features/calendar/exam_reminder_planner.dart';
import 'package:deskplan_companion/ui/calendar/calendar_entry.dart';
import 'package:deskplan_companion/ui/calendar/calendar_view.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Like the FH JOANNEUM feed: one course, three sittings.
CalendarEvent _exam(String id, DateTime start, {String course = 'EPE'}) =>
    CalendarEvent(
      id: id,
      kind: CalendarEventKind.exam,
      title: 'Exam: $course',
      context: 'WS46a.02.212 · Fluch',
      start: start,
      end: start.add(const Duration(minutes: 90)),
      course: course,
    );

final _now = DateTime(2026, 12, 1, 12);
final _first = _exam('e1', DateTime(2026, 12, 21, 9));
final _second = _exam('e2', DateTime(2027, 1, 18, 9));
final _third = _exam('e3', DateTime(2027, 3, 2, 13));
final _lone = _exam('t1', DateTime(2026, 12, 20, 9), course: 'Trends');
// Out of order on purpose: numbering goes by time.
final _all = [_third, _lone, _first, _second];

void main() {
  group('ExamDates', () {
    test('numbers each course\'s dates by time', () {
      final d = ExamDates.of(_all, const {});
      expect(d.labelOf(_first), 'Date 1 of 3');
      expect(d.labelOf(_second), 'Date 2 of 3');
      expect(d.labelOf(_third), 'Date 3 of 3');
      expect(d.labelOf(_lone), isNull); // only one date
    });

    test('a mark passes over the course\'s other dates only', () {
      final d = ExamDates.of(_all, {ExamDates.keyOf(_second): 'e2'});
      expect(d.isRegistered(_second), isTrue);
      expect(d.isPassedOver(_first), isTrue);
      expect(d.isPassedOver(_third), isTrue);
      expect(d.isPassedOver(_second), isFalse);
      expect(d.isPassedOver(_lone), isFalse);
    });

    test('a mark for a date no longer in the feed is ignored', () {
      final d = ExamDates.of(_all, {ExamDates.keyOf(_first): 'gone'});
      expect(d.isPassedOver(_first), isFalse);
    });
  });

  test('reminders skip the dates passed over', () {
    final ids = ExamReminderPlanner.forEvents(
      _all,
      _now,
      registered: {ExamDates.keyOf(_second): 'e2'},
    ).map((r) => r.eventId).toSet();
    expect(ids, {'e2', 't1'});
  });

  test('the store keeps one mark per course, and clears it', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ExamChoiceStore();
    await store.choose('epe', 'e1');
    await store.choose('epe', 'e2');
    await store.choose('trends', 't1');
    expect(await store.load(), {'epe': 'e2', 'trends': 't1'});
    await store.choose('epe', null);
    expect(await store.load(), {'trends': 't1'});
  });

  testWidgets('marking a date in its sheet; the others show dimmed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    var marks = <String, String>{};
    final calls = <(String, bool)>[];
    Widget app() {
      final dates = ExamDates.of(_all, marks);
      return MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CalendarView(
            entries: [for (final e in _all) CalendarEntry.ofEvent(e, dates)],
            asOf: null,
            onOpenTask: (_, _) {},
            onRefresh: () async {},
            now: () => _now,
            exams: dates,
            onRegister: (e, on) async => calls.add((e.id, on)),
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(
      find.text('Exam · Date 2 of 3 · WS46a.02.212 · Fluch'),
      findsOneWidget,
    );

    await tester.tap(find.text('Exam · Date 2 of 3 · WS46a.02.212 · Fluch'));
    await tester.pumpAndSettle();
    expect(find.text('Date 2 of 3 · also Dec 21, Mar 2'), findsOneWidget);
    await tester.tap(find.text('Registered for this date'));
    await tester.pumpAndSettle();
    expect(calls, [('e2', true)]);

    // The screen saves it and builds the calendar again.
    Navigator.of(tester.element(find.byType(CalendarView))).pop();
    marks = {ExamDates.keyOf(_second): 'e2'};
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    double opacityOf(String text) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
        )
        .opacity;
    expect(
      opacityOf('Exam · Registered · Date 2 of 3 · WS46a.02.212 · Fluch'),
      1,
    );
    expect(opacityOf('Exam · Date 1 of 3 · WS46a.02.212 · Fluch'), lessThan(1));
  });
}
