import 'calendar_event.dart';

/// DeskPlan's answer to `GET /v1/calendar`: the complete set of events for
/// the window it used (protocol.md section 5). Events missing from it no
/// longer exist.
class CalendarReply {
  final List<CalendarEvent> events;

  /// The window DeskPlan actually used.
  final DateTime from;
  final DateTime to;

  /// DeskPlan's clock when it built the reply, shown as "as of".
  final DateTime serverTime;

  const CalendarReply({
    required this.events,
    required this.from,
    required this.to,
    required this.serverTime,
  });

  /// Reads the reply. Throws [FormatException] if any part is wrong: then
  /// nothing is replaced and the cached events stay.
  factory CalendarReply.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Not a calendar reply');
    DateTime time(String key) {
      final v = json[key];
      final t = v is String ? DateTime.tryParse(v) : null;
      if (t == null) throw FormatException('The calendar has no valid $key');
      return t.toUtc();
    }

    final raw = json['events'];
    if (raw is! List) throw const FormatException('The calendar has no events');
    return CalendarReply(
      events: raw.map(CalendarEvent.fromJson).toList(),
      from: time('from'),
      to: time('to'),
      serverTime: time('serverTime'),
    );
  }
}
