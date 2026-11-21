/// How often a task or assignment repeats (protocol.md section 4 "Repeating
/// items"): `{ "every": "day" | "week" | "month", "interval": 1-12,
/// "until": UTC time or null }`. When one is ticked off, its next copy is
/// added (see repeats.dart).
enum RepeatEvery {
  day('Daily', 'days'),
  week('Weekly', 'weeks'),
  month('Monthly', 'months');

  final String one;
  final String many;

  const RepeatEvery(this.one, this.many);

  static RepeatEvery? fromWire(Object? value) {
    for (final e in values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

class RepeatRule {
  static const maxInterval = 12;

  final RepeatEvery every;

  /// 1 to [maxInterval]: every 2 weeks is `week` with interval 2.
  final int interval;

  /// The last moment a copy may be due, or null for no end. UTC.
  final DateTime? until;

  RepeatRule(this.every, {this.interval = 1, DateTime? until})
    : until = until?.toUtc();

  /// "Weekly", "Every 2 weeks".
  String get label =>
      interval == 1 ? every.one : 'Every $interval ${every.many}';

  RepeatRule withUntil(DateTime? until) =>
      RepeatRule(every, interval: interval, until: until);

  Map<String, Object?> toJson() => {
    'every': every.name,
    'interval': interval,
    'until': until?.toIso8601String(),
  };

  /// Reads a rule. Throws [FormatException] for anything that is not one.
  factory RepeatRule.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('repeat is not an object');
    final every = RepeatEvery.fromWire(json['every']);
    final interval = json['interval'] ?? 1;
    final until = json['until'];
    if (every == null) throw const FormatException('repeat has no every');
    if (interval is! int || interval < 1 || interval > maxInterval) {
      throw const FormatException('repeat interval is not 1 to 12');
    }
    if (until != null &&
        (until is! String || DateTime.tryParse(until) == null)) {
      throw const FormatException('repeat until is not a time');
    }
    return RepeatRule(
      every,
      interval: interval,
      until: until == null ? null : DateTime.parse(until as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RepeatRule &&
      other.every == every &&
      other.interval == interval &&
      other.until == until;

  @override
  int get hashCode => Object.hash(every, interval, until);
}
