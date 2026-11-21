import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the one app database and creates its tables.
/// Version 2 added the `sync_queue` table, version 3 the `uploads` table,
/// version 4 the `kind`, `parentId` and `placeKnown` columns on tasks,
/// version 5 the `details` (DeskPlan's description) and `createdAt` columns,
/// version 6 the `doc` column (a note's formatted text, as JSON), version 7
/// the `course`, `courseKnown` and `source` columns and the `calendar_events`
/// table, version 8 the `course` column on calendar events, version 9 the
/// `repeat` and `repeatKnown` columns on tasks, version 10 the `feeds` and
/// `feed_courses` tables and the `feedId` and `courseKey` columns on calendar
/// events.
class AppDatabase {
  static const tasksTable = 'tasks';
  static const queueTable = 'sync_queue';
  static const uploadsTable = 'uploads';
  static const eventsTable = 'calendar_events';
  static const windowTable = 'calendar_window';
  static const feedsTable = 'feeds';
  static const feedCoursesTable = 'feed_courses';

  /// Pass a [path] only in tests (for example `inMemoryDatabasePath`).
  final String? path;
  Database? _db;

  AppDatabase({this.path});

  Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;
    final dbPath =
        path ?? p.join(await getDatabasesPath(), 'deskplan_companion.db');
    final db = await openDatabase(
      dbPath,
      version: 10,
      onCreate: (db, _) async {
        await _createTasks(db);
        await _createQueue(db);
        await _createUploads(db);
        await _createEvents(db);
        await _createFeeds(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createQueue(db);
        if (oldVersion < 3) await _createUploads(db);
        if (oldVersion < 4) await _addPlaceToTasks(db);
        if (oldVersion < 5) await _addNotesToTasks(db);
        if (oldVersion < 6) await _addDocToTasks(db);
        if (oldVersion < 7) {
          await _addCourseToTasks(db);
          await _createEvents(db);
        }
        if (oldVersion == 7) await _addCourseToEvents(db);
        if (oldVersion < 9) await _addRepeatToTasks(db);
        if (oldVersion >= 7 && oldVersion < 10) await _addFeedToEvents(db);
        if (oldVersion < 10) await _createFeeds(db);
      },
    );
    _db = db;
    return db;
  }

