import 'package:flutter/material.dart';

import '../features/connection/destination.dart';
import '../features/connection/pc_info.dart';
import '../features/connection/ping_result.dart';
import '../features/files/file_services.dart';
import '../features/queue/sync_service.dart';
import '../features/share_intake/share_entry.dart';
import '../features/share_intake/shared_item.dart';
import 'destination_picker.dart';
import 'theme/deskplan_colors.dart';

/// The small screen that opens when something is shared to the app: check or
/// edit each name, pick where it goes (default Received files), tap Queue.
class ShareScreen extends StatefulWidget {
  final List<SharedItem> items;
  final FileServices files;
  final SyncService sync;

  const ShareScreen({
    super.key,
    required this.items,
    required this.files,
    required this.sync,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _entries = <ShareEntry>[];
  final _controllers = <TextEditingController>[];
  bool _ready = false;
  bool _queueing = false;

  /// What the PC last said it accepts. Null until known (then the PC decides).
  PcInfo? _pc;

  /// Set when the folders shown are from an earlier visit, not fresh.
  String? _staleNote;
  String _destId = Destination.receivedFilesId;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prepare() async {
    for (final item in widget.items) {
      final entry = await ShareEntry.from(item);
      _entries.add(entry);
      _controllers.add(TextEditingController(text: entry.baseName));
    }
    // Show what was remembered at once, then freshen it from the PC.
    _pc = await widget.files.pcInfoStore.load();
    if (mounted) setState(() => _ready = true);
    await _refreshFromPc();
  }

  /// The folder list can change on the PC at any time, so ask again every
  /// time this screen opens (protocol.md section 4).
  Future<void> _refreshFromPc() async {
    final result = await widget.files.checker.check();
    if (!mounted) return;
    setState(() {
      switch (result) {
        case PingOk(:final info):
          _pc = info;
          _staleNote = null;
        case PingBlocked(:final problem):
          _staleNote =
              '${problem.message}. '
              '${_pc == null ? 'Your files will wait in the queue.' : 'Showing what was known last time.'}';
      }
      // A remembered folder may be gone: fall back to Received files.
      if (!_destinations.any((d) => d.id == _destId)) {
        _destId = Destination.receivedFilesId;
      }
    });
  }

  List<Destination> get _destinations =>
      _pc?.destinations ?? const [Destination.receivedFiles];

  List<ShareEntry> get _queueable =>
      _entries.where((e) => e.problem(_pc) == null).toList();

  Future<void> _queue() async {
    setState(() => _queueing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var count = 0;
    for (final entry in _queueable) {
      final item = entry.item;
      if (item is SharedFile) {
        await widget.files.queuer.addFile(
          sourcePath: item.path,
          displayName: entry.name.trim(),
          destId: _destId,
        );
      } else {
        await widget.files.queuer.addText(
          content: entry.linkContent!,
          displayName: entry.name.trim(),
          destId: _destId,
        );
      }
      count++;
    }
    widget.sync.syncNow(); // sends now if the PC is reachable
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? 'Queued 1 file for DeskPlan'
                : 'Queued $count files for DeskPlan',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final canQueue = _ready && !_queueing && _queueable.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Send to DeskPlan')),
      body: !_ready
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < _entries.length; i++) _entryRow(i, c),
                const SizedBox(height: 8),
                DestinationPicker(
                  destinations: _destinations,
                  selectedId: _destId,
                  onChanged: (id) => setState(() => _destId = id),
                ),
                if (_staleNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _staleNote!,
                      style: TextStyle(fontSize: 12.5, color: c.muted),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: canQueue ? _queue : null,
            child: Text(
              _queueable.length > 1
                  ? 'Queue ${_queueable.length} files'
                  : 'Queue',
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryRow(int i, DeskPlanColors c) {
    final entry = _entries[i];
    final problem = entry.problem(_pc);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[i],
        // Nothing to edit when the item can never be sent.
        enabled: entry.fixedProblem == null,
        decoration: InputDecoration(
          labelText: entry.item is SharedText ? 'Link name' : 'File name',
          // The ending is fixed: only the name before it can be changed.
          suffixText: entry.extension.isEmpty ? null : entry.extension,
          suffixStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
          errorText: problem,
          errorMaxLines: 3,
          helperText: entry.sizeBytes == null ? null : _size(entry.sizeBytes!),
        ),
        onChanged: (v) => setState(() => entry.rename(v)),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
