import 'package:flutter/material.dart';

import 'sync_dots.dart';

/// A rounded pill with [SyncDots] and a short line ("Syncing with
/// Office-PC…"), tinted in [color]: a faint fill, a thin edge, the text and
/// dots in the colour itself.
class SyncPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool animate;

  const SyncPill({
    super.key,
    required this.label,
    required this.color,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 16, 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SyncDots(color: color, animate: animate),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
