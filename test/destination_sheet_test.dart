import 'package:deskplan_companion/features/connection/destination.dart';
import 'package:deskplan_companion/ui/destination_sheet.dart';
import 'package:deskplan_companion/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _all = [
  Destination(id: 'received-files', label: 'Received files'),
  Destination(id: 'folder:csc', label: 'CSC101', name: 'CSC101'),
  Destination(
    id: 'folder:wk1',
    label: 'CSC101 › Week 1',
    name: 'Week 1',
    depth: 1,
  ),
  Destination(
    id: 'folder:hw2',
    label: 'CSC101 › Week 1 › Homework 2',
    name: 'Homework 2',
    depth: 2,
  ),
  Destination(
    id: 'folder:wk2',
    label: 'CSC101 › Week 2',
    name: 'Week 2',
    depth: 1,
  ),
  Destination(id: 'folder:math', label: 'MATH200', name: 'MATH200'),
];

Future<List<Object?>> _open(WidgetTester tester, String selectedId) async {
  final results = <Object?>[];
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(
              await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => DestinationSheet(
                  destinations: _all,
                  selectedId: selectedId,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('sub-folders start closed, and open with the arrow', (
    tester,
  ) async {
    await _open(tester, 'received-files');

    expect(find.text('CSC101'), findsOneWidget);
    expect(find.text('MATH200'), findsOneWidget);
    expect(find.text('Week 1'), findsNothing); // inside a closed folder

    await tester.tap(find.byTooltip('Open').first);
    await tester.pumpAndSettle();
    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('Week 2'), findsOneWidget);
    expect(find.text('Homework 2'), findsNothing); // one level at a time

    await tester.tap(find.byTooltip('Close').first);
    await tester.pumpAndSettle();
    expect(find.text('Week 1'), findsNothing);
  });

  testWidgets('the path to the current choice starts open', (tester) async {
    await _open(tester, 'folder:hw2');
    expect(find.text('CSC101'), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('Homework 2'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping a row chooses it, and arrows do not', (tester) async {
    final results = await _open(tester, 'received-files');

    await tester.tap(find.byTooltip('Open').first); // only opens
    await tester.pumpAndSettle();
    expect(results, isEmpty);

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();
    expect(results, ['folder:wk2']);
  });
}
