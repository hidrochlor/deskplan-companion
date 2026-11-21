import '../../core/task.dart';
import '../../core/task_kind.dart';
import 'change_puller.dart';
import 'pull_applier.dart';
import 'pull_cursor_store.dart';
import 'pull_outcome.dart';
import 'pull_reply.dart';
import 'pull_result.dart';
import 'pull_service.dart';

/// The real [ChangePuller]: asks DeskPlan what changed since the saved place,
/// applies the answer, and only then moves the place forward. If anything
/// fails part way, the place stays where it was, so the same changes are
/// simply fetched again next time (applying them twice does no harm).
///
/// The place belongs to the kinds it was read with: earlier pulls left
/// notes out, so the first pull that asks for them starts from the
/// beginning (protocol.md section 5, "Adding a kind").
///
/// It also belongs to the fields it was read with: when DeskPlan's answer
/// has a field this phone reads ([Task.syncFields]) that was not there last
/// time, the phone reads everything again at once, so items that did not
/// change still learn it (protocol.md section 5, `fields`). Nobody has to
/// remember to force that when a field is added on either side.
class ServerChangePuller implements ChangePuller {
  final PullService _service;
  final PullApplier _applier;
  final PullCursorStore _cursor;

  ServerChangePuller(this._service, this._applier, this._cursor);

  @override
  Future<PullOutcome> pull({bool notes = false}) async {
    final kinds = {
      TaskKind.task,
      TaskKind.assignment,
      if (notes) TaskKind.note,
    };
    final kindsText = kinds.map((k) => k.wireName).join(',');
    try {
      final savedKinds = await _cursor.kinds() ?? PullService.defaultKinds;
      final since = savedKinds == kindsText ? await _cursor.load() : null;
      var result = await _service.pull(since: since, kinds: kindsText);
      if (since != null &&
          result is PullOk &&
          await _readsNewFields(result.reply)) {
        result = await _service.pull(kinds: kindsText);
      }
      switch (result) {
        case PullOk(:final reply):
          final changed = await _applier.apply(reply, kinds: kinds);
          await _cursor.save(
            reply.serverTime,
            kinds: kindsText,
            fields: _read(reply),
          );
          return PullOutcome(changed: changed);
        case PullUnsupported():
          return const PullOutcome(unsupported: true);
        case PullBlocked(:final problem):
          return PullOutcome(blocked: problem);
        case PullFailed(:final reason, :final resetPlace):
          if (resetPlace) await _cursor.clear();
          return PullOutcome(failure: reason);
      }
    } catch (e) {
      return PullOutcome(failure: 'Could not apply DeskPlan\'s changes: $e');
    }
  }

  /// The fields in [reply] that this phone reads, or null if DeskPlan does
  /// not list them.
  static Set<String>? _read(PullReply reply) =>
      reply.fields?.intersection(Task.syncFields);

  /// Whether [reply] has a field this phone reads that the saved place was
  /// read without. Unknown (never saved) counts as new: one full read.
  Future<bool> _readsNewFields(PullReply reply) async {
    final now = _read(reply);
    if (now == null) return false; // an older DeskPlan: carry on as before
    final before = await _cursor.fields();
    return before == null || !before.containsAll(now);
  }
}
