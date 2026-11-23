import 'package:flutter/material.dart';

import 'clash_notice.dart';

import '../core/task.dart';
import '../core/task_remover.dart';
import '../core/task_repository.dart';
import '../core/task_tree.dart';
import '../features/connection/destination.dart';
import 'date_text.dart';
import 'progress_count.dart';
import 'source_badge.dart';
import 'task_sheet.dart';
import 'theme/deskplan_colors.dart';

/// An assignment opened from the list: its progress, its steps (tap to edit,
/// tick to finish, add more), and the submit button. All changes go through
/// the repository that queues them for DeskPlan.
class AssignmentSheet extends StatefulWidget {
  final String assignmentId;

  /// The repository that queues changes for DeskPlan.
  final TaskRepository repository;

  /// DeskPlan's folders, to show and change which one it is in.
  final List<Destination> folders;

  /// Called after every change, so the list behind updates and a sync starts.
  final Future<void> Function() onChanged;

  /// How its steps sit against the day's other blocks, when opened from
  /// the calendar.
  final List<(String, bool)> clashes;

  const AssignmentSheet({
    super.key,
    required this.assignmentId,
    required this.repository,
    required this.folders,
    required this.onChanged,
    this.clashes = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required String assignmentId,
    required TaskRepository repository,
    required List<Destination> folders,
    required Future<void> Function() onChanged,
    List<(String, bool)> clashes = const [],
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AssignmentSheet(
      assignmentId: assignmentId,
      repository: repository,
      folders: folders,
      onChanged: onChanged,
      clashes: clashes,
    ),
  );

  @override
  State<AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<AssignmentSheet> {
  final _newStep = TextEditingController();
  TaskTree _tree = TaskTree(const []);
  Task? _assignment;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _newStep.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final all = await widget.repository.all();
    final tree = TaskTree(all);
    final found = all.where((t) => t.id == widget.assignmentId);
    if (!mounted) return;
    if (found.isEmpty) {
      Navigator.pop(context); // it was deleted (for example on the PC)
      return;
    }
    setState(() {
      _tree = tree;
      _assignment = found.first;
    });
  }

  /// Saves a change, then refreshes this sheet and the list behind it.
  Future<void> _save(Task task) async {
    await widget.repository.save(task);
    await _reload();
    await widget.onChanged();
  }

  /// A step is a task, so it needs a From and a To (protocol.md section 4
  /// "Shapes"): the typed title opens the step sheet to set them, and only
  /// its Save adds the step.
  Future<void> _addStep() async {
    final title = _newStep.text.trim();
    final result = await TaskSheet.show(
      context,
      fixedParentId: widget.assignmentId,
      initialTitle: title,
    );
    if (result is! Task) return;
    _newStep.clear();
    await _save(result);
  }

  Future<void> _editStep(Task step) async {
    final result = await TaskSheet.show(
      context,
      task: step,
      fixedParentId: widget.assignmentId,
    );
    if (result is Task) {
      await _save(result);
    } else if (result == TaskSheet.deleted) {
      await widget.repository.delete(step.id);
      await _reload();
      await widget.onChanged();
    }
  }

  Future<void> _editAssignment(Task assignment) async {
    final result = await TaskSheet.show(
      context,
      task: assignment,
      folders: widget.folders,
    );
    if (result is Task) {
      await _save(result);
    } else if (result == TaskSheet.deleted) {
      await _confirmDelete(assignment);
    }
  }

  /// Deleting an assignment deletes its steps (and notes) too, so ask first.
  Future<void> _confirmDelete(Task assignment) async {
    final remover = TaskRemover(widget.repository);
    final inside = await remover.countInside(assignment);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: Text(
          (inside == 0
                  ? '"${assignment.title}" will be deleted.'
                  : '"${assignment.title}" and the $inside '
                        '${inside == 1 ? 'item' : 'items'} inside it will be '
                        'deleted.') +
              // DeskPlan does not import it again (protocol.md section 4
              // "Imported assignments"); only the PC can restore it.
              (assignment.isImported
                  ? " ${assignment.sourceLabel} won't add it back. You can "
                        'restore it on your PC in Settings › Data.'
                  : ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: DeskPlanColors.of(context).danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await remover.remove(assignment);
    await widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  String? _folderName(Task a) {
    for (final d in widget.folders) {
      if (d.id == 'folder:${a.parentId}') return d.label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final assignment = _assignment;
    if (assignment == null) return const SizedBox(height: 120);

    final steps = _tree.stepsOf(assignment.id);
    final progress = _tree.progressOf(assignment.id);
    final folder = _folderName(assignment);
    final loc = MaterialLocalizations.of(context);
    final due = assignment.end?.toLocal();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: DeskPlanColors.assignmentKind,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assignment',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                  ),
                  if (assignment.sourceLabel case final label?)
                    SourceBadge(label: label),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _editAssignment(assignment),
                  ),
                ],
              ),
              Text(
                assignment.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 4),
              if (folder != null)
                Text('In $folder', style: TextStyle(color: c.muted)),
              if (due != null)
                Text(
                  'Due ${loc.formatShortDate(due)} '
                  '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(due), alwaysUse24HourFormat: true)}'
                  '${assignment.isImported ? ' · Set by ${assignment.sourceLabel}' : ''}',
                  style: TextStyle(color: c.muted),
                ),
              Text(
                'Created ${DateText.when(context, assignment.createdAt)}',
                style: TextStyle(fontSize: 12.5, color: c.faint),
              ),
              ClashNotice(lines: widget.clashes),
              if (assignment.details.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(assignment.details, style: TextStyle(color: c.text)),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 6,
                  backgroundColor: c.surface2,
                  color: c.ok,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                progress.isEmpty
                    ? 'No steps yet'
                    : '${progress.done} of ${progress.total} steps done',
                style: TextStyle(
                  fontSize: 12.5,
                  color: ProgressCount.colorOf(c, progress, c.muted),
                ),
              ),
              const SizedBox(height: 8),
              for (final step in steps)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: step.done,
                    onChanged: (_) => _save(step.copyWith(done: !step.done)),
                  ),
                  title: Text(
                    step.title,
                    style: TextStyle(
                      color: step.done ? c.muted : c.text,
                      decoration: step.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: step.start != null && step.end != null
                      ? Text(
                          DateText.range(context, step.start!, step.end!),
                          style: TextStyle(fontSize: 12.5, color: c.muted),
                        )
                      : null,
                  onTap: () => _editStep(step),
                ),
              TextField(
                controller: _newStep,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Add a step',
                  helperText: 'Then choose its From and To times',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add step',
                    onPressed: _addStep,
                  ),
                ),
                onSubmitted: (_) => _addStep(),
              ),
              const SizedBox(height: 16),
              // Finishing every step does not submit the assignment: the
              // user does that (DeskPlan works the same way).
              assignment.done
                  ? OutlinedButton.icon(
                      onPressed: () => _save(assignment.copyWith(done: false)),
                      icon: Icon(Icons.undo, color: c.muted),
                      label: const Text('Submitted. Mark as not submitted'),
                    )
                  : FilledButton.icon(
                      onPressed: () => _save(assignment.copyWith(done: true)),
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: const Text('Mark submitted'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
