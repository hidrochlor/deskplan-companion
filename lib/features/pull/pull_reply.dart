import '../../core/task.dart';
import 'pulled_item.dart';

/// DeskPlan's answer to `GET /v1/items?since=` (docs/protocol.md section 5).
class PullReply {
  final List<PulledItem> items;

  /// DeskPlan's own clock when it built the answer. Kept as the exact text
  /// DeskPlan sent and used as `since` next time, so a wrong phone clock can
  /// never cause missed changes.
  final String serverTime;

  /// True when [items] is the complete set of tasks rather than the changes:
  /// a task that is not in it is gone from DeskPlan.
  final bool fullResync;

  /// Every field an item can have in this answer, or null from a DeskPlan
  /// that does not say (protocol.md section 5, `fields`).
  final Set<String>? fields;

  const PullReply({
    required this.items,
    required this.serverTime,
    required this.fullResync,
    this.fields,
  });

  /// Reads the answer. Throws [FormatException] if any part is wrong: the
  /// whole answer is refused, so the phone does not move its place forward
  /// past something it could not read.
  factory PullReply.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Not a list of changes');

    final serverTime = json['serverTime'];
    if (serverTime is! String || DateTime.tryParse(serverTime) == null) {
      throw const FormatException('The changes have no valid server time');
    }
    final fullResync = json['fullResync'];
    if (fullResync != null && fullResync is! bool) {
      throw const FormatException('fullResync is not true or false');
    }
    final fields = json['fields'];
    if (fields != null &&
        (fields is! List || fields.any((f) => f is! String))) {
      throw const FormatException('fields is not a list of names');
    }
    final raw = json['items'];
    if (raw is! List) throw const FormatException('The changes have no items');

    final items = <PulledItem>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('A change is not an object');
      }
      final id = entry['id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('A change has no id');
      }
      items.add(
        entry['deleted'] == true
            ? PulledDeletion(id)
            : PulledTask(Task.fromSyncJson(entry)),
      );
    }
    return PullReply(
      items: items,
      serverTime: serverTime,
      fullResync: fullResync == true,
      fields: fields == null ? null : Set<String>.from(fields as List),
    );
  }
}
