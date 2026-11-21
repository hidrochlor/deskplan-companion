import 'calendar_event_kind.dart';

/// One read-only event from DeskPlan's calendar feeds: a lecture, an exam or
/// another event (protocol.md section 5 "GET /v1/calendar"). It is not an
/// item: it is never edited, ticked or sent back. Times are held in UTC.
class CalendarEvent {
  /// Stable between replies. Only names the event: not an item id.
  final String id;
  final CalendarEventKind kind;

  /// Never empty.
  final String title;

  /// What DeskPlan shows after the kind (type, room, lecturer). May be empty.
  final String context;
  final DateTime start;

  /// Equals [start] for an event that is a single moment.
  final DateTime end;

  /// The course a lecture or exam belongs to, as DeskPlan names it. Null
  /// when DeskPlan did not say (an older DeskPlan, or an event of no course).
  final String? course;

  /// The feed this phone downloaded it from (protocol.md section 5,
  /// `/v1/feed-settings`), or null
  /// for an event DeskPlan sent (GET /v1/calendar).
  final String? feedId;

  CalendarEvent({
    required this.id,
    required this.kind,
    required this.title,
    this.context = '',
    required DateTime start,
    required DateTime end,
    this.course,
    this.feedId,
  }) : start = start.toUtc(),
       end = end.toUtc();

  /// "Lecture · VO · Online · Sumereder Christof", or just "Exam".
  String get label => context.isEmpty ? kind.label : '${kind.label} · $context';

  /// The name its course's sessions share: [course], or the title for an
  /// event that has none.
  String get courseName {
    final c = course;
    if (c != null && c.isNotEmpty) return c;
    return title.startsWith('Exam: ') ? title.substring(6) : title;
  }

  /// Once its end is past, an event counts as done (shown dimmed).
  bool isPast(DateTime now) => end.isBefore(now);

  /// Reads one event from DeskPlan's reply. Throws [FormatException] if it
  /// is not one.
  factory CalendarEvent.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('An event is not an object');
    final id = json['id'];
    final title = json['title'];
    final context = json['context'];
    final start = json['start'];
    final end = json['end'];
    final course = json['course'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('An event has no id');
    }
    if (title is! String) throw const FormatException('An event has no title');
    if (context != null && context is! String) {
      throw const FormatException('An event context is not text');
    }
    if (course != null && course is! String) {
      throw const FormatException('An event course is not text');
    }
    final from = start is String ? DateTime.tryParse(start) : null;
    final to = end is String ? DateTime.tryParse(end) : null;
    if (from == null || to == null) {
      throw const FormatException('An event has no valid times');
    }
    return CalendarEvent(
      id: id,
      kind: CalendarEventKind.fromWire(json['kind']),
      title: title,
      context: context as String? ?? '',
      start: from,
      end: to,
      course: course as String?,
    );
  }

  /// Database row. Times are UTC ISO text ending in "Z".
  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'context': context,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'course': course,
    'feedId': feedId,
    // How a hidden course is found (feed_courses.key): the course's name,
    // normalised as DeskPlan does (CourseFilter.courseKey).
    'courseKey': course == null ? null : courseKeyOf(course!),
  };

  /// "Climate  Change" -> "climate change".
  static String courseKeyOf(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  factory CalendarEvent.fromMap(Map<String, Object?> m) => CalendarEvent(
    id: m['id'] as String,
    kind: CalendarEventKind.fromWire(m['kind']),
    title: m['title'] as String,
    context: (m['context'] as String?) ?? '',
    start: DateTime.parse(m['start'] as String),
    end: DateTime.parse(m['end'] as String),
    course: m['course'] as String?,
    feedId: m['feedId'] as String?,
  );
}
