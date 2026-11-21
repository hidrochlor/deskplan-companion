import 'dart:convert';
import 'dart:io';

import 'package:deskplan_companion/features/feeds/feed_mappers.dart';
import 'package:deskplan_companion/features/feeds/ics_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// The PC's own sample feeds, and what DeskPlan's parser and mappers make of
/// them (test/fixtures/feeds-expected.json, written by DeskPlan's code), so
/// the phone is checked against the PC rather than against itself.
final _now = DateTime.utc(2026, 10, 30, 12);

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  final expected =
      jsonDecode(_fixture('feeds-expected.json')) as Map<String, dynamic>;

  for (final name in ['stundenplan-sample.ics', 'moodle-sample.ics']) {
    test('$name reads exactly as DeskPlan reads it', () {
      final want = expected[name] as Map<String, dynamic>;
      final parsed = IcsParser.parse(_fixture(name), now: _now);
      final kind = FeedKind.ofProducer(parsed.producer);
      expect(parsed.name, want['name']);
      expect(kind.name, want['kind']);
      final got = [
        for (final e in parsed.events)
          () {
            final m = FeedMappers.map(kind, e);
            return {
              'uid': e.uid,
              'start': e.start.toIso8601String(),
              'end': e.end?.toIso8601String(),
              'type': m.type.name,
              'title': m.title,
              'course': m.course,
              'context': m.context,
            };
          }(),
      ];
      // Fields DeskPlan leaves out for some types are '' on both.
      final wantEvents = [
        for (final e in want['events'] as List)
          {
            ...(e as Map<String, dynamic>),
            if ((e['type'] as String) == 'skip') ...{
              'title': '',
              'course': '',
              'context': '',
            },
          },
      ];
      expect(got, wantEvents);
    });
  }

  test(
    'a weekly repeat, a moved and a cancelled occurrence, and a lone change',
    () {
      const ics =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:x\r\n'
          'BEGIN:VEVENT\r\nUID:w1\r\nSUMMARY:Gym\r\nLOCATION:Hall A\r\n'
          'DTSTART:20261102T170000Z\r\nDTEND:20261102T180000Z\r\n'
          'RRULE:FREQ=WEEKLY;COUNT=3\r\nEND:VEVENT\r\n'
          'BEGIN:VEVENT\r\nUID:w1\r\nRECURRENCE-ID:20261109T170000Z\r\n'
          'SUMMARY:Gym (moved)\r\nLOCATION:Hall B\r\n'
          'DTSTART:20261110T080000Z\r\nDTEND:20261110T090000Z\r\nEND:VEVENT\r\n'
          'BEGIN:VEVENT\r\nUID:w1\r\nRECURRENCE-ID:20261116T170000Z\r\n'
          'STATUS:CANCELLED\r\nDTSTART:20261116T170000Z\r\n'
          'DTEND:20261116T180000Z\r\nEND:VEVENT\r\n'
          'BEGIN:VEVENT\r\nUID:lone\r\nRECURRENCE-ID:20261120T100000Z\r\n'
          'SUMMARY:Extra\r\nDTSTART:20261120T120000Z\r\n'
          'DTEND:20261120T130000Z\r\nEND:VEVENT\r\n'
          'END:VCALENDAR\r\n';
      final events = IcsParser.parse(ics, now: _now).events;
      expect(
        events.map(
          (e) => [e.uid, e.summary, e.location, e.start.toIso8601String()],
        ),
        [
          [
            'w1|2026-11-02T17:00:00.000Z',
            'Gym',
            'Hall A',
            '2026-11-02T17:00:00.000Z',
          ],
          [
            'w1|2026-11-09T17:00:00.000Z',
            'Gym (moved)',
            'Hall B',
            '2026-11-10T08:00:00.000Z',
          ],
          [
            'lone|2026-11-20T10:00:00.000Z',
            'Extra',
            '',
            '2026-11-20T12:00:00.000Z',
          ],
        ],
      );
    },
  );

  test(
    'weekly BYDAY in the feed\'s zone keeps the wall time across a clock change',
    () {
      const ics =
          'BEGIN:VCALENDAR\r\nPRODID:x\r\nBEGIN:VEVENT\r\nUID:d\r\nSUMMARY:Deutsch\r\n'
          'DTSTART;TZID=Europe/Vienna:20261020T180000\r\n'
          'DTEND;TZID=Europe/Vienna:20261020T193000\r\n'
          'RRULE:FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=20261030T000000Z\r\n'
          'EXDATE;TZID=Europe/Vienna:20261022T180000\r\n'
          'END:VEVENT\r\nEND:VCALENDAR';
      final starts = IcsParser.parse(ics, now: _now).events.map((e) => e.start);
      // Vienna is UTC+2 until Oct 25, then UTC+1: still 18:00 there.
      expect(starts, [
        DateTime.utc(2026, 10, 20, 16),
        DateTime.utc(2026, 10, 27, 17),
        DateTime.utc(2026, 10, 29, 17),
      ]);
    },
  );

  test('refuses what is not a calendar', () {
    expect(() => IcsParser.parse('<html>login</html>'), throwsFormatException);
  });
}
