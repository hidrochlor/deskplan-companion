import 'dart:async';

import 'package:flutter/material.dart';

import '../features/files/file_services.dart';
import '../features/files/queued_upload.dart';
import '../features/files/upload_status.dart';
import '../features/queue/sync_report.dart';
import '../features/queue/sync_service.dart';
import 'theme/deskplan_colors.dart';

/// The file queue, in two parts: what still needs attention (waiting, or
/// refused with the reason and a Retry or Delete), and what was sent, with a
/// button to clear that history.
class UploadsScreen extends StatefulWidget {
  final FileServices files;
  final SyncService sync;

  const UploadsScreen({super.key, required this.files, required this.sync});

  @override
  State<UploadsScreen> createState() => _UploadsScreenState();
}

class _UploadsScreenState extends State<UploadsScreen> {
  List<QueuedUpload> _uploads = [];
  StreamSubscription<SyncReport>? _reports;

  @override
  void initState() {
    super.initState();
    _reports = widget.sync.reports.listen((_) => _reload());
    _reload();
  }

  @override
  void dispose() {
    _reports?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final all = await widget.files.queue.all();
    if (mounted) setState(() => _uploads = all);
  }

  Future<void> _retry(QueuedUpload u) async {
    await widget.files.queue.retry(u.uploadId, DateTime.now());
    await _reload();
    widget.sync.syncNow();
  }

  Future<void> _delete(QueuedUpload u) async {
    await widget.files.queue.remove(u.uploadId);
    try {
      await widget.files.store.delete(u.localPath);
    } catch (_) {
      // The record is gone; a leftover copy loses nothing.
    }
    await _reload();
  }

  Future<void> _clearHistory() async {
    await widget.files.queue.clearSent();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final queued = _uploads
        .where((u) => u.status != UploadStatus.sent)
        .toList();
    final sent = _uploads.where((u) => u.status == UploadStatus.sent).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Files')),
      body: _uploads.isEmpty
          ? const Center(child: Text('No files yet. Share one to this app.'))
          : ListView(
              children: [
                _header('Waiting or refused', queued.length),
                if (queued.isEmpty)
                  const _EmptyNote('Nothing waiting')
                else
                  for (final u in queued) _row(u),
                // Sent files fold away: they are history, not something to
                // act on. Closed by default.
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const PageStorageKey('sent-files'),
                    tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    title: Text(
                      'Sent (${sent.length})',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: DeskPlanColors.of(context).muted,
                      ),
                    ),
                    children: [
                      if (sent.isEmpty)
                        const _EmptyNote('Nothing sent yet')
                      else ...[
                        for (final u in sent) _row(u),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton.icon(
                              onPressed: _clearHistory,
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 18,
                              ),
                              label: const Text('Clear history'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _header(String title, int count) {
    final c = DeskPlanColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title ($count)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(QueuedUpload u) {
    final c = DeskPlanColors.of(context);
    final (icon, color, text) = switch (u.status) {
      UploadStatus.waiting => (
        Icons.schedule,
        c.muted,
        u.lastError == null ? 'Waiting' : 'Waiting · ${u.lastError}',
      ),
      UploadStatus.failed => (
        Icons.error_outline,
        c.danger,
        u.lastError ?? 'Could not be sent',
      ),
      UploadStatus.sent => (Icons.check_circle_outline, c.ok, 'Sent'),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(u.displayName, overflow: TextOverflow.ellipsis),
      subtitle: Text(text, style: TextStyle(color: color)),
      trailing: switch (u.status) {
        UploadStatus.failed => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => _retry(u), child: const Text('Retry')),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _delete(u),
            ),
          ],
        ),
        UploadStatus.waiting => IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => _delete(u),
        ),
        UploadStatus.sent => null,
      },
    );
  }
}

/// A quiet line shown when a section has nothing in it.
class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Text(
      text,
      style: TextStyle(color: DeskPlanColors.of(context).faint),
    ),
  );
}
