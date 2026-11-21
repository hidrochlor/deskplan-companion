import 'destination.dart';

/// What DeskPlan says about itself in `GET /v1/ping`.
class PcInfo {
  final String name;
  final String version;

  /// Always starts with Received files.
  final List<Destination> destinations;

  /// File types the PC accepts: lowercase, no dots. Null when this DeskPlan
  /// is too old to say, so nothing is refused on the phone side.
  final Set<String>? allowedExtensions;

  /// What this DeskPlan syncs beyond tasks and assignments (protocol.md
  /// section 5, `features`). Empty for an older DeskPlan.
  final Set<String> features;

  const PcInfo({
    required this.name,
    required this.version,
    required this.destinations,
    this.allowedExtensions,
    this.features = const {},
  });

  /// True when DeskPlan syncs notes: only then are notes offered, sent and
  /// pulled.
  bool get syncsNotes => features.contains('notes');

  /// True when DeskPlan has calendar feeds: only then is `GET /v1/calendar`
  /// used and are its events shown.
  bool get hasCalendar => features.contains('calendar');

  /// True when DeskPlan shares its calendar feed list (protocol.md section
  /// 6): then the phone downloads the feeds itself instead of asking
  /// DeskPlan for their events.
  bool get sharesFeeds => features.contains('feeds');

  /// Reads a ping answer. Throws [FormatException] if it is not one.
  factory PcInfo.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Not a DeskPlan ping reply');
    final name = json['name'];
    if (name is! String) throw const FormatException('Ping has no PC name');
    final version = json['version'];

    final parsed = json['destinations'] is List
        ? (json['destinations'] as List)
              .map(Destination.tryParse)
              .whereType<Destination>()
              .toList()
        : <Destination>[];
    // Received files is always there, even if the list came back empty or
    // short. The PC's own entry (and its label) is used when it sent one.
    final destinations = parsed.any((d) => d.isReceivedFiles)
        ? parsed
        : [Destination.receivedFiles, ...parsed];

    final ext = json['allowedExtensions'];
    final allowed = ext is List
        ? ext.whereType<String>().map((e) => e.toLowerCase()).toSet()
        : null;

    final features = json['features'];

    return PcInfo(
      name: name,
      version: version is String ? version : '',
      destinations: destinations,
      allowedExtensions: allowed,
      features: features is List
          ? features.whereType<String>().toSet()
          : const {},
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'version': version,
    'destinations': destinations.map((d) => d.toJson()).toList(),
    'allowedExtensions': allowedExtensions?.toList(),
    'features': features.toList(),
  };

  /// True if a file with this name may be sent. Judged by the extension,
  /// any letter case. When the PC gave no list, everything is allowed.
  bool accepts(String fileName) {
    final allowed = allowedExtensions;
    if (allowed == null) return true;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return false;
    return allowed.contains(fileName.substring(dot + 1).toLowerCase());
  }
}
