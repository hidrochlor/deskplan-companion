/// Remembers how far the phone has read DeskPlan's changes: the
/// `serverTime` of the last answer that was applied in full, and which
/// kinds that answer was for (protocol.md section 5, `kinds`).
abstract class PullCursorStore {
  /// The saved `serverTime`, or null if the phone has never pulled (or the
  /// place was forgotten): the next pull then asks for everything.
  Future<String?> load();

  /// The `kinds` the saved place was read with, or null when it was saved
  /// before the phone asked for kinds (that is: tasks and assignments).
  Future<String?> kinds();

  /// The fields this phone reads that DeskPlan's items had when the saved
  /// place was read, or null when not known (never saved, or an older
  /// DeskPlan that does not list them).
  Future<Set<String>?> fields();

  Future<void> save(
    String serverTime, {
    required String kinds,
    Set<String>? fields,
  });
  Future<void> clear();
}
