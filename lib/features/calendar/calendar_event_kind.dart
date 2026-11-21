/// What a calendar event is (protocol.md section 5 "GET /v1/calendar").
/// Anything else a feed sends is shown as an [event].
enum CalendarEventKind {
  lecture('Lecture'),
  exam('Exam'),
  event('Event');

  /// The label shown before the event's context ("Lecture · VO · Online").
  final String label;
  const CalendarEventKind(this.label);

  /// Reads the wire name. An unknown or missing kind is an [event].
  static CalendarEventKind fromWire(Object? name) => switch (name) {
    'lecture' => lecture,
    'exam' => exam,
    _ => event,
  };
}
