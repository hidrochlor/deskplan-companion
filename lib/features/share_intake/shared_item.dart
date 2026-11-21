/// Something another app shared with DeskPlan Companion.
sealed class SharedItem {
  const SharedItem();
}

/// A file. Android already copied it into the app's cache, so [path] stays
/// readable even if the sender's link expires.
class SharedFile extends SharedItem {
  final String path;

  /// The file's own name, as the sending app gave it.
  final String name;

  const SharedFile({required this.path, required this.name});
}

/// Plain text, usually a web link shared from a browser.
class SharedText extends SharedItem {
  final String text;

  /// A title that came with it (a browser sends the page title), if any.
  final String? subject;

  const SharedText({required this.text, this.subject});
}
