import 'package:deskplan_companion/core/repeat_rule.dart';
import 'package:deskplan_companion/core/repeats.dart';
import 'package:deskplan_companion/core/task.dart';
import 'package:deskplan_companion/ui/series_card.dart';
import 'package:deskplan_companion/ui/series_details_sheet.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// German class every Monday 16:00-17:30: two weeks ago done, last week
/// missed, and the next one a week from now.
TaskSeries _german() {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day + 7);
  Task copy(String id, int weeksBack, {bool done = false}) {
    final d = DateTime(monday.year, monday.month, monday.day - 7 * weeksBack);
    return Task(
      id: id,
      title: 'German',
      start: DateTime(d.year, d.month, d.day, 16),
      end: DateTime(d.year, d.month, d.day, 17, 30),
      done: done,
      updatedAt: now,
      repeat: RepeatRule(RepeatEvery.week),
    );
  }

  return Repeats.seriesOf([
    copy('de', 2, done: true),
    copy('de.r1', 1),
    copy('de.r2', 0),
  ]).single;
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('the card shows the series once, with its next occurrence', (
    tester,
  ) async {
    var ticked = 0;
    await tester.pumpWidget(
      _app(
        SeriesCard(
          series: _german(),
          now: DateTime.now(),
          onTap: () {},
          onToggleDone: () => ticked++,
        ),
      ),
    );
    expect(find.text('German'), findsOneWidget);
    expect(find.textContaining('Next '), findsOneWidget);
    expect(find.textContaining('Weekly'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    expect(ticked, 1);
  });

  testWidgets('the details list next, coming up and earlier, done or missed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Task? toggled;
    final series = _german();
    await tester.pumpWidget(
      _app(
        SeriesDetailsSheet(
          series: series,
          onToggle: (t) async {
            toggled = t;
            return series;
          },
        ),
      ),
    );
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('COMING UP'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.text('Delete series'), findsOneWidget);

    // Ticking the missed one ticks that very copy.
    final missedRow = find.ancestor(
      of: find.text('Missed'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: missedRow.first, matching: find.byType(Checkbox)),
    );
    await tester.pump();
    expect(toggled?.id, 'de.r1');
  });
}
