import 'package:flutter/material.dart';

/// Asks for the pairing code as text, for when the QR code cannot be scanned.
/// Pops with the text, or with null for Cancel. It owns its text controller,
/// so the controller is released only after the dialog has fully closed.
class PasteCodeDialog extends StatefulWidget {
  const PasteCodeDialog({super.key});

  @override
  State<PasteCodeDialog> createState() => _PasteCodeDialogState();
}

class _PasteCodeDialogState extends State<PasteCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste pairing code'),
      content: TextField(
        controller: _controller,
        maxLines: 5,
        autofocus: true,
        decoration: const InputDecoration(hintText: '{"v":1,...}'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Pair'),
        ),
      ],
    );
  }
}
