import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/app_database.dart';
import 'phone_feed.dart';

/// Where feed addresses are kept. Android's encrypted storage in the app;
/// a map in tests.
abstract class FeedUrlStore {
  Future<String?> read(String feedId);
  Future<void> write(String feedId, String url);
  Future<void> delete(String feedId);
}

class SecureFeedUrlStore implements FeedUrlStore {
  final FlutterSecureStorage _storage;

  SecureFeedUrlStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static String _key(String id) => 'feed_url_$id';

  @override
  Future<String?> read(String feedId) => _storage.read(key: _key(feedId));

  @override
  Future<void> write(String feedId, String url) =>
      _storage.write(key: _key(feedId), value: url);

  @override
  Future<void> delete(String feedId) => _storage.delete(key: _key(feedId));
}

class MemoryFeedUrlStore implements FeedUrlStore {
  final urls = <String, String>{};

  @override
  Future<String?> read(String feedId) async => urls[feedId];

  @override
  Future<void> write(String feedId, String url) async => urls[feedId] = url;

  @override
  Future<void> delete(String feedId) async => urls.remove(feedId);
}

/// The feeds and course choices kept on the phone (protocol.md section 5,
/// `/v1/feed-settings`).
class FeedStore {
  static const _feeds = AppDatabase.feedsTable;
  static const _courses = AppDatabase.feedCoursesTable;
  final AppDatabase _database;
  final FeedUrlStore urls;

  FeedStore(this._database, this.urls);

  /// Every feed, removed ones included, A-Z.
  Future<List<PhoneFeed>> all() async {
    final db = await _database.open();
    final rows = await db.query(_feeds, orderBy: 'name COLLATE NOCASE');
    return rows.map(PhoneFeed.fromMap).toList();
  }

  /// The feeds to show and download.
  Future<List<PhoneFeed>> active() async =>
      (await all()).where((f) => !f.removed).toList();

  Future<PhoneFeed?> get(String id) async {
    final db = await _database.open();
    final rows = await db.query(_feeds, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : PhoneFeed.fromMap(rows.first);
  }

  Future<void> save(PhoneFeed feed) async {
    final db = await _database.open();
    await db.insert(
      _feeds,
      feed.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Forgets a feed for good: its row, address and course choices.
  Future<void> forget(String id) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.delete(_feeds, where: 'id = ?', whereArgs: [id]);
      await txn.delete(_courses, where: 'feedId = ?', whereArgs: [id]);
    });
    await urls.delete(id);
  }

  Future<List<CourseChoice>> choices() async {
    final db = await _database.open();
    final rows = await db.query(_courses);
    return rows.map(CourseChoice.fromMap).toList();
  }

  Future<void> saveChoice(CourseChoice choice) async {
    final db = await _database.open();
    await db.insert(
      _courses,
      choice.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// DeskPlan's choices, as it answered them, replace the phone's.
  Future<void> replaceChoices(List<CourseChoice> choices) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.delete(_courses);
      for (final c in choices) {
        await txn.insert(
          _courses,
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// How many changes wait for DeskPlan (for "N changes waiting to sync").
  Future<int> dirtyCount() async {
    final db = await _database.open();
    final a = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_feeds WHERE dirty = 1'),
    );
    final b = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_courses WHERE dirty = 1'),
    );
    return (a ?? 0) + (b ?? 0);
  }
}
