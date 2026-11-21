import 'package:sqflite/sqflite.dart';

import 'task.dart';
import 'app_database.dart';
import 'task_repository.dart';

/// SQLite implementation of [TaskRepository]. Knows nothing about syncing.
class TaskStorage implements TaskRepository {
  static const _table = AppDatabase.tasksTable;
  final AppDatabase _database;

  TaskStorage(this._database);

  @override
  Future<List<Task>> all() async {
    final db = await _database.open();
    final rows = await db.query(_table, orderBy: 'start IS NULL, start ASC');
    return rows.map(Task.fromMap).toList();
  }

  @override
  Future<Task?> get(String id) async {
    final db = await _database.open();
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Task.fromMap(rows.first);
  }

  @override
  Future<void> save(Task task) async => saveIn(await _database.open(), task);

  @override
  Future<void> delete(String id) async => deleteIn(await _database.open(), id);

  /// Same as [save] but inside a given transaction (or database), so it can
  /// be combined with other writes into one all-or-nothing step.
  Future<void> saveIn(DatabaseExecutor db, Task task) => db.insert(
    _table,
    task.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> deleteIn(DatabaseExecutor db, String id) =>
      db.delete(_table, where: 'id = ?', whereArgs: [id]);
}
