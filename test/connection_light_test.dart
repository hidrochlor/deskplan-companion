import 'package:deskplan_companion/features/connection/connection_light.dart';
import 'package:deskplan_companion/features/connection/unreachable_cause.dart';
import 'package:deskplan_companion/features/reminders/goal_reminder.dart';
import 'package:deskplan_companion/features/reminders/goal_reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ConnectionLight', () {
    test('green when DeskPlan answered, blue when it was not reached', () {
      expect(
        ConnectionLight.from(cause: null, reached: true),
        ConnectionLight.connected,
      );
      expect(
        ConnectionLight.from(cause: null, reached: false),
        ConnectionLight.idle,
      );
      expect(
        ConnectionLight.from(
          cause: UnreachableCause.cannotReach,
          reached: false,
        ),
        ConnectionLight.idle,
      );
    });

    test('amber when something needs a look on the PC', () {
      for (final cause in [
        UnreachableCause.awaitingApproval,
        UnreachableCause.receivingOff,
        UnreachableCause.other,
      ]) {
        expect(
          ConnectionLight.from(cause: cause, reached: false),
          ConnectionLight.attention,
          reason: '$cause',
        );
      }
    });

    test('red when the phone must be paired again, grey when not paired', () {
      expect(
        ConnectionLight.from(cause: UnreachableCause.unpaired, reached: false),
        ConnectionLight.problem,
      );
      expect(
        ConnectionLight.from(
          cause: UnreachableCause.identityChanged,
          reached: false,
        ),
        ConnectionLight.problem,
      );
      expect(
        ConnectionLight.from(cause: UnreachableCause.notPaired, reached: false),
        ConnectionLight.off,
      );
    });
  });

  group('GoalReminderStore', () {
    test('a new goal has no text: the prompt is only a hint', () async {
      SharedPreferences.setMockInitialValues({});
      final goal = await GoalReminderStore().load();
      expect(goal.text, '');
      expect(goal.enabled, false);
    });

    test(
      'the old saved prompt is not treated as the user\'s own text',
      () async {
        SharedPreferences.setMockInitialValues({
          'goal.text': 'What is your goal for today?',
          'goal.enabled': true,
          'goal.hour': 7,
        });
        final goal = await GoalReminderStore().load();
        expect(goal.text, '');
        expect(goal.hour, 7);
      },
    );

    test('the user\'s own text is kept', () async {
      SharedPreferences.setMockInitialValues({'goal.text': 'Finish chapter 3'});
      expect((await GoalReminderStore().load()).text, 'Finish chapter 3');
    });

    test('a blank goal falls back to the prompt in the notification', () {
      const blank = GoalReminder(text: '   ');
      expect(
        blank.text.trim().isEmpty ? GoalReminder.defaultText : blank.text,
        'What is your goal today?',
      );
    });
  });
}
