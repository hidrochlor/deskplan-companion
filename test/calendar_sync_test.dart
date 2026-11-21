import 'dart:convert';

import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/core/task_storage.dart';
import 'package:deskplan_companion/features/calendar/calendar_event.dart';
import 'package:deskplan_companion/features/calendar/calendar_event_kind.dart';
import 'package:deskplan_companion/features/calendar/calendar_fetcher.dart';
import 'package:deskplan_companion/features/calendar/calendar_service.dart';
import 'package:deskplan_companion/features/calendar/exam_reminder_planner.dart';
import 'package:deskplan_companion/features/calendar/exam_reminders.dart';
import 'package:deskplan_companion/features/calendar/sqlite_calendar_store.dart';
import 'package:deskplan_companion/features/connection/deskplan_client.dart';
import 'package:deskplan_companion/features/connection/pc_info.dart';
import 'package:deskplan_companion/features/connection/ping_result.dart';
import 'package:deskplan_companion/features/discovery/hint_discovery.dart';
import 'package:deskplan_companion/features/files/sqlite_upload_queue.dart';
import 'package:deskplan_companion/features/files/upload_processor.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:deskplan_companion/features/queue/queue_processor.dart';
import 'package:deskplan_companion/features/queue/sqlite_action_queue.dart';
import 'package:deskplan_companion/features/queue/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_change_puller.dart';
import 'fakes/fake_connection_checker.dart';
import 'fakes/fake_deskplan_server.dart';
import 'fakes/fake_file_parts.dart';
import 'fakes/fake_uploader.dart';
import 'fakes/in_memory_pairing_store.dart';

final _token = base64.encode(List.filled(32, 7));

Map<String, Object?> _event(
  String id, {
  String kind = 'lecture',
  String title = 'Storage and Power-to-X Technologies',
  String context = 'VO · Online · Sumereder Christof',
  String start = '2026-11-05T08:45:00.000Z',
  String end = '2026-11-05T11:15:00.000Z',
}) => {
  'id': id,
  'kind': kind,
  'title': title,
  'context': context,
  'start': start,
  'end': end,
};

Map<String, Object?> _reply(
  List<Object?> events, {
  String from = '2026-10-16T12:00:00.000Z',
  String to = '2027-04-28T12:00:00.000Z',
  String serverTime = '2026-10-30T12:00:00.000Z',
}) => {'events': events, 'from': from, 'to': to, 'serverTime': serverTime};

/// Records what would be put on the phone's clock.
class _FakeExamReminders implements ExamReminders {
  final calls = <(List<CalendarEvent>, List<CalendarEvent>)>[];

  @override
  Future<void> replace(
    List<CalendarEvent> before,
    List<CalendarEvent> now,
  ) async => calls.add((before, now));
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('reading events', () {
    test('an unknown kind is shown as an event', () {
      final e = CalendarEvent.fromJson(_event('x', kind: 'workshop'));
      expect(e.kind, CalendarEventKind.event);
      expect(e.label, 'Event · VO · Online · Sumereder Christof');
    });

    test('the label is the kind, then the context if any', () {
      expect(
        CalendarEvent.fromJson(_event('a')).label,
        'Lecture · VO · Online · Sumereder Christof',
      );
      expect(
        CalendarEvent.fromJson(_event('b', kind: 'exam', context: '')).label,
        'Exam',
      );
    });

    test('an event without valid times is refused', () {
      expect(
        () => CalendarEvent.fromJson({..._event('a'), 'start': 'soon'}),
        throwsFormatException,
      );
    });
  });

  group('exam notifications', () {
    final now = DateTime.utc(2026, 10, 30, 12);
    final exam = CalendarEvent.fromJson(
      _event(
        'e',
        kind: 'exam',
        title: 'Exam: Climate Change and Dynamics',
        start: '2026-12-02T09:00:00.000Z',
        end: '2026-12-02T10:30:00.000Z',
      ),
    );

    test('an exam: 1 day and 1 hour before its start', () {
      final plan = ExamReminderPlanner.forEvents([exam], now);
      expect(plan.map((r) => r.at), [
        DateTime.utc(2026, 12, 1, 9),
        DateTime.utc(2026, 12, 2, 8),
      ]);
      expect(plan.every((r) => r.body == exam.title), true);
      expect(plan.map((r) => r.notificationId).toSet().length, 2);
    });

    test('lectures and other events never', () {
      final lecture = CalendarEvent.fromJson(_event('l'));
      final other = CalendarEvent.fromJson(_event('o', kind: 'event'));
      expect(ExamReminderPlanner.forEvents([lecture, other], now), isEmpty);
    });

    test('a time already past is skipped', () {
      final late = DateTime.utc(2026, 12, 1, 12); // after the day-before one
      final plan = ExamReminderPlanner.forEvents([exam], late);
      expect(plan.map((r) => r.at), [DateTime.utc(2026, 12, 2, 8)]);
    });
  });

