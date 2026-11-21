import 'package:flutter/material.dart';

import '../features/connection/connection_light.dart';
import 'theme/deskplan_colors.dart';

/// The link icon in the app bar with a small coloured dot, like the phone
/// icon on DeskPlan's top bar: grey (not paired), blue (paired, PC not
/// reached), green (connected), amber (needs attention), red (pair again).
class ConnectionIconButton extends StatelessWidget {
  final ConnectionLight light;
  final VoidCallback onPressed;

  const ConnectionIconButton({
    super.key,
    required this.light,
    required this.onPressed,
  });

  Color _color(DeskPlanColors c) => switch (light) {
    ConnectionLight.off => c.faint,
    ConnectionLight.idle => c.accent,
    ConnectionLight.connected => c.ok,
    ConnectionLight.attention => c.warn,
    ConnectionLight.problem => c.danger,
  };

  @override
  Widget build(BuildContext context) {
    final c = DeskPlanColors.of(context);
    return IconButton(
      tooltip: light.description,
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.link),
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: _color(c),
                shape: BoxShape.circle,
                // A ring in the bar's colour keeps the dot readable.
                border: Border.all(color: c.frame, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
