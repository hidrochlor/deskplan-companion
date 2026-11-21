import 'package:sqflite/sqflite.dart';

import '../../core/app_database.dart';
import 'action_queue.dart';
import 'sync_action.dart';

/// [ActionQueue] stored in the app database.
class SqliteActionQueue implements ActionQueue {
  static const _table = AppDatabase.queueTable;
  final AppDatabase _database;
  final DateTime Function() _now;

  SqliteActionQueue(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> enqueue(String taskId, ActionType type) async =>
      enqueueIn(await _database.open(), taskId, type);

  /// Same as [enqueue] but inside a given transaction (or database).
  Future<void> enqueueIn(
    DatabaseExecutor db,
    String taskId,
    ActionType type,
  ) async {
    // REPLACE removes the old row for this task and inserts a new one,
    // which gets a new `seq` and resets attempts.
    await db.insert(_table, {
      'taskId': taskId,
      'type': type.name,
      'attempts': 0,
      'nextAttemptAt': _now().millisecondsSinceEpoch,
      'lastError': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<SyncAction>> due(DateTime now) async {
    final db = await _database.open();
    final rows = await db.query(
      _table,
      where: 'nextAttemptAt <= ?',
      whereArgs: [now.millisecondsSinceEpoch],
      orderBy: 'seq ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> complete(SyncAction action) async {
    final db = await _database.open();
    await db.delete(_table, where: 'seq = ?', whereArgs: [action.seq]);
  }

  @override
  Future<void> reschedule(
    SyncAction action, {
    required DateTime nextAttemptAt,
    required String error,
  }) async {
    final db = await _database.open();
    await db.update(
      _table,
      {
        'attempts': action.attempts + 1,
        'nextAttemptAt': nextAttemptAt.millisecondsSinceEpoch,
        'lastError': error,
      },
      where: 'seq = ?',
      whereArgs: [action.seq],
    );
  }

  @override
  Future<bool> hasPending(String taskId) async {
    final db = await _database.open();
    final rows = await db.query(
      _table,
      columns: ['seq'],
      where: 'taskId = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<int> pendingCount() async {
    final db = await _database.open();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_table'),
        ) ??
        0;
  }

  SyncAction _fromRow(Map<String, Object?> r) => SyncAction(
    seq: r['seq'] as int,
    taskId: r['taskId'] as String,
    type: ActionType.values.byName(r['type'] as String),
    attempts: r['attempts'] as int,
    nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
      r['nextAttemptAt'] as int,
      isUtc: true,
    ),
    lastError: r['lastError'] as String?,
  );
}
