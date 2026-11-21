/// Somewhere a file can be sent: Received files or a DeskPlan folder
/// (docs/protocol.md, `GET /v1/ping`).
class Destination {
  /// The id of Received files.
  static const receivedFilesId = 'received-files';

  /// Its id before. An older DeskPlan still lists it, and cached pings and
  /// queued uploads may hold it, so it means Received files too.
  static const legacyReceivedFilesId = 'inbox';

  /// Sent as `X-Dest-Id`: `received-files` or `folder:<id>`.
  final String id;

  /// The full path, good for a flat list ("CSC101 › Week 1").
  final String label;

  /// Just the folder's own name (null for Received files).
  final String? name;

  /// How deep it is, 0 = top level, for drawing a tree.
  final int depth;

  const Destination({
    required this.id,
    required this.label,
    this.name,
    this.depth = 0,
  });

  /// Stands in until the PC has said its own label (the ping's is shown then).
  static const receivedFiles = Destination(
    id: receivedFilesId,
    label: 'Received files',
  );

  bool get isReceivedFiles =>
      id == receivedFilesId || id == legacyReceivedFilesId;

  /// Reads one entry. Returns null for anything that is not a usable one,
  /// so a strange entry is skipped instead of breaking the whole list.
  static Destination? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final label = json['label'];
    if (id is! String || id.isEmpty || label is! String) return null;
    final name = json['name'];
    final depth = json['depth'];
    return Destination(
      id: id,
      label: label,
      name: name is String ? name : null,
      depth: depth is int && depth >= 0 ? depth : 0,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'name': name,
    'depth': depth,
  };
}