  group('with a fake DeskPlan', () {
    late FakeDeskPlanServer server;
    late AppDatabase database;
    late SqliteCalendarStore store;
    late _FakeExamReminders reminders;
    late ServerCalendarFetcher fetcher;

    setUp(() async {
      server = await FakeDeskPlanServer.start();
      database = AppDatabase(path: inMemoryDatabasePath);
      store = SqliteCalendarStore(database);
      reminders = _FakeExamReminders();
      final pairing = InMemoryPairingStore(
        PairingData(
          name: 'PC',
          port: server.port,
          token: _token,
          fingerprint: FakeDeskPlanServer.fingerprintOf('test'),
          hint: '127.0.0.1',
        ),
      );
      fetcher = ServerCalendarFetcher(
        CalendarService(DeskPlanClient(pairing, HintDiscovery())),
        store,
        reminders,
      );
    });

    tearDown(() async {
      await server.stop();
      await database.close();
    });

    test(
      'asks for the default window: GET /v1/calendar, no from or to',
      () async {
        server.reply = _reply([]);
        await fetcher.fetch();
        final seen = server.requests.single;
        expect(seen.method, 'GET');
        expect(seen.path, '/v1/calendar');
        expect(seen.query, isEmpty);
        expect(seen.authorization, 'Bearer $_token');
      },
    );

    test(
      'the window is replaced: an event missing from the reply is removed',
      () async {
        server.reply = _reply([_event('a'), _event('b')]);
        await fetcher.fetch();
        expect((await store.events()).map((e) => e.id), ['a', 'b']);

        server.reply = _reply([
          _event(
            'b',
            title: 'Moved',
            start: '2026-11-06T08:45:00.000Z',
            end: '2026-11-06T11:15:00.000Z',
          ),
          _event('c'),
        ]);
        final outcome = await fetcher.fetch();

        expect(outcome.updated, true);
        final events = await store.events();
        expect(events.map((e) => e.id), ['c', 'b']);
        expect(events.last.title, 'Moved');
      },
    );

    test('events outside the new window are kept', () async {
      server.reply = _reply([
        _event(
          'old',
          start: '2026-10-01T08:00:00.000Z',
          end: '2026-10-01T09:00:00.000Z',
        ),
      ], from: '2026-09-20T00:00:00.000Z');
      await fetcher.fetch();
      server.reply = _reply([_event('a')]);
      await fetcher.fetch();
      expect((await store.events()).map((e) => e.id), ['old', 'a']);
    });

    test('kept for offline, with the time DeskPlan built the reply', () async {
      server.reply = _reply([_event('a')]);
      await fetcher.fetch();
      await server.stop(); // the PC is gone

      final outcome = await fetcher.fetch();
      expect(outcome.updated, false);
      expect(outcome.blocked, isNotNull);
      expect((await store.events()).single.id, 'a');
      expect(await store.asOf(), DateTime.utc(2026, 10, 30, 12));

      // Survives the app closing too: a new store on the same database.
      expect((await SqliteCalendarStore(database).events()).single.id, 'a');
    });

    test('404: an older DeskPlan, the events are hidden', () async {
      server.reply = _reply([_event('a')]);
      await fetcher.fetch();
      server
        ..status = 404
        ..reply = {'error': 'not-found'};

      final outcome = await fetcher.fetch();
      expect(outcome.unsupported, true);
      expect(await store.events(), isEmpty);
      expect(await store.asOf(), null);
    });

    test('503: kept, and tried again at the next sync', () async {
      server.reply = _reply([_event('a')]);
      await fetcher.fetch();
      server
        ..status = 503
        ..reply = {'error': 'app-not-ready'};

      final outcome = await fetcher.fetch();
      expect(outcome.failure, isNotNull);
      expect((await store.events()).single.id, 'a');
    });

    test('exam notifications follow the cached events', () async {
      server.reply = _reply([
        _event(
          'x',
          kind: 'exam',
          start: '2027-01-10T09:00:00.000Z',
          end: '2027-01-10T10:00:00.000Z',
        ),
      ]);
      await fetcher.fetch();
      server.reply = _reply([]);
      await fetcher.fetch();

      expect(reminders.calls.length, 2);
      expect(reminders.calls.first.$2.single.id, 'x');
      // The second reply drops it: its notifications are cancelled.
      expect(reminders.calls.last.$1.single.id, 'x');
      expect(reminders.calls.last.$2, isEmpty);
    });
  });

  group('in a sync', () {
    late AppDatabase database;
    late _FakeFetcher calendar;

    setUp(() {
      database = AppDatabase(path: inMemoryDatabasePath);
      calendar = _FakeFetcher();
    });

    tearDown(() => database.close());

    SyncService service(Set<String> features) {
      final checker = FakeConnectionChecker()
        ..result = PingOk(
          PcInfo(
            name: 'PC',
            version: '1',
            destinations: const [],
            features: features,
          ),
        );
      return SyncService(
        checker,
        QueueProcessor(
          queue: SqliteActionQueue(database),
          repository: TaskStorage(database),
          uploader: FakeUploader(),
        ),
        UploadProcessor(
          queue: SqliteUploadQueue(database),
          uploader: FakeFileUploader(),
          files: FakeLocalFileStore(),
        ),
        FakeChangePuller(),
        calendar: calendar,
      );
    }

    test('fetched only while the ping lists calendar', () async {
      final on = service({'notes', 'calendar'});
      addTearDown(on.dispose);
      await on.syncNow();
      expect(calendar.calls, ['fetch']);

      final off = service({'notes'});
      addTearDown(off.dispose);
      await off.syncNow();
      expect(calendar.calls, ['fetch', 'hide']);
    });
  });
}

class _FakeFetcher implements CalendarFetcher {
  final calls = <String>[];

  @override
  Future<CalendarOutcome> fetch() async {
    calls.add('fetch');
    return const CalendarOutcome(updated: true);
  }

  @override
  Future<void> hide() async => calls.add('hide');
}
