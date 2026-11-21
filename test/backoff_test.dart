import 'package:flutter_test/flutter_test.dart';
import 'package:deskplan_companion/features/queue/backoff.dart';

void main() {
  test('doubles from 30 seconds', () {
    expect(Backoff.delayFor(1), const Duration(seconds: 30));
    expect(Backoff.delayFor(2), const Duration(minutes: 1));
    expect(Backoff.delayFor(3), const Duration(minutes: 2));
  });

  test('never exceeds one hour, even for huge attempt counts', () {
    expect(Backoff.delayFor(8), const Duration(hours: 1));
    expect(Backoff.delayFor(500), const Duration(hours: 1));
  });
}
