import 'package:deskplan_companion/features/reminders/reminder_options.dart';
import 'package:deskplan_companion/ui/due_warning_timeline.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary reads the stops longest first', () {
    expect(DueWarningTimeline.summary({}), 'Reminds only when it is due.');
    expect(
      DueWarningTimeline.summary({DueWarning.hour1}),
      'Reminds 1 hour before, and when it is due.',
    );
    expect(
      DueWarningTimeline.summary({
        DueWarning.minutes30,
        DueWarning.day1,
        DueWarning.hour1,
      }),
      'Reminds 1 day, 1 hour and 30 minutes before, and when it is due.',
    );
  });

  testWidgets('tapping a stop toggles it; Due cannot be tapped', (
    tester,
  ) async {
    final toggled = <DueWarning>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: DueWarningTimeline(
            selected: const {DueWarning.day1},
            onToggle: toggled.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('3 hrs'));
    await tester.tap(find.text('Due'));
    expect(toggled, [DueWarning.hours3]);
  });
}
