import 'package:flutter_test/flutter_test.dart';
import 'package:deskplan_companion/core/task.dart';

void main() {
  test('Task survives a toMap/fromMap round trip', () {
    final t = Task.create(title: 'Pay rent', end: DateTime.utc(2026, 11, 1, 9));
    final back = Task.fromMap(t.toMap());
    expect(back.id, t.id);
    expect(back.title, 'Pay rent');
    expect(back.end, t.end);
    expect(back.done, false);
  });

  test('new ids are UUID v4', () {
    final id = Task.create(title: 'A').id;
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('times are stored as UTC text ending in Z, even from local input', () {
    final local = DateTime(2026, 11, 1, 9, 30);
    final map = Task.create(title: 'A', start: local, end: local).toMap();
    expect((map['start'] as String).endsWith('Z'), true);
    expect((map['end'] as String).endsWith('Z'), true);
    expect((map['updatedAt'] as String).endsWith('Z'), true);
    expect(DateTime.parse(map['start'] as String), local.toUtc());
  });

  test('copyWith keeps the id and bumps updatedAt', () {
    final t = Task.create(title: 'A');
    final done = t.copyWith(done: true);
    expect(done.id, t.id);
    expect(done.done, true);
    expect(done.updatedAt.isBefore(t.updatedAt), false);
  });

  test('copyWith can clear a time, and null alone keeps it', () {
    final t = Task.create(title: 'A', end: DateTime.utc(2026, 11, 1));
    expect(t.copyWith(title: 'B').end, t.end);
    expect(t.copyWith(clearEnd: true).end, isNull);
  });

  test('copyWith keeps a given updatedAt (a task pulled from the PC)', () {
    final t = Task.create(title: 'A');
    final pcTime = DateTime.utc(2026, 11, 2, 10);
    expect(t.copyWith(done: true, updatedAt: pcTime).updatedAt, pcTime);
  });

  test('moving forgets DeskPlan\'s course; other edits keep it', () {
    final t = Task(
      id: 'x',
      title: 'DevFest',
      parentId: 'all-day',
      course: 'All Day',
      courseKnown: true,
      updatedAt: DateTime.utc(2026),
    );
    final kept = t.copyWith(title: 'DevFest Linz', parentId: 'all-day');
    expect((kept.course, kept.courseKnown), ('All Day', true));
    final moved = t.copyWith(parentId: 'events');
    expect((moved.course, moved.courseKnown), (null, false));
    final home = t.copyWith(clearParent: true);
    expect((home.course, home.courseKnown), (null, false));
  });
}
