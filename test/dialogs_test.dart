import 'package:deskplan_companion/features/pairing/address_dialog.dart';
import 'package:deskplan_companion/features/pairing/paste_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows a button that opens [dialog]; whatever the dialog pops with is added
/// to [results].
Future<void> _open(WidgetTester tester, Widget dialog, List<Object?> results) {
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(
              await showDialog<String>(
                context: context,
                builder: (_) => dialog,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('cancelling the address dialog closes it without an error', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(
      tester,
      const AddressDialog(current: '10.0.0.5', defaultPort: 47800),
      results,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle(); // the closing animation, which used to crash

    expect(tester.takeException(), isNull);
    expect(results, [null]);
  });

  testWidgets('a bad address shows a message, a good one is returned', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(
      tester,
      const AddressDialog(current: null, defaultPort: 47800),
      results,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not an address');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('Enter an address like'), findsOneWidget);
    expect(results, isEmpty);

    await tester.enterText(find.byType(TextField), ' 192.168.1.5:47801 ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(results, ['192.168.1.5:47801']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Remove returns an empty string', (tester) async {
    final results = <Object?>[];
    await _open(
      tester,
      const AddressDialog(current: '10.0.0.5', defaultPort: 47800),
      results,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(results, ['']);
  });

  testWidgets('cancelling the paste dialog closes it without an error', (
    tester,
  ) async {
    final results = <Object?>[];
    await _open(tester, const PasteCodeDialog(), results);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(results, [null]);
  });
}
