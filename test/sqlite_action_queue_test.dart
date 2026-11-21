import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/features/queue/sync_action.dart';
import 'package:deskplan_companion/core/app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase database;
  late SqliteActionQueue queue;
  var clock = DateTime.utc(2026, 11, 1, 12);

  setUp(() {
    clock = DateTime.utc(2026, 11, 1, 12);
    database = AppDatabase(path: inMemoryDatabasePath);
    queue = SqliteActionQueue(database, now: () => clock);
  });

  // Closing drops the in-memory database, so every test starts empty.
  tearDown(() => database.close());

  test('a newer action for the same task replaces the older one', () async {
    await queue.enqueue('a', ActionType.save);
    await queue.enqueue('a', ActionType.delete);
    final due = await queue.due(clock);
    expect(due, hasLength(1));
    expect(due.single.type, ActionType.delete);
    expect(await queue.pendingCount(), 1);
  });

  test('actions come out oldest first', () async {
    await queue.enqueue('a', ActionType.save);
    await queue.enqueue('b', ActionType.save);
    await queue.enqueue('a', ActionType.save); // a is now newer than b
    final ids = (await queue.due(clock)).map((x) => x.taskId).toList();
    expect(ids, ['b', 'a']);
  });

  test('finishing a stale action does not remove the newer one', () async {
    await queue.enqueue('a', ActionType.save);
    final stale = (await queue.due(clock)).single;
    await queue.enqueue('a', ActionType.save); // edited while sending
    await queue.complete(stale);
    expect(await queue.pendingCount(), 1);
  });

  test(
    'reschedule counts the attempt and hides it until the retry time',
    () async {
      await queue.enqueue('a', ActionType.save);
      final action = (await queue.due(clock)).single;
      final retryAt = clock.add(const Duration(minutes: 5));
      await queue.reschedule(action, nextAttemptAt: retryAt, error: 'busy');

      expect(await queue.due(clock), isEmpty);
      final later = (await queue.due(retryAt)).single;
      expect(later.attempts, 1);
      expect(later.lastError, 'busy');
      expect(await queue.pendingCount(), 1);
    },
  );
}
