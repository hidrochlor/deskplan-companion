import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_file_store.dart';

/// [LocalFileStore] using the app's private storage: one folder per upload,
/// holding a single file called `payload` (the name the user sees is kept in
/// the database, so odd characters never reach the file system).
class AppLocalFileStore implements LocalFileStore {
  /// Pass [root] only in tests.
  final Directory? _root;

  AppLocalFileStore({this._root});

  Future<Directory> _folderFor(String uploadId) async {
    final base = _root ?? await getApplicationSupportDirectory();
    final folder = Directory(p.join(base.path, 'uploads', uploadId));
    await folder.create(recursive: true);
    return folder;
  }

  @override
  Future<String> adopt(String sourcePath, String uploadId) async {
    final target = p.join((await _folderFor(uploadId)).path, 'payload');
    await File(sourcePath).copy(target);
    return target;
  }

  @override
  Future<String> writeText(String uploadId, String content) async {
    final target = File(p.join((await _folderFor(uploadId)).path, 'payload'));
    await target.writeAsBytes(utf8.encode(content));
    return target.path;
  }

  @override
  Future<void> delete(String path) async {
    final folder = File(path).parent;
    // Only ever remove the folder this store made, never an unknown one.
    if (p.basename(path) == 'payload' && await folder.exists()) {
      await folder.delete(recursive: true);
    } else {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
