import 'package:flutter/material.dart';

import '../features/connection/destination.dart';
import 'destination_sheet.dart';
import 'theme/deskplan_colors.dart';

/// One row showing a chosen place on the PC. Tap to pick another from the
/// sheet that slides up. Used for where a file goes, and for which folder a
/// task or assignment lives in.
class DestinationPicker extends StatelessWidget {
  final List<Destination> destinations;
  final String selectedId;
  final ValueChanged<String> onChanged;

  /// The heading of the sheet, and the small line under the chosen place.
  final String title;
  final String subtitle;

  /// The icon for the first entry (Received files, or Home).
  final IconData topIcon;

  /// Shown when [selectedId] matches nothing, for a choice that must still
  /// be made. Without it the first entry stands in.
  final String? emptyLabel;

  /// Entries that are assignments, not folders (a note can sit in one).
  final Set<String> assignmentIds;

  const DestinationPicker({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onChanged,
    this.title = 'Send to',
    this.subtitle = 'Where it goes on your PC',
    this.topIcon = Icons.inbox_outlined,
    this.emptyLabel,
    this.assignmentIds = const {},
  });

  Destination? get _selected {
    for (final d in destinations) {
      if (d.id == selectedId) return d;
    }
    return emptyLabel == null ? destinations.first : null;
  }

  Future<void> _pick(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DestinationSheet(
        title: title,
        destinations: destinations,
        selectedId: selectedId,
        topIcon: topIcon,
        assignmentIds: assignmentIds,
      ),
    );
    if (id != null) onChanged(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final selected = _selected;
    final isTop = selected != null && selected.name == null;
    final isAssignment =
        selected != null && assignmentIds.contains(selected.id);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: isAssignment
            ? const Icon(
                Icons.assignment_outlined,
                color: DeskPlanColors.assignmentKind,
              )
            : Icon(
                isTop ? topIcon : Icons.folder_open,
                color: selected == null ? c.muted : (isTop ? c.accent : c.warn),
              ),
        title: Text(
          selected?.label ?? emptyLabel!,
          style: selected == null ? TextStyle(color: c.muted) : null,
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.keyboard_arrow_up),
        onTap: () => _pick(context),
      ),
    );
  }
}
