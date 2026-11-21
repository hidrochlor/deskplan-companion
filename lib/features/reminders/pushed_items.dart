import 'dart:isolate';
import 'dart:ui';

/// Tells the open app that a reminder button pushed an item back. The button
/// runs in a separate background isolate (a second copy of the app's Dart
/// code), so the list on screen would not know; this sends it a note through
/// a named port, so it reloads at once.
class PushedItems {
  static const _name = 'deskplan.pushed-items';

  ReceivePort? _port;

  /// While the app is open: call [onPushed] after each push.
  void listen(void Function() onPushed) {
    close();
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_name);
    IsolateNameServer.registerPortWithName(port.sendPort, _name);
    port.listen((_) => onPushed());
    _port = port;
  }

  void close() {
    if (_port == null) return;
    IsolateNameServer.removePortNameMapping(_name);
    _port?.close();
    _port = null;
  }

  /// From the background isolate: nothing happens when the app is closed.
  static void announce() => IsolateNameServer.lookupPortByName(_name)?.send(1);
}
