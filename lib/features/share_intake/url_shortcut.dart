/// Turns a shared web link into the file DeskPlan accepts: a Windows Internet
/// Shortcut, `Name.url` (docs/protocol.md section 10). DeskPlan reads it back
/// and refuses any address that does not start with http:// or https://.
class UrlShortcut {
  static final _webUrl = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

  /// Characters that are often glued to the end of a link in a sentence.
  static const _trailing = '.,;:!?)]}\'"';

  /// The first web address in [text], or null. Browsers share the text as
  /// "Page title https://example.com/page", so this picks the link out.
  static Uri? extractWebUrl(String text) {
    final match = _webUrl.firstMatch(text);
    if (match == null) return null;
    var found = match.group(0)!;
    while (found.isNotEmpty && _trailing.contains(found[found.length - 1])) {
      found = found.substring(0, found.length - 1);
    }
    final uri = Uri.tryParse(found);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    return uri;
  }

  /// The file content. Windows text files use CRLF line endings.
  static String content(Uri url) => '[InternetShortcut]\r\nURL=$url\r\n';

  /// A file name for the link: the page [title] if there is one, otherwise
  /// the site name. Characters Windows rejects are removed.
  static String fileName(Uri url, {String? title}) {
    var base = (title ?? '').trim();
    if (base.isEmpty) base = url.host.replaceFirst(RegExp(r'^www\.'), '');
    base = base
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (base.length > 80) base = base.substring(0, 80).trim();
    if (base.isEmpty) base = 'link';
    return '$base.url';
  }
}
