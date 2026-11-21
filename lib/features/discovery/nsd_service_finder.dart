import 'dart:async';
import 'dart:convert';

import 'package:nsd/nsd.dart';

import 'found_service.dart';
import 'service_finder.dart';

/// [ServiceFinder] using Android's own network service discovery (through the
/// `nsd` package), which also takes care of the multicast lock Android needs.
class NsdServiceFinder implements ServiceFinder {
  static const serviceType = '_deskplan._tcp';

  @override
  Future<List<FoundService>> find({
    required bool Function(FoundService) accept,
    required Duration timeout,
  }) async {
    final found = <FoundService>[];
    final done = Completer<void>();
    Discovery? discovery;
    try {
      discovery = await startDiscovery(
        serviceType,
        ipLookupType: IpLookupType.v4,
      );
      discovery.addServiceListener((service, status) {
        if (status != ServiceStatus.found) return;
        final converted = _convert(service);
        if (converted != null && accept(converted)) {
          found.add(converted);
          if (!done.isCompleted) done.complete();
        }
      });
      // Services found before the listener was attached.
      for (final service in discovery.services) {
        final converted = _convert(service);
        if (converted != null && accept(converted)) found.add(converted);
      }
      if (found.isEmpty) {
        await done.future.timeout(timeout, onTimeout: () {});
      }
    } catch (_) {
      // No multicast, or discovery is not allowed here: behave as "not found"
      // and let the next way of finding the PC take over.
    } finally {
      if (discovery != null) {
        try {
          await stopDiscovery(discovery);
        } catch (_) {}
      }
    }
    return found;
  }

  /// Null when the service has no usable address or port.
  FoundService? _convert(Service service) {
    final port = service.port;
    final addresses =
        service.addresses?.map((a) => a.address).toList() ?? <String>[];
    if (port == null || addresses.isEmpty) return null;
    final raw = service.txt?['id'];
    return FoundService(
      addresses: addresses,
      port: port,
      id: raw == null ? null : utf8.decode(raw, allowMalformed: true),
    );
  }
}