  /// Closes the database. Mainly for tests, so each one starts empty.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _createTasks(Database db) => db.execute('''
    CREATE TABLE $tasksTable (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      start TEXT,
      end TEXT,
      done INTEGER NOT NULL DEFAULT 0,
      updatedAt TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'task',
      parentId TEXT,
      placeKnown INTEGER NOT NULL DEFAULT 1,
      details TEXT NOT NULL DEFAULT '',
      detailsKnown INTEGER NOT NULL DEFAULT 1,
      detailsEdited INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT,
      createdKnown INTEGER NOT NULL DEFAULT 0,
      doc TEXT,
      course TEXT,
      courseKnown INTEGER NOT NULL DEFAULT 0,
      source TEXT,
      repeat TEXT,
      repeatKnown INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // What DeskPlan says: the item's course, and the feed it was imported from
  // (as JSON). Items saved before do not know their course yet
  // (courseKnown = 0), so their top-level folder stands in until a pull.
  Future<void> _addCourseToTasks(Database db) async {
    await db.execute('ALTER TABLE $tasksTable ADD COLUMN course TEXT');
    await db.execute(
      'ALTER TABLE $tasksTable ADD COLUMN courseKnown INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE $tasksTable ADD COLUMN source TEXT');
  }

  // The read-only calendar events of the last window fetched from DeskPlan
  // (protocol.md section 5 "GET /v1/calendar"), kept to show offline. Times
  // are UTC ISO text. One row, id '', in `calendar_window` says which window
  // they are and when DeskPlan built the reply.
  Future<void> _createEvents(Database db) async {
    await db.execute('''
      CREATE TABLE $eventsTable (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        context TEXT NOT NULL DEFAULT '',
        start TEXT NOT NULL,
        end TEXT NOT NULL,
        course TEXT,
        feedId TEXT,
        courseKey TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $windowTable (
        id TEXT PRIMARY KEY,
        fromTime TEXT NOT NULL,
        toTime TEXT NOT NULL,
        serverTime TEXT NOT NULL
      )
    ''');
  }

  // How an item repeats (JSON), and whether DeskPlan's rule is known: items
  // saved before do not know it, so they send none until a pull tells them.
  Future<void> _addRepeatToTasks(Database db) async {
    await db.execute('ALTER TABLE $tasksTable ADD COLUMN repeat TEXT');
    await db.execute(
      'ALTER TABLE $tasksTable ADD COLUMN repeatKnown INTEGER NOT NULL DEFAULT 0',
    );
  }

  // Events the phone downloads itself carry their feed and the course's key
  // (to hide the courses the user hid); DeskPlan's own (GET /v1/calendar)
  // have neither.
  Future<void> _addFeedToEvents(Database db) async {
    await db.execute('ALTER TABLE $eventsTable ADD COLUMN feedId TEXT');
    await db.execute('ALTER TABLE $eventsTable ADD COLUMN courseKey TEXT');
  }

  // The calendar feeds shared with DeskPlan (protocol.md section 5,
  // `/v1/feed-settings`) and which
  // of their courses are hidden. `dirty` marks a change DeskPlan has not had
  // yet. The addresses are not here: they are in secure storage.
  Future<void> _createFeeds(Database db) async {
    await db.execute('''
      CREATE TABLE $feedsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL DEFAULT 'calendar',
        host TEXT NOT NULL DEFAULT '',
        removed INTEGER NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0,
        lastFetched TEXT,
        lastError TEXT,
        count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE $feedCoursesTable (
        feedId TEXT NOT NULL,
        key TEXT NOT NULL,
        hidden INTEGER NOT NULL,
        updatedAt TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (feedId, key)
      )
    ''');
  }

  // The course a lecture or exam belongs to (null: use the title). Events
  // fetched before keep null until the next fetch replaces them.
  Future<void> _addCourseToEvents(Database db) =>
      db.execute('ALTER TABLE $eventsTable ADD COLUMN course TEXT');

  // Notes: their formatted text. Tasks and assignments leave it empty.
  Future<void> _addDocToTasks(Database db) =>
      db.execute('ALTER TABLE $tasksTable ADD COLUMN doc TEXT');

  // Tasks saved before this version do not know where they live on DeskPlan
  // (placeKnown = 0), so editing one never moves it: the place is only sent
  // once it has been read from DeskPlan or chosen on the phone.
  Future<void> _addPlaceToTasks(Database db) async {
    await db.execute(
      "ALTER TABLE $tasksTable ADD COLUMN kind TEXT NOT NULL DEFAULT 'task'",
    );
    await db.execute('ALTER TABLE $tasksTable ADD COLUMN parentId TEXT');
    await db.execute(
      'ALTER TABLE $tasksTable ADD COLUMN placeKnown INTEGER NOT NULL DEFAULT 0',
    );
  }

  // Details and a creation time. Tasks saved before do not know DeskPlan's
  // description (so it is not sent back) and have no creation time, so their
  // last edit stands in for it until DeskPlan's arrives.
  Future<void> _addNotesToTasks(Database db) async {
    await db.execute(
      "ALTER TABLE $tasksTable ADD COLUMN details TEXT NOT NULL DEFAULT ''",
    );
    await db.execute('ALTER TABLE $tasksTable ADD COLUMN createdAt TEXT');
    await db.execute(
      'ALTER TABLE $tasksTable ADD COLUMN detailsKnown INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE $tasksTable ADD COLUMN detailsEdited INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE $tasksTable ADD COLUMN createdKnown INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'UPDATE $tasksTable SET createdAt = updatedAt WHERE createdAt IS NULL',
    );
  }

  // One row per task: a newer action for the same task replaces the old one.
  // `seq` grows with every replace, so we can tell a stale row from a fresh one.
  Future<void> _createQueue(Database db) => db.execute('''
    CREATE TABLE $queueTable (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      taskId TEXT NOT NULL UNIQUE,
      type TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      nextAttemptAt INTEGER NOT NULL,
      lastError TEXT
    )
  ''');

  // One row per shared file. `status` is waiting, failed (DeskPlan refused it
  // or it ran out of tries; the user can retry or delete) or sent (kept for a
  // short history). The file itself lives at `localPath` until it is sent.
  Future<void> _createUploads(Database db) => db.execute('''
    CREATE TABLE $uploadsTable (
      uploadId TEXT PRIMARY KEY,
      localPath TEXT NOT NULL,
      displayName TEXT NOT NULL,
      destId TEXT NOT NULL,
      sizeBytes INTEGER NOT NULL,
      status TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      nextAttemptAt INTEGER NOT NULL,
      lastError TEXT,
      createdAt INTEGER NOT NULL,
      sentAt INTEGER
    )
  ''');
}
