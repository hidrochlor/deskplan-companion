/// Where the app keeps its own copy of each queued file. A shared file's
/// original link can expire, so the copy is made at once (protocol.md
/// section 6).
abstract class LocalFileStore {
  /// Copies the file at [sourcePath] into the app's storage for [uploadId].
  /// Returns where the copy is.
  Future<String> adopt(String sourcePath, String uploadId);

  /// Writes a small text file (a link) for [uploadId]. Returns its path.
  Future<String> writeText(String uploadId, String content);

  /// Deletes the stored copy of [path] (and anything else kept with it).
  Future<void> delete(String path);
}
