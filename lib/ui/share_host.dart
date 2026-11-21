import 'dart:async';

import 'package:flutter/material.dart';

import '../features/files/file_services.dart';
import '../features/queue/sync_service.dart';
import '../features/share_intake/shared_item.dart';
import 'share_screen.dart';

/// Wraps the home screen and opens the [ShareScreen] whenever something is
/// shared to the app: both when the share started the app, and when the app
/// was already open.
class ShareHost extends StatefulWidget {
  final FileServices files;
  final SyncService sync;
  final Widget child;

  const ShareHost({
    super.key,
    required this.files,
    required this.sync,
    required this.child,
  });

  @override
  State<ShareHost> createState() => _ShareHostState();
}

class _ShareHostState extends State<ShareHost> {
  StreamSubscription<List<SharedItem>>? _incoming;

  @override
  void initState() {
    super.initState();
    _incoming = widget.files.intake.incoming.listen(_show);
    widget.files.intake.initial().then(_show);
  }

  @override
  void dispose() {
    _incoming?.cancel();
    super.dispose();
  }

  void _show(List<SharedItem> items) {
    if (items.isEmpty || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ShareScreen(items: items, files: widget.files, sync: widget.sync),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
