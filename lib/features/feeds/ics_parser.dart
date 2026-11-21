import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One event of a feed, as the feed says it. Times are UTC; [end] is null
/// for a single moment. A repeating event gives one entry per occurrence,
/// with [uid] `<uid>|<original start>` as DeskPlan makes it
/// (main/calendar/IcsParser.js), so both name each occurrence the same.
class FeedEntry {
  final String uid;
  final String summary;
  final String description;
  final String location;
  final String categories;
  final DateTime start;
  final DateTime? end;

  const FeedEntry({
    required this.uid,
    required this.summary,
    this.description = '',
    this.location = '',
    this.categories = '',
    required this.start,
    this.end,
  });
}

/// A whole feed: its name, the program that made it (which picks how its
/// events are read, see feed_mappers.dart) and its events.
class ParsedFeed {
  final String name;
  final String producer;
  final List<FeedEntry> events;

  const ParsedFeed(this.name, this.producer, this.events);
}

/// Reads iCal text (.ics) the way DeskPlan does: folded lines, escaped text,
/// times in the feed's own zones (TZID), all-day dates, cancelled events
/// left out, and repeating events (RRULE with EXDATE, and RECURRENCE-ID for
/// a moved or cancelled occurrence) expanded up to about a year ahead.
///
/// RRULE: FREQ, INTERVAL, COUNT, UNTIL, and BYDAY for weekly rules. A rule
/// with other parts is shown at its first time only, never at wrong ones.
class IcsParser {
  static const maxOccurrences = 400;
  static const horizon = Duration(days: 400);

  static bool _zonesLoaded = false;

  /// Throws [FormatException] when [text] is not an iCal calendar.
  static ParsedFeed parse(String text, {DateTime? now}) {
    if (!RegExp(r'^\s*BEGIN:VCALENDAR', caseSensitive: false).hasMatch(text)) {
      throw const FormatException('This address did not return a calendar.');
    }
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n[ \t]'), '')
        .split('\n');

    var name = '';
    var producer = '';
    final events = <_Event>[];
    _Event? current;
    var depth = 0; // inside VEVENT: sub-components (VALARM) are skipped
    for (final line in lines) {
      final p = _Property.parse(line);
      if (p == null) continue;
      if (p.name == 'BEGIN') {
        if (p.value.toUpperCase() == 'VEVENT' && current == null) {
          current = _Event();
        } else if (current != null) {
          depth++;
        }
        continue;
      }
      if (p.name == 'END') {
        if (current != null && depth > 0) {
          depth--;
        } else if (current != null && p.value.toUpperCase() == 'VEVENT') {
          events.add(current);
          current = null;
        }
        continue;
      }
      if (current != null) {
        if (depth == 0) current.add(p);
      } else if (p.name == 'PRODID') {
        producer = p.text.trim();
      } else if (p.name == 'X-WR-CALNAME') {
        name = p.text.trim();
      }
    }

    final at = (now ?? DateTime.now()).toUtc();
    final out = <FeedEntry>[];
    final overrides = <String, List<_Event>>{};
    final plain = <_Event>[];
    for (final e in events) {
      if (e.uid.isEmpty || e.start == null) continue;
      if (e.recurrenceId != null) {
        overrides.putIfAbsent(e.uid, () => []).add(e);
      } else if (!e.cancelled) {
        plain.add(e);
      }
    }
    final used = <String>{};
    for (final e in plain) {
      final rule = e.rrule;
      if (rule == null) {
        out.add(e.entry(e.uid, e.start!.utc, e.singleEnd));
        continue;
      }
      final own = overrides[e.uid] ?? const [];
      if (own.isNotEmpty) used.add(e.uid);
      out.addAll(_occurrences(e, rule, own, at));
    }
    // A change whose repeating event is not in the feed still happens.
    for (final MapEntry(key: uid, value: own) in overrides.entries) {
      if (used.contains(uid)) continue;
      for (final o in own) {
        if (o.cancelled) continue;
        out.add(
          o.entry('$uid|${_iso(o.recurrenceId!.utc)}', o.start!.utc, o.endUtc),
        );
      }
    }
    return ParsedFeed(name, producer, out);
  }

  static List<FeedEntry> _occurrences(
    _Event e,
    Map<String, String> rule,
    List<_Event> overrides,
    DateTime now,
  ) {
    final start = e.start!;
    final length = e.endUtc?.difference(start.utc);
    final excluded = {for (final x in e.exdates) x.utc};
    final changed = <DateTime, _Event>{
      for (final o in overrides) o.recurrenceId!.utc: o,
    };
    final out = <FeedEntry>[];
    for (final original in _expand(start, rule, now.add(horizon))) {
      if (out.length >= maxOccurrences) break;
      if (excluded.contains(original)) continue;
      final uid = '${e.uid}|${_iso(original)}';
      final o = changed[original];
      if (o != null) {
        if (!o.cancelled) out.add(o.entry(uid, o.start!.utc, o.endUtc));
        continue;
      }
      final end = length == null || length <= Duration.zero
          ? null
          : original.add(length);
      out.add(e.entry(uid, original, end));
    }
    return out;
  }

