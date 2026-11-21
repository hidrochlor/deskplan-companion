import 'package:device_info_plus/device_info_plus.dart';

import 'device_name_provider.dart';

/// Uses the name from Android Settings (for example "Galaxy S24"), or the
/// brand and model if the user never set one.
class AndroidDeviceNameProvider implements DeviceNameProvider {
  String? _cached;

  @override
  Future<String?> name() async {
    if (_cached != null) return _cached;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final set = info.name.trim();
      _cached = set.isNotEmpty ? set : '${info.brand} ${info.model}'.trim();
    } on Object {
      return null; // a missing name must never stop syncing
    }
    return _cached;
  }
}
