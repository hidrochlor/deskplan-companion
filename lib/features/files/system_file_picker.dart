import 'package:flutter/services.dart';

import '../share_intake/android_share_intake.dart';
import '../share_intake/shared_item.dart';
import 'file_picker_service.dart';

/// [FilePickerService] using Android's own file chooser, opened by
/// `MainActivity.kt`. Each chosen file is copied into the app cache there, the
/// same way a shared file is, so the result is always a readable path.
class SystemFilePicker implements FilePickerService {
  // The same channel as the share intake: one Kotlin class does both.
  static const _channel = MethodChannel('deskplan/share');

  @override
  Future<List<SharedFile>> pick() async {
    final raw = await _channel.invokeMethod<Object?>('pickFiles');
    return AndroidShareIntake.parse(raw).whereType<SharedFile>().toList();
  }
}
