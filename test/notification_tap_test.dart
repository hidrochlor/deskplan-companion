import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/features/calendar/calendar_event.dart';
import 'package:deskplan_companion/features/calendar/exam_reminder_planner.dart';
import 'package:deskplan_companion/features/reminders/notification_target.dart';
import 'package:deskplan_companion/features/reminders/notification_taps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a notification says what it is about', () {
    test('an item, by id', () {
      final t = NotificationTarget.parse(NotificationTarget.forItem('abc-1'));
      expect(t, isA<ItemTarget>());
      expect((t as ItemTarget).id, 'abc-1');
    });

    test('an event, by id, even one with colons and bars in it', () {
      const id = 'feed:3f2a|MET2026_1071313';
      final t = NotificationTarget.parse(NotificationTarget.forEvent(id));
      expect((t as EventTarget).id, id);
    });

    test('none, or the daily goal, opens nothing in particular', () {
      expect(NotificationTarget.parse(null), null);
      expect(NotificationTarget.parse(''), null);
      expect(NotificationTarget.parse('item:'), null);
      expect(NotificationTarget.parse('goal'), null);
    });

    test('an exam reminder carries the exam\'s id', () {
      final exam = CalendarEvent.fromJson({
        'id': 'feed:x|1',
        'kind': 'exam',
        'title': 'Exam',
        'context': '',
        'start': '2027-01-10T09:00:00.000Z',
        'end': '2027-01-10T10:00:00.000Z',
      });
      final plan = ExamReminderPlanner.forEvents([exam], DateTime.utc(2026));
      expect(plan.map((r) => r.eventId), ['feed:x|1', 'feed:x|1']);
    });
  });

  group('taps', () {
    test('while running, each tap goes to the listener', () async {
      final taps = NotificationTaps();
      final seen = <NotificationTarget>[];
      taps.stream.listen(seen.add);
      taps.tapped(NotificationTarget.forItem('a'));
      taps.tapped('goal'); // nothing to open
      await Future<void>.delayed(Duration.zero);
      expect(seen.single, isA<ItemTarget>());
    });

    test('the tap that started the app is handed over once', () {
      final taps = NotificationTaps()
        ..launchedBy(NotificationTarget.forEvent('e'));
      expect(taps.takeLaunch(), isA<EventTarget>());
      expect(taps.takeLaunch(), null);
    });
  });

  test('item reminders use the item id', () {
    final t = Task.create(title: 'A');
    expect(
      (NotificationTarget.parse(NotificationTarget.forItem(t.id)) as ItemTarget)
          .id,
      t.id,
    );
  });
}
