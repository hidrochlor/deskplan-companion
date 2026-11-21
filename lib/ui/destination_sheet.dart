import 'package:flutter/material.dart';

import '../features/connection/destination.dart';
import 'theme/deskplan_colors.dart';

/// The list that slides up from the bottom to pick a place on the PC: a
/// first entry (Received files, or Home) and then DeskPlan's folders as a tree.
/// A folder with sub-folders has an arrow that opens and closes it, thin
/// guide lines show how deep each one is, and the path to the current choice
/// starts open. Tap a row to choose it. Pops with the chosen id.
class DestinationSheet extends StatefulWidget {
  final String title;

  /// In the order DeskPlan sends them: each folder is followed by its own
  /// sub-folders, and `depth` says how deep it is.
  final List<Destination> destinations;
  final String selectedId;

  /// The icon of the first entry, which has no folder name of its own.
  final IconData topIcon;

  /// Entries that are assignments, not folders (a note can sit in one).
  final Set<String> assignmentIds;

  const DestinationSheet({
    super.key,
    this.title = 'Send to',
    required this.destinations,
    required this.selectedId,
    this.topIcon = Icons.inbox_outlined,
    this.assignmentIds = const {},
  });

  @override
  State<DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends State<DestinationSheet> {
  static const _indent = 22.0;

  /// Ids of the folders that are open.
  late final Set<String> _open = _pathToSelected();

  /// The folders above the current choice, so it is visible when the sheet
  /// opens.
  Set<String> _pathToSelected() {
    final list = widget.destinations;
    final at = list.indexWhere((d) => d.id == widget.selectedId);
    final open = <String>{};
    if (at < 0) return open;
    var depth = list[at].depth;
    for (var i = at - 1; i >= 0 && depth > 0; i--) {
      if (list[i].depth < depth) {
        open.add(list[i].id);
        depth = list[i].depth;
      }
    }
    return open;
  }

  bool _hasChildren(int i) {
    final list = widget.destinations;
    return i + 1 < list.length &&
        list[i + 1].name != null &&
        list[i + 1].depth > list[i].depth;
  }

  /// The rows to show: everything except what is inside a closed folder.
  List<int> _visibleRows() {
    final list = widget.destinations;
    final rows = <int>[];
    int? closedAtDepth;
    for (var i = 0; i < list.length; i++) {
      final d = list[i];
      if (closedAtDepth != null) {
        if (d.depth > closedAtDepth) continue;
        closedAtDepth = null;
      }
      rows.add(i);
      if (_hasChildren(i) && !_open.contains(d.id)) closedAtDepth = d.depth;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final rows = _visibleRows();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [for (final i in rows) _row(i, c)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int i, DeskPlanColors c) {
    final d = widget.destinations[i];
    final isTop = d.name == null;
    final selected = d.id == widget.selectedId;
    final hasChildren = _hasChildren(i);
    final isOpen = _open.contains(d.id);

    return Padding(
      padding: EdgeInsets.only(bottom: isTop ? 6 : 0),
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.pop(context, d.id),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                // One guide line per level, so how deep a folder is can be
                // seen at a glance.
                for (var level = 0; level < d.depth; level++)
                  Container(
                    width: _indent,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: c.borderSoft, width: 1.5),
                      ),
                    ),
                  ),
                // The arrow, or an empty space of the same width.
                SizedBox(
                  width: 40,
                  child: hasChildren
                      ? IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: isOpen ? 'Close' : 'Open',
                          icon: Icon(
                            isOpen
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            color: c.muted,
                          ),
                          onPressed: () => setState(() {
                            isOpen ? _open.remove(d.id) : _open.add(d.id);
                          }),
                        )
                      : null,
                ),
                if (widget.assignmentIds.contains(d.id))
                  const Icon(
                    Icons.assignment_outlined,
                    color: DeskPlanColors.assignmentKind,
                    size: 22,
                  )
                else
                  Icon(
                    isTop
                        ? widget.topIcon
                        : (isOpen && hasChildren
                              ? Icons.folder_open
                              : Icons.folder_outlined),
                    color: isTop ? c.accent : c.warn,
                    size: 22,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    d.name ?? d.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.check, color: c.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
