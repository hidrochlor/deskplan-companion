import 'package:sqflite/sqflite.dart';

import '../../core/app_database.dart';
import 'calendar_event.dart';
import 'calendar_reply.dart';
import 'calendar_store.dart';

/// [CalendarStore] in the app database.
class SqliteCalendarStore implements CalendarStore {
  static const _events = AppDatabase.eventsTable;
  static const _window = AppDatabase.windowTable;
  final AppDatabase _database;

  SqliteCalendarStore(this._database);

  @override
  Future<void> replaceWindow(CalendarReply reply) async {
    final db = await _database.open();
    final from = reply.from.toIso8601String();
    final to = reply.to.toIso8601String();
    await db.transaction((txn) async {
      // DeskPlan's rule: an event touches the window when it starts before
      // `to` and ends at or after `from`. UTC ISO text sorts like the times.
      await txn.delete(
        _events,
        where: 'feedId IS NULL AND start < ? AND end >= ?',
        whereArgs: [to, from],
      );
      for (final e in reply.events) {
        await txn.insert(
          _events,
          e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.delete(_window);
      await txn.insert(_window, {
        'id': '',
        'fromTime': from,
        'toTime': to,
        'serverTime': reply.serverTime.toIso8601String(),
      });
    });
  }

  /// Every event, without the courses the user hid (feed_courses): the
  /// calendar and exam reminders both read this.
  @override
  Future<List<CalendarEvent>> events() async {
    final db = await _database.open();
    final rows = await db.rawQuery('''
      SELECT e.* FROM $_events e
      LEFT JOIN ${AppDatabase.feedCoursesTable} c
        ON c.feedId = e.feedId AND c.key = e.courseKey
      WHERE c.hidden IS NULL OR c.hidden = 0
      ORDER BY e.start ASC, e.end ASC
    ''');
    return rows.map(CalendarEvent.fromMap).toList();
  }

  @override
  Future<void> replaceFeed(
    String feedId,
    List<CalendarEvent> events,
    DateTime fetchedAt,
  ) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.delete(_events, where: 'feedId = ?', whereArgs: [feedId]);
      for (final e in events) {
        await txn.insert(
          _events,
          e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final at = fetchedAt.toUtc().toIso8601String();
      await txn.delete(_window);
      await txn.insert(_window, {
        'id': '',
        'fromTime': at,
        'toTime': at,
        'serverTime': at,
      });
    });
  }

  @override
  Future<List<CalendarEvent>> feedEvents(String feedId) async {
    final db = await _database.open();
    final rows = await db.query(
      _events,
      where: 'feedId = ?',
      whereArgs: [feedId],
      orderBy: 'start ASC',
    );
    return rows.map(CalendarEvent.fromMap).toList();
  }

  @override
  Future<void> removeFeed(String feedId) async {
    final db = await _database.open();
    await db.delete(_events, where: 'feedId = ?', whereArgs: [feedId]);
  }

  @override
  Future<void> clearFromPc() async {
    final db = await _database.open();
    await db.delete(_events, where: 'feedId IS NULL');
  }

  @override
  Future<DateTime?> asOf() async {
    final db = await _database.open();
    final rows = await db.query(_window, where: 'id = ?', whereArgs: ['']);
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['serverTime'] as String);
  }

  @override
  Future<void> clear() async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.delete(_events);
      await txn.delete(_window);
    });
  }
}
