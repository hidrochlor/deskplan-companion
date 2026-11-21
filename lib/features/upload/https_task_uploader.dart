import 'dart:convert';

import '../../core/task.dart';
import '../connection/client_reply.dart';
import '../connection/deskplan_client.dart';
import 'task_uploader.dart';
import 'upload_result.dart';

/// Sends task changes to DeskPlan (docs/protocol.md, sections 4 and 6).
/// Never throws for network trouble: it returns an [UploadResult] the queue
/// knows how to handle.
class HttpsTaskUploader implements TaskUploader {
  /// DeskPlan refuses an item body over 1 MB (protocol.md section 8).
  static const maxBodyBytes = 1024 * 1024;

  final DeskPlanClient _client;

  HttpsTaskUploader(this._client);

  /// True when [task]'s request would be over DeskPlan's limit. Only a long
  /// note can get there.
  static bool tooBig(Task task) =>
      utf8.encode(jsonEncode(task.toSyncJson())).length > maxBodyBytes;

  @override
  Future<UploadResult> save(Task task) async {
    // Checked here, so a note that can never fit is not sent over and over:
    // it stays on the phone and the user is told.
    if (tooBig(task)) {
      return Rejected(
        task.isNote
            ? 'this note is too big to sync (over 1 MB)'
            : 'it is too big for DeskPlan (over 1 MB)',
      );
    }
    return _interpret(
      await _client.send('PUT', [
        'v1',
        'items',
        task.id,
      ], jsonBody: task.toSyncJson()),
      task.id,
      readTask: true,
    );
  }

  @override
  Future<UploadResult> delete(String taskId) async => _interpret(
    await _client.send('DELETE', ['v1', 'items', taskId]),
    taskId,
    readTask: false,
  );

  /// Turns DeskPlan's answer into what the queue should do. Errors look like
  /// `{ "error": "<code>" }`.
  UploadResult _interpret(
    ClientReply reply,
    String taskId, {
    required bool readTask,
  }) {
    if (reply is NoReply) {
      return Unreachable(
        reply.message,
        cause: reply.cause,
        retrySoon: reply.retrySoon,
      );
    }
    final Reply(:status, body: text) = reply as Reply;
    final code = DeskPlanClient.errorCode(text);

    final blocked = NoReply.fromStatus(status, code);
    if (blocked != null) {
      return Unreachable(
        blocked.message,
        cause: blocked.cause,
        retrySoon: blocked.retrySoon,
      );
    }
    switch (status) {
      case 200 || 201:
        return readTask ? _confirmedSave(text, taskId) : _confirmedDelete(text);
      case 413:
        return const Rejected('it is too big for DeskPlan');
      case 422:
        return Rejected(switch (code) {
          'not-syncable' => 'that item is a folder or file on your PC',
          // A rule of the PC, not a bug: for example an assignment needs a
          // folder and a due time, a task needs a From and a To, and a
          // step must be inside an assignment.
          'invalid-request' =>
            'it breaks a DeskPlan rule (an '
                'assignment needs a folder and a due time, a task needs a '
                'From and a To, and a step must be inside an assignment)',
          _ => 'DeskPlan did not accept it (${code ?? 'invalid'})',
        });
      case 404 || 405:
        return Rejected('the app and DeskPlan disagree ($status, a bug)');
      case 503:
        return const RetryLater('DeskPlan is busy or starting');
      default:
        return RetryLater('Unexpected reply from DeskPlan ($status)');
    }
  }

  /// DELETE answers 200 whether or not the task was removed. If DeskPlan
  /// kept it because it has things filed inside, the queued delete is
  /// dropped and the user is told.
  UploadResult _confirmedDelete(String text) {
    try {
      final json = jsonDecode(text);
      if (json is Map && json['result'] == 'kept-has-contents') {
        return const Rejected(
          'it has things filed inside it, so DeskPlan kept it',
        );
      }
    } on FormatException {
      // An empty or odd body on a 200 still means the delete is done.
    }
    return const Confirmed();
  }

  /// A saved task's reply carries the task as DeskPlan now stores it.
  /// A "kept-newer" reply replaces the phone's copy; any other only brings
  /// the fields DeskPlan decides (course, source, an imported due date).
  UploadResult _confirmedSave(String text, String taskId) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic> || json['id'] != taskId) {
        return const RetryLater('DeskPlan sent an unreadable reply');
      }
      if (json['result'] == 'kept-newer') {
        return Confirmed(pcVersion: Task.fromSyncJson(json));
      }
      return Confirmed(stored: _storedOrNull(json));
    } on FormatException {
      return const RetryLater('DeskPlan sent an unreadable reply');
    }
  }

  /// The task in a "created" or "updated" reply. The save itself is done, so
  /// a reply that is not a whole task (an odd or older DeskPlan) only means
  /// there is nothing to take from it.
  Task? _storedOrNull(Map<String, dynamic> json) {
    try {
      return Task.fromSyncJson(json);
    } on FormatException {
      return null;
    }
  }
}
