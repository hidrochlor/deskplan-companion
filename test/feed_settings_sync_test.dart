import 'dart:convert';
import 'dart:io';

import 'package:deskplan_companion/core/app_database.dart';
import 'package:deskplan_companion/features/calendar/sqlite_calendar_store.dart';
import 'package:deskplan_companion/features/connection/deskplan_client.dart';
import 'package:deskplan_companion/features/discovery/hint_discovery.dart';
import 'package:deskplan_companion/features/feeds/feed_fetcher.dart';
import 'package:deskplan_companion/features/feeds/feed_mappers.dart';
import 'package:deskplan_companion/features/feeds/feed_service.dart';
import 'package:deskplan_companion/features/feeds/feed_settings_sync.dart';
import 'package:deskplan_companion/features/feeds/feed_store.dart';
import 'package:deskplan_companion/features/pairing/pairing_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_deskplan_server.dart';
import 'fakes/in_memory_pairing_store.dart';

const _tt = 'https://almaty.fh-joanneum.at/stundenplan/search.php?q=Met26';
const _de = 'https://almaty.fh-joanneum.at/stundenplan/search.php?q=Deutsch';
final _now = DateTime.utc(2026, 10, 30, 12);

/// Serves the PC's sample timetable for any address; [fail] makes it fail.
class _FakeFetcher implements FeedFetcher {
  final fetched = <String>[];
  bool fail = false;

