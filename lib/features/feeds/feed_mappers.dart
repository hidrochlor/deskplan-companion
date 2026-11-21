import 'ics_parser.dart';

/// What one feed event means, read exactly as DeskPlan reads it
/// (renderer/modules/feeds/feedMappers.js), so a course is named the same on
/// both and a hidden course is hidden on both.
enum MappedType { lecture, exam, event, deadline, skip }

class MappedEvent {
  final MappedType type;
  final String title;

  /// The course name, or '' (a generic event, or a lecture that does not
  /// fit the timetable's pattern).
  final String course;

  /// What is shown after the kind: type, room, lecturer.
  final String context;

  const MappedEvent(
    this.type, {
    this.title = '',
    this.course = '',
    this.context = '',
  });
}

/// The kinds of feed DeskPlan knows, from the program that made it.
enum FeedKind {
  timetable,
  moodle,
  calendar;

  static FeedKind fromWire(Object? v) =>
      values.firstWhere((k) => k.name == v, orElse: () => calendar);

  /// The same test as DeskPlan's FeedController.kindOf.
  static FeedKind ofProducer(String producer) {
    if (RegExp('moodle', caseSensitive: false).hasMatch(producer)) {
      return moodle;
    }
    if (RegExp('FH JOANNEUM', caseSensitive: false).hasMatch(producer) &&
        RegExp('Stundenplan', caseSensitive: false).hasMatch(producer)) {
      return timetable;
    }
    return calendar;
  }

  /// The name a new feed gets: "Moodle", the calendar's own name, or its host.
  String nameFor(String calName, String host) =>
      this == moodle ? 'Moodle' : (calName.isNotEmpty ? calName : host);
}

class FeedMappers {
  static MappedEvent map(FeedKind kind, FeedEntry e) => switch (kind) {
    FeedKind.timetable => _timetable(e),
    FeedKind.moodle => _moodle(e),
    FeedKind.calendar => MappedEvent(
      MappedType.event,
      title: e.summary.isEmpty ? 'Untitled' : e.summary,
      context: roomOf(e.location).isNotEmpty ? roomOf(e.location) : e.location,
    ),
  };

  /// "WS46a WS46a.02.212" -> "WS46a.02.212". "Ohne Ort" (no place) is ''.
  static String roomOf(String location) {
    final parts = location
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != '. .')
        .toList();
    final last = parts.isEmpty ? '' : parts.last;
    if (last.isEmpty ||
        RegExp(r'^ohne ort$', caseSensitive: false).hasMatch(last)) {
      return '';
    }
    return last.split(RegExp(r'\s+')).last;
  }

  static final _lecture = RegExp(
    r'^(.*?) \((-\d+)\) \(([^()]*(?:\(([^()]*)\))?[^()]*)\),\s*([^,]*)',
  );
  static final _exam = RegExp(r'^Prüfungstermin:\s*', caseSensitive: false);
  static final _examParts = RegExp(
    r'^\S+\s+\S+\s+\S+\s+([A-Z]{2,3})\s+(.+?)\s+bei\s+([^,]*)',
  );

  static MappedEvent _timetable(FeedEntry e) {
    final room = roomOf(e.location);
    if (_exam.hasMatch(e.summary)) {
      final rest = e.summary.replaceFirst(_exam, '');
      final m = _examParts.firstMatch(rest);
      final course = (m != null ? m[2]! : rest.split(',').first).trim();
      return MappedEvent(
        MappedType.exam,
        title: 'Exam: $course',
        course: course,
        context: _join([room, m?[3]]),
      );
    }
    final m = _lecture.firstMatch(e.summary);
    if (m == null) {
      final first = e.summary.split(',').first.trim();
      return MappedEvent(
        MappedType.lecture,
        title: first.isEmpty ? 'Lecture' : first,
        context: room,
      );
    }
    final course = m[1]!.trim();
    return MappedEvent(
      MappedType.lecture,
      title: course,
      course: course,
      context: _join([m[4] ?? m[3], room, m[5]]),
    );
  }

  static final _dueSuffix = RegExp(
    r'\s+(?:ist fällig|is due|endet|ends|closes|schließt|fällig|due)\.?\s*$',
    caseSensitive: false,
  );
  static final _opensSuffix = RegExp(
    r'\s+(?:öffnet|opens|beginnt|starts)\.?\s*$',
    caseSensitive: false,
  );

  /// "(MET_WS2026_1) Climate Change and Dynamics" -> the course name.
  static String courseOf(String categories) {
    final m = RegExp(r'^\(([^)]+)\)\s*(.*)$').firstMatch(categories.trim());
    return m != null ? m[2]!.trim() : categories.trim();
  }

  static MappedEvent _moodle(FeedEntry e) {
    final course = courseOf(e.categories);
    if (e.end != null && e.end!.isAfter(e.start)) {
      return MappedEvent(
        MappedType.event,
        title: e.summary.isEmpty ? 'Moodle event' : e.summary,
        context: course,
      );
    }
    if (_opensSuffix.hasMatch(e.summary)) {
      return const MappedEvent(MappedType.skip);
    }
    final title = e.summary.replaceFirst(_dueSuffix, '').trim();
    return MappedEvent(
      MappedType.deadline,
      title: title.isEmpty ? 'Assignment' : title,
      course: course,
    );
  }

  static String _join(List<String?> parts) => parts
      .map((p) => (p ?? '').trim())
      .where((p) => p.isNotEmpty && p != '-')
      .join(' · ');
}
