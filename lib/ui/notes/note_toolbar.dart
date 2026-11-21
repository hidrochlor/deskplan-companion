import 'package:flutter/material.dart';

import '../../features/notes/note_block.dart';
import '../theme/deskplan_colors.dart';

/// The thin bar above the keyboard while a line is being written: what the
/// line is, indent, bold / italic / strikethrough, and links
/// (docs/DESIGN.md "Note page"). It never takes the keyboard's focus.
class NoteToolbar extends StatelessWidget {
  final NoteBlockType lineType;
  final bool Function(String mark) isOn;
  final bool inLink;
  final bool canIndent;
  final bool canOutdent;
  final ValueChanged<NoteBlockType> onType;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final ValueChanged<String> onMark;
  final VoidCallback onLink;
  final VoidCallback onOpenLink;

  const NoteToolbar({
    super.key,
    required this.lineType,
    required this.isOn,
    required this.inLink,
    required this.canIndent,
    required this.canOutdent,
    required this.onType,
    required this.onIndent,
    required this.onOutdent,
    required this.onMark,
    required this.onLink,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    Widget sep() => Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: c.borderSoft,
    );

    return TextFieldTapRegion(
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ToolButton(
                label: 'Text',
                tooltip: 'Normal text',
                active: lineType == NoteBlockType.paragraph,
                onTap: () => onType(NoteBlockType.paragraph),
              ),
              _ToolButton(
                label: 'H1',
                tooltip: 'Heading 1',
                active: lineType == NoteBlockType.heading1,
                onTap: () => onType(NoteBlockType.heading1),
              ),
              _ToolButton(
                label: 'H2',
                tooltip: 'Heading 2',
                active: lineType == NoteBlockType.heading2,
                onTap: () => onType(NoteBlockType.heading2),
              ),
              _ToolButton(
                icon: Icons.format_list_bulleted,
                tooltip: 'Bulleted list',
                active: lineType == NoteBlockType.bullet,
                onTap: () => onType(NoteBlockType.bullet),
              ),
              _ToolButton(
                icon: Icons.checklist,
                tooltip: 'Checklist',
                active: lineType == NoteBlockType.task,
                onTap: () => onType(NoteBlockType.task),
              ),
              sep(),
              _ToolButton(
                icon: Icons.format_indent_decrease,
                tooltip: 'Outdent',
                onTap: canOutdent ? onOutdent : null,
              ),
              _ToolButton(
                icon: Icons.format_indent_increase,
                tooltip: 'Indent',
                onTap: canIndent ? onIndent : null,
              ),
              sep(),
              _ToolButton(
                icon: Icons.format_bold,
                tooltip: 'Bold',
                active: isOn('bold'),
                onTap: () => onMark('bold'),
              ),
              _ToolButton(
                icon: Icons.format_italic,
                tooltip: 'Italic',
                active: isOn('italic'),
                onTap: () => onMark('italic'),
              ),
              _ToolButton(
                icon: Icons.format_strikethrough,
                tooltip: 'Strikethrough',
                active: isOn('strike'),
                onTap: () => onMark('strike'),
              ),
              sep(),
              _ToolButton(
                icon: Icons.link,
                tooltip: inLink ? 'Change or remove link' : 'Link',
                active: inLink,
                onTap: onLink,
              ),
              if (inLink)
                _ToolButton(
                  icon: Icons.open_in_new,
                  tooltip: 'Open link',
                  onTap: onOpenLink,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One button of the bar: an icon or a short label, `accent-soft` when on.
class _ToolButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final bool active;
  final VoidCallback? onTap;

  const _ToolButton({
    this.icon,
    this.label,
    required this.tooltip,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    final color = onTap == null
        ? c.faint
        : active
        ? c.accent
        : c.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: active ? c.accentSoft : c.surface2,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            canRequestFocus: false,
            onTap: onTap,
            child: SizedBox(
              height: 36,
              width: label == null ? 38 : 42,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 19, color: color)
                    : Text(
                        label!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
