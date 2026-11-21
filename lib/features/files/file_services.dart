import '../connection/connection_checker.dart';
import '../connection/pc_info_store.dart';
import '../share_intake/share_intake.dart';
import 'file_picker_service.dart';
import 'file_queuer.dart';
import 'local_file_store.dart';
import 'upload_queue.dart';

/// Everything the screens need for sending files, kept together so it can be
/// passed around as one thing instead of seven.
class FileServices {
  final FileQueuer queuer;
  final UploadQueue queue;
  final LocalFileStore store;
  final PcInfoStore pcInfoStore;
  final ConnectionChecker checker;
  final ShareIntake intake;
  final FilePickerService picker;

  const FileServices({
    required this.queuer,
    required this.queue,
    required this.store,
    required this.pcInfoStore,
    required this.checker,
    required this.intake,
    required this.picker,
  });
}
