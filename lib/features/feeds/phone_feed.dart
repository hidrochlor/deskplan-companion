import 'feed_mappers.dart';

/// One calendar feed in the list shared with DeskPlan (protocol.md section
/// 6). The address is kept apart, in secure storage ([FeedUrlStore]): a
/// Moodle address holds a token.
class PhoneFeed {
  /// The same on both sides once DeskPlan has it.
  final String id;
  final String name;
  final FeedKind kind;

  /// The address's host, to show ("almaty.fh-joanneum.at").
  final String host;

  /// Removed: kept as a marker until DeskPlan has heard it.
  final bool removed;

  /// When its address, name or removal last changed. The newer side wins.
  final DateTime updatedAt;

  /// Changed here and not yet sent to DeskPlan.
  final bool dirty;

  /// When this phone last downloaded it, and what went wrong if it failed.
  final DateTime? lastFetched;
  final String? lastError;

  /// How many events the last download had.
  final int count;

  PhoneFeed({
    required this.id,
    required this.name,
    this.kind = FeedKind.calendar,
    this.host = '',
    this.removed = false,
    required DateTime updatedAt,
    this.dirty = false,
    DateTime? lastFetched,
    this.lastError,
    this.count = 0,
  }) : updatedAt = updatedAt.toUtc(),
       lastFetched = lastFetched?.toUtc();

  PhoneFeed copyWith({
    String? name,
    FeedKind? kind,
    String? host,
    bool? removed,
    DateTime? updatedAt,
    bool? dirty,
    DateTime? lastFetched,
    String? lastError,
    bool clearError = false,
    int? count,
  }) => PhoneFeed(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    host: host ?? this.host,
    removed: removed ?? this.removed,
    updatedAt: updatedAt ?? this.updatedAt,
    dirty: dirty ?? this.dirty,
    lastFetched: lastFetched ?? this.lastFetched,
    lastError: clearError ? null : (lastError ?? this.lastError),
    count: count ?? this.count,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'host': host,
    'removed': removed ? 1 : 0,
    'updatedAt': updatedAt.toIso8601String(),
    'dirty': dirty ? 1 : 0,
    'lastFetched': lastFetched?.toIso8601String(),
    'lastError': lastError,
    'count': count,
  };

  factory PhoneFeed.fromMap(Map<String, Object?> m) => PhoneFeed(
    id: m['id'] as String,
    name: m['name'] as String,
    kind: FeedKind.fromWire(m['kind']),
    host: m['host'] as String,
    removed: (m['removed'] as int) == 1,
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    dirty: (m['dirty'] as int) == 1,
    lastFetched: m['lastFetched'] == null
        ? null
        : DateTime.parse(m['lastFetched'] as String),
    lastError: m['lastError'] as String?,
    count: m['count'] as int,
  );
}

/// Whether one course of a feed is hidden, shared with DeskPlan.
class CourseChoice {
  final String feedId;

  /// The course name, normalised (CalendarEvent.courseKeyOf).
  final String key;
  final bool hidden;
  final DateTime updatedAt;
  final bool dirty;

  CourseChoice({
    required this.feedId,
    required this.key,
    required this.hidden,
    required DateTime updatedAt,
    this.dirty = false,
  }) : updatedAt = updatedAt.toUtc();

  Map<String, Object?> toMap() => {
    'feedId': feedId,
    'key': key,
    'hidden': hidden ? 1 : 0,
    'updatedAt': updatedAt.toIso8601String(),
    'dirty': dirty ? 1 : 0,
  };

  factory CourseChoice.fromMap(Map<String, Object?> m) => CourseChoice(
    feedId: m['feedId'] as String,
    key: m['key'] as String,
    hidden: (m['hidden'] as int) == 1,
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    dirty: (m['dirty'] as int) == 1,
  );

  Map<String, Object?> toWire() => {
    'feedId': feedId,
    'key': key,
    'hidden': hidden,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
