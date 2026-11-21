import 'package:sqflite/sqflite.dart';

import '../../core/app_database.dart';
import 'queued_upload.dart';
import 'upload_queue.dart';
import 'upload_status.dart';

/// [UploadQueue] stored in the app database.
class SqliteUploadQueue implements UploadQueue {
  static const _table = AppDatabase.uploadsTable;

  /// Sent files kept for the history list; older ones are dropped.
  static const keepSent = 50;

  final AppDatabase _database;

  SqliteUploadQueue(this._database);

  @override
  Future<void> add(QueuedUpload upload) async {
    final db = await _database.open();
    await db.insert(_table, upload.toMap());
  }

  @override
  Future<List<QueuedUpload>> due(DateTime now) async {
    final db = await _database.open();
    final rows = await db.query(
      _table,
      where: 'status = ? AND nextAttemptAt <= ?',
      whereArgs: [UploadStatus.waiting.name, now.millisecondsSinceEpoch],
      orderBy: 'createdAt ASC',
    );
    return rows.map(QueuedUpload.fromMap).toList();
  }

  @override
  Future<List<QueuedUpload>> all() async {
    final db = await _database.open();
    final rows = await db.query(_table, orderBy: 'createdAt DESC');
    return rows.map(QueuedUpload.fromMap).toList();
  }

  @override
  Future<QueuedUpload?> find(String uploadId) async {
    final db = await _database.open();
    final rows = await db.query(
      _table,
      where: 'uploadId = ?',
      whereArgs: [uploadId],
    );
    return rows.isEmpty ? null : QueuedUpload.fromMap(rows.first);
  }

  @override
  Future<void> markSent(String uploadId, DateTime at) async {
    final db = await _database.open();
    await db.update(
      _table,
      {
        'status': UploadStatus.sent.name,
        'sentAt': at.millisecondsSinceEpoch,
        'lastError': null,
      },
      where: 'uploadId = ?',
      whereArgs: [uploadId],
    );
    // Keep only the newest few sent files.
    await db.delete(
      _table,
      where:
          'status = ? AND uploadId NOT IN ('
          'SELECT uploadId FROM $_table WHERE status = ? '
          'ORDER BY sentAt DESC LIMIT $keepSent)',
      whereArgs: [UploadStatus.sent.name, UploadStatus.sent.name],
    );
  }

  @override
  Future<void> markFailed(String uploadId, String reason) async {
    final db = await _database.open();
    await db.update(
      _table,
      {'status': UploadStatus.failed.name, 'lastError': reason},
      where: 'uploadId = ?',
      whereArgs: [uploadId],
    );
  }

  @override
  Future<void> reschedule(
    String uploadId, {
    required DateTime nextAttemptAt,
    required String error,
  }) async {
    final db = await _database.open();
    await db.rawUpdate(
      'UPDATE $_table SET attempts = attempts + 1, nextAttemptAt = ?, '
      'lastError = ? WHERE uploadId = ?',
      [nextAttemptAt.millisecondsSinceEpoch, error, uploadId],
    );
  }

  @override
  Future<void> retry(String uploadId, DateTime now) async {
    final db = await _database.open();
    await db.update(
      _table,
      {
        'status': UploadStatus.waiting.name,
        'attempts': 0,
        'nextAttemptAt': now.millisecondsSinceEpoch,
        'lastError': null,
      },
      where: 'uploadId = ? AND status = ?',
      whereArgs: [uploadId, UploadStatus.failed.name],
    );
  }

  @override
  Future<void> remove(String uploadId) async {
    final db = await _database.open();
    await db.delete(_table, where: 'uploadId = ?', whereArgs: [uploadId]);
  }

  @override
  Future<void> clearSent() async {
    final db = await _database.open();
    await db.delete(
      _table,
      where: 'status = ?',
      whereArgs: [UploadStatus.sent.name],
    );
  }

  @override
  Future<int> waitingCount() async {
    final db = await _database.open();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_table WHERE status = ?', [
            UploadStatus.waiting.name,
          ]),
        ) ??
        0;
  }
}
