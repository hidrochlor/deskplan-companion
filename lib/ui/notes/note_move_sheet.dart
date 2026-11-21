import 'package:flutter/material.dart';

import '../destination_picker.dart';
import '../theme/deskplan_colors.dart';
import 'note_places.dart';

/// Moves a note to Home, a folder or an assignment. Like every other move
/// it changes nothing until Save (CHANGES.md item 2). Pops with the picker
/// id of the new place, or null when cancelled.
class NoteMoveSheet extends StatefulWidget {
  final NotePlaces places;
  final String selectedId;

  const NoteMoveSheet({
    super.key,
    required this.places,
    required this.selectedId,
  });

  static Future<String?> show(
    BuildContext context, {
    required NotePlaces places,
    required String selectedId,
  }) => showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => NoteMoveSheet(places: places, selectedId: selectedId),
  );

  @override
  State<NoteMoveSheet> createState() => _NoteMoveSheetState();
}

class _NoteMoveSheetState extends State<NoteMoveSheet> {
  late String _selected = widget.selectedId;

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move note',
              style: TextStyle(fontWeight: FontWeight.w600, color: c.text),
            ),
            const SizedBox(height: 12),
            DestinationPicker(
              title: 'Put in',
              subtitle: 'Home, a folder or an assignment on your PC',
              topIcon: Icons.home_outlined,
              destinations: widget.places.entries,
              assignmentIds: widget.places.assignmentIds,
              selectedId: _selected,
              onChanged: (id) => setState(() => _selected = id),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
