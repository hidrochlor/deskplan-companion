import 'dart:io';

import '../connection/pc_info.dart';
import '../files/https_file_uploader.dart';
import 'shared_item.dart';
import 'url_shortcut.dart';

/// One shared thing on the share screen, with the name it will be sent as.
/// Plain Dart (no widgets), so the rules are easy to test.
class ShareEntry {
  static const unsupportedMessage =
      'DeskPlan only takes documents, images and links';

  final SharedItem item;

  /// The full name to send, with its ending. The user changes only the part
  /// before the ending (see [rename]).
  String name;

  /// The ending of the original name, with its dot (".pdf"), or "" if it had
  /// none. It is locked: DeskPlan judges a file by it, and changing it would
  /// not change what the file is.
  final String extension;

  /// File size in bytes (null for a link, which is tiny).
  final int? sizeBytes;

  /// The `.url` file content, when [item] is a shared web link.
  final String? linkContent;

  /// A reason this can never be queued, whatever its name (a text that is
  /// not a link, a file over 100 MB).
  final String? fixedProblem;

  ShareEntry._({
    required this.item,
    required this.name,
    this.sizeBytes,
    this.linkContent,
    this.fixedProblem,
  }) : extension = extensionOf(name);

  /// The ending of [fileName] with its dot, or "" if it has none. A name like
  /// ".hidden" or "trailing." has no ending.
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot);
  }

  /// The part of the name the user may change.
  String get baseName => name.endsWith(extension)
      ? name.substring(0, name.length - extension.length)
      : name;

  /// Changes the name before the locked ending.
  void rename(String base) => name = '$base$extension';

  /// Looks at a shared item and works out its name and whether it can go.
  static Future<ShareEntry> from(SharedItem item) async {
    switch (item) {
      case SharedFile(:final path, :final name):
        final size = await File(path).length();
        return ShareEntry._(
          item: item,
          name: name,
          sizeBytes: size,
          fixedProblem: size > HttpsFileUploader.maxBytes
              ? 'It is over 100 MB, the most DeskPlan takes'
              : null,
        );
      case SharedText(:final text, :final subject):
        final url = UrlShortcut.extractWebUrl(text);
        if (url == null) {
          return ShareEntry._(
            item: item,
            name: subject ?? 'text',
            fixedProblem:
                'Only web links can be shared as text. '
                '$unsupportedMessage',
          );
        }
        return ShareEntry._(
          item: item,
          name: UrlShortcut.fileName(url, title: subject),
          linkContent: UrlShortcut.content(url),
        );
    }
  }

  /// Why this cannot be queued right now, or null if it can. [pc] is what the
  /// PC last said it accepts (null if unknown: the PC then decides).
  String? problem(PcInfo? pc) {
    if (fixedProblem != null) return fixedProblem;
    if (baseName.trim().isEmpty) return 'Enter a name';
    if (pc != null && !pc.accepts(name.trim())) return unsupportedMessage;
    return null;
  }
}