  /// The UTC starts of a repeating event, in its own zone's wall time (a
  /// 9:00 lecture stays at 9:00 across a clock change), up to [until].
  static Iterable<DateTime> _expand(
    _Time start,
    Map<String, String> rule,
    DateTime until,
  ) sync* {
    final freq = rule['FREQ'];
    final interval = int.tryParse(rule['INTERVAL'] ?? '1') ?? 1;
    final count = int.tryParse(rule['COUNT'] ?? '');
    final ruleUntil = rule['UNTIL'] == null
        ? null
        : _Time.parse(rule['UNTIL']!, null, dateOnly: false)?.utc;
    final known = {'FREQ', 'INTERVAL', 'COUNT', 'UNTIL', 'WKST'};
    if (freq == 'WEEKLY') known.add('BYDAY');
    final simple =
        rule.keys.every(known.contains) &&
        {'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'}.contains(freq) &&
        interval >= 1;
    if (!simple) {
      yield start.utc;
      return;
    }
    const days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    final byDay =
        (rule['BYDAY']?.split(',') ?? const <String>[])
            .map((d) => days.indexOf(d.trim().toUpperCase()) + 1)
            .where((d) => d > 0)
            .toList()
          ..sort();
    final w = start.wall;
    var made = 0;
    bool done(DateTime t) =>
        (count != null && made >= count) ||
        (ruleUntil != null && t.isAfter(ruleUntil)) ||
        t.isAfter(until) ||
        made >= maxOccurrences * 4;

    if (freq == 'WEEKLY' && byDay.isNotEmpty) {
      // The week of the first time, from its Monday, then every `interval`.
      final monday = DateTime.utc(w.year, w.month, w.day - (w.weekday - 1));
      for (var week = 0; ; week += interval) {
        for (final d in byDay) {
          final day = monday.add(Duration(days: week * 7 + d - 1));
          final t = start.at(day.year, day.month, day.day);
          if (t.isBefore(start.utc)) continue;
          if (done(t)) return;
          made++;
          yield t;
        }
      }
    }
    for (var i = 0; ; i++) {
      final DateTime t;
      switch (freq) {
        case 'DAILY':
          t = start.at(w.year, w.month, w.day + i * interval);
        case 'WEEKLY':
          t = start.at(w.year, w.month, w.day + 7 * i * interval);
        case 'MONTHLY':
          final m = DateTime.utc(w.year, w.month + i * interval);
          // A day the month does not have is skipped (RFC 5545).
          if (DateTime.utc(m.year, m.month + 1, 0).day < w.day) continue;
          t = start.at(m.year, m.month, w.day);
        default:
          final y = w.year + i * interval;
          if (DateTime.utc(y, w.month + 1, 0).day < w.day) continue;
          t = start.at(y, w.month, w.day);
      }
      if (done(t)) return;
      made++;
      yield t;
    }
  }

  static void _loadZones() {
    if (_zonesLoaded) return;
    try {
      tz.getLocation('UTC');
    } catch (_) {
      tzdata.initializeTimeZones();
    }
    _zonesLoaded = true;
  }

  static tz.Location? _zone(String? id) {
    if (id == null || id.isEmpty) return null;
    _loadZones();
    try {
      return tz.getLocation(id.replaceAll('"', ''));
    } catch (_) {
      return null; // a zone the database does not know: read as phone time
    }
  }
}

String _iso(DateTime t) => t.toUtc().toIso8601String();

/// One content line: NAME;PARAM=VALUE:value.
class _Property {
  final String name;
  final Map<String, String> params;
  final String value;

  _Property(this.name, this.params, this.value);

  static _Property? parse(String line) {
    if (line.isEmpty) return null;
    // The value starts after the first colon outside a quoted parameter.
    var quoted = false;
    var colon = -1;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') quoted = !quoted;
      if (ch == ':' && !quoted) {
        colon = i;
        break;
      }
    }
    if (colon < 0) return null;
    final head = line.substring(0, colon).split(';');
    final params = <String, String>{};
    for (final part in head.skip(1)) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        params[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1);
      }
    }
    return _Property(
      head.first.toUpperCase(),
      params,
      line.substring(colon + 1),
    );
  }

  /// The value as text: \n, \, \; and \\ unescaped.
  String get text => value.replaceAllMapped(
    RegExp(r'\\([nN,;\\])'),
    (m) => m[1] == 'n' || m[1] == 'N' ? '\n' : m[1]!,
  );
}

/// A start or end: the instant, and how to make another time on another day
/// at the same wall-clock time in the same zone.
class _Time {
  final DateTime utc;

  /// The wall-clock time as written (components only).
  final DateTime wall;
  final tz.Location? zone;
  final bool floating;
  final bool dateOnly;

