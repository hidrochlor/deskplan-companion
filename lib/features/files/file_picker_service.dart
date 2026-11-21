import '../share_intake/shared_item.dart';

/// Lets the user choose files from inside the app (the "+" menu), as an
/// alternative to sharing from another app. Chosen files go to the same share
/// screen as shared ones.
abstract class FilePickerService {
  /// Opens the system file chooser. Returns the chosen files, readable from
  /// the app's cache, or an empty list if the user backed out.
  Future<List<SharedFile>> pick();
}
