import 'dart:async';

import 'package:flutter/services.dart';

import 'share_intake.dart';
import 'shared_item.dart';

/// [ShareIntake] backed by `MainActivity.kt`, which reads the share intent
/// and copies each file into the app cache before handing it over.
class AndroidShareIntake implements ShareIntake {
  static const _channel = MethodChannel('deskplan/share');
  final _incoming = StreamController<List<SharedItem>>.broadcast();

  AndroidShareIntake() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') {
        final items = parse(call.arguments);
        if (items.isNotEmpty) _incoming.add(items);
      }
    });
  }

  @override
  Stream<List<SharedItem>> get incoming => _incoming.stream;

  @override
  Future<List<SharedItem>> initial() async =>
      parse(await _channel.invokeMethod<Object?>('takeInitial'));

  /// Reads the list the Kotlin side sends. Anything unreadable is skipped.
  static List<SharedItem> parse(Object? raw) {
    if (raw is! List) return const [];
    final items = <SharedItem>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      switch (entry['type']) {
        case 'file':
          final path = entry['path'];
          final name = entry['name'];
          if (path is String && name is String) {
            items.add(SharedFile(path: path, name: name));
          }
        case 'text':
          final text = entry['text'];
          final subject = entry['subject'];
          if (text is String) {
            items.add(
              SharedText(
                text: text,
                subject: subject is String ? subject : null,
              ),
            );
          }
      }
    }
    return items;
  }
}