  _Time(
    this.utc,
    this.wall,
    this.zone, {
    this.floating = false,
    this.dateOnly = false,
  });

  DateTime at(int y, int m, int d) {
    final zone = this.zone;
    if (dateOnly || floating) {
      return DateTime(y, m, d, wall.hour, wall.minute, wall.second).toUtc();
    }
    if (zone != null) {
      return tz.TZDateTime(
        zone,
        y,
        m,
        d,
        wall.hour,
        wall.minute,
        wall.second,
      ).toUtc();
    }
    return DateTime.utc(y, m, d, wall.hour, wall.minute, wall.second);
  }

  static final _form = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$',
  );

  static _Time? parse(String raw, String? tzid, {required bool dateOnly}) {
    final m = _form.firstMatch(raw.trim());
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (m[4] == null) {
      // A date: the start of that day on the phone, as DeskPlan reads it.
      final wall = DateTime.utc(y, mo, d);
      return _Time(DateTime(y, mo, d).toUtc(), wall, null, dateOnly: true);
    }
    final h = int.parse(m[4]!),
        mi = int.parse(m[5]!),
        s = int.parse(m[6] ?? '0');
    final wall = DateTime.utc(y, mo, d, h, mi, s);
    if (m[7] != null) return _Time(wall, wall, null);
    final zone = IcsParser._zone(tzid);
    if (zone != null) {
      return _Time(tz.TZDateTime(zone, y, mo, d, h, mi, s).toUtc(), wall, zone);
    }
    return _Time(
      DateTime(y, mo, d, h, mi, s).toUtc(),
      wall,
      null,
      floating: true,
    );
  }
}

class _Event {
  String uid = '';
  String summary = '';
  String description = '';
  String location = '';
  final categories = <String>[];
  bool cancelled = false;
  _Time? start;
  _Time? end;
  Duration? duration;
  _Time? recurrenceId;
  Map<String, String>? rrule;
  final exdates = <_Time>[];

  void add(_Property p) {
    final dateOnly = p.params['VALUE']?.toUpperCase() == 'DATE';
    _Time? time(String v) =>
        _Time.parse(v, p.params['TZID'], dateOnly: dateOnly);
    switch (p.name) {
      case 'UID':
        uid = p.text.trim();
      case 'SUMMARY':
        summary = _clean(p.text);
      case 'DESCRIPTION':
        description = _clean(p.text);
      case 'LOCATION':
        location = _clean(p.text);
      case 'CATEGORIES':
        categories.addAll(
          p.value
              .split(RegExp(r'(?<!\\),'))
              .map((c) => _Property('', const {}, c).text.trim())
              .where((c) => c.isNotEmpty),
        );
      case 'STATUS':
        cancelled = p.value.trim().toUpperCase() == 'CANCELLED';
      case 'DTSTART':
        start = time(p.value);
      case 'DTEND':
        end = time(p.value);
      case 'DURATION':
        duration = _duration(p.value.trim());
      case 'RECURRENCE-ID':
        recurrenceId = time(p.value);
      case 'RRULE':
        rrule = {
          for (final part in p.value.split(';'))
            if (part.contains('='))
              part.substring(0, part.indexOf('=')).toUpperCase(): part
                  .substring(part.indexOf('=') + 1),
        };
      case 'EXDATE':
        exdates.addAll(p.value.split(',').map(time).whereType<_Time>());
    }
  }

  /// The end of an event that does not repeat, as ical.js gives it to
  /// DeskPlan: DTEND, or DTSTART plus DURATION, or the next day for a
  /// date, or the start itself (a single moment).
  DateTime? get singleEnd {
    final s = start!;
    if (end != null) return end!.utc;
    if (duration != null) return s.utc.add(duration!);
    if (s.dateOnly) return s.at(s.wall.year, s.wall.month, s.wall.day + 1);
    return s.utc;
  }

  /// The end of an occurrence or a changed one: null when it has no length.
  DateTime? get endUtc {
    final e = end?.utc ?? (duration == null ? null : start!.utc.add(duration!));
    return e == null || !e.isAfter(start!.utc) ? null : e;
  }

  FeedEntry entry(String id, DateTime from, DateTime? to) => FeedEntry(
    uid: id,
    summary: summary,
    description: description,
    location: location,
    categories: categories.join(', '),
    start: from,
    end: to,
  );

  static String _clean(String s) => s.replaceAll('\r', '').trim();

  /// "PT1H30M", "P1D": enough for event lengths.
  static Duration? _duration(String v) {
    final m = RegExp(
      r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    ).firstMatch(v);
    if (m == null) return null;
    int n(int i) => int.tryParse(m[i] ?? '') ?? 0;
    final d = Duration(
      days: n(2) * 7 + n(3),
      hours: n(4),
      minutes: n(5),
      seconds: n(6),
    );
    return m[1] == '-' ? -d : d;
  }
}