  @override
  Future<String> fetchText(String url) async {
    fetched.add(url);
    if (fail) {
      throw const FeedFetchError('The calendar server did not answer in time.');
    }
    return File('test/fixtures/stundenplan-sample.ics').readAsStringSync();
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase database;
  late SqliteCalendarStore calendar;
  late FeedService feeds;
  late _FakeFetcher fetcher;

  setUp(() {
    database = AppDatabase(path: inMemoryDatabasePath);
    calendar = SqliteCalendarStore(database);
    fetcher = _FakeFetcher();
    feeds = FeedService(
      FeedStore(database, MemoryFeedUrlStore()),
      calendar,
      fetcher,
      now: () => _now,
    );
  });

  tearDown(() => database.close());

  group('FeedService', () {
    test(
      'adding downloads it, names it as DeskPlan does, and marks it to send',
      () async {
        final feed = await feeds.add(
          'webcal://almaty.fh-joanneum.at/stundenplan/search.php?q=Met26',
        );
        expect(fetcher.fetched, [_tt]);
        expect(feed.name, 'Met26');
        expect(feed.kind, FeedKind.timetable);
        expect(feed.dirty, isTrue);
        final events = await calendar.events();
        expect(events, isNotEmpty);
        // The same ids as DeskPlan's own copy.
        expect(events.first.id, startsWith('feed:${feed.id}|MET2026_'));
        expect(await feeds.store.dirtyCount(), 1);
        expect(() => feeds.add(_tt), throwsA(isA<FeedFetchError>()));
      },
    );

    test('hiding a course hides its lectures and exams everywhere', () async {
      final feed = await feeds.add(_tt);
      final courses = await feeds.courses(feed.id);
      final climate = courses.firstWhere(
        (c) => c.name == 'Climate Change and Dynamics',
      );
      await feeds.setHidden(feed.id, [climate.key], true);
      final shown = await calendar.events();
      expect(
        shown.where((e) => e.course == 'Climate Change and Dynamics'),
        isEmpty,
      );
      expect(
        (await feeds.courses(
          feed.id,
        )).firstWhere((c) => c.key == climate.key).hidden,
        isTrue,
      );
      // Its events are still kept, only hidden.
      expect(
        (await calendar.feedEvents(
          feed.id,
        )).where((e) => e.course == 'Climate Change and Dynamics'),
        isNotEmpty,
      );
    });

    test('a failed download keeps the last copy and says why', () async {
      final feed = await feeds.add(_tt);
      final before = (await calendar.events()).length;
      fetcher.fail = true;
      expect(await feeds.refresh(feed.id), contains('in time'));
      expect((await calendar.events()).length, before);
      expect((await feeds.store.get(feed.id))!.lastError, contains('in time'));
    });

    test('removing drops its events and keeps a marker to send', () async {
      final feed = await feeds.add(_tt);
      await feeds.remove(feed.id);
      expect(await calendar.events(), isEmpty);
      expect(await feeds.store.active(), isEmpty);
      final marker = (await feeds.store.get(feed.id))!;
      expect([marker.removed, marker.dirty], [true, true]);
    });
  });

  group('FeedSettingsSync with a fake DeskPlan', () {
    late FakeDeskPlanServer server;
    late FeedSettingsSync sync;

    setUp(() async {
      server = await FakeDeskPlanServer.start();
      final pairing = InMemoryPairingStore(
        PairingData(
          name: 'PC',
          port: server.port,
          token: base64.encode(List.filled(32, 7)),
          fingerprint: FakeDeskPlanServer.fingerprintOf('test'),
          hint: '127.0.0.1',
        ),
      );
      sync = FeedSettingsSync(DeskPlanClient(pairing, HintDiscovery()), feeds);
    });

    tearDown(() => server.stop());

    test(
      'nothing changed here: it only asks, and takes DeskPlan\'s list',
      () async {
        server.reply = {
          'feeds': [
            {
              'id': 'pc-tt',
              'url': _tt,
              'name': 'Met26',
              'kind': 'timetable',
              'removed': false,
              'updatedAt': '2026-10-01T00:00:00.000Z',
            },
          ],
          'courses': [
            {
              'feedId': 'pc-tt',
              'key': 'mobility infrastructure',
              'hidden': true,
              'updatedAt': '2026-10-02T00:00:00.000Z',
            },
          ],
        };
        final outcome = await sync.run();
        expect(outcome.failure, isNull);
        expect(server.requests.single.method, 'GET');
        expect(server.requests.single.path, '/v1/feed-settings');
        final list = await feeds.store.active();
        expect(list.map((f) => [f.id, f.name, f.dirty]), [
          ['pc-tt', 'Met26', false],
        ]);
        // Downloaded straight away, with DeskPlan's hidden course left out.
        expect(fetcher.fetched, [_tt]);
        final shown = await calendar.events();
        expect(shown, isNotEmpty);
        expect(
          shown.where((e) => e.course == 'Mobility Infrastructure'),
          isEmpty,
        );
      },
    );

    test(
      'changes made here are sent; the same address takes DeskPlan\'s id',
      () async {
        final mine = await feeds.add(_tt);
        final german = await feeds.add(_de);
        await feeds.setHidden(mine.id, ['renewable energy generation'], true);
        server.reply = {
          'feeds': [
            {
              'id': 'pc-tt',
              'url': _tt,
              'name': 'Met26',
              'kind': 'timetable',
              'removed': false,
              'updatedAt': '2026-10-01T00:00:00.000Z',
            },
            {
              'id': german.id,
              'url': _de,
              'name': german.name,
              'kind': 'calendar',
              'removed': false,
              'updatedAt': _now.toIso8601String(),
            },
          ],
          'courses': [],
        };
        await sync.run();
        final sent = server.requests.single;
        expect(sent.method, 'PUT');
        expect(
          (sent.json['feeds'] as List).map((f) => (f as Map)['url']),
          unorderedEquals([_tt, _de]),
        );
        expect((sent.json['courses'] as List).single, {
          'feedId': mine.id,
          'key': 'renewable energy generation',
          'hidden': true,
          'updatedAt': _now.toIso8601String(),
        });
        final ids = (await feeds.store.active()).map((f) => f.id);
        expect(ids, unorderedEquals(['pc-tt', german.id]));
        expect(await feeds.store.dirtyCount(), 0);
        // The old id's events are gone; DeskPlan's id has them.
        expect((await calendar.feedEvents(mine.id)), isEmpty);
        expect((await calendar.feedEvents('pc-tt')), isNotEmpty);
      },
    );

    test('a feed DeskPlan removed is removed here too', () async {
      server.reply = {
        'feeds': [
          {
            'id': 'pc-tt',
            'url': _tt,
            'name': 'Met26',
            'removed': false,
            'updatedAt': '2026-10-01T00:00:00.000Z',
          },
        ],
        'courses': [],
      };
      await sync.run();
      server.reply = {
        'feeds': [
          {
            'id': 'pc-tt',
            'url': null,
            'name': 'Met26',
            'removed': true,
            'updatedAt': '2026-10-29T00:00:00.000Z',
          },
        ],
        'courses': [],
      };
      await sync.run();
      expect(await feeds.store.all(), isEmpty);
      expect(await calendar.events(), isEmpty);
    });

    test('DeskPlan unreachable: changes stay waiting', () async {
      await feeds.add(_tt);
      await server.stop();
      final outcome = await sync.run();
      expect(outcome.blocked, isNotNull);
      expect(await feeds.store.dirtyCount(), 1);
    });
  });
}
