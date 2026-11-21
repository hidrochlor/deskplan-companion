import 'package:flutter/material.dart';

import '../discovery/pc_address.dart';

/// Asks for the PC's address, to use when it cannot be found by itself.
/// Pops with the text typed, with an empty string for "Remove", or with null
/// for Cancel. The text field's controller belongs to this dialog, so it is
/// only released once the dialog has fully closed.
class AddressDialog extends StatefulWidget {
  /// What is saved now, to show in the field (null if nothing).
  final String? current;

  /// The port used when none is typed.
  final int defaultPort;

  const AddressDialog({
    super.key,
    required this.current,
    required this.defaultPort,
  });

  @override
  State<AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<AddressDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    try {
      PcAddress.parse(_controller.text, defaultPort: widget.defaultPort);
      Navigator.pop(context, _controller.text.trim());
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PC address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Only needed if DeskPlan cannot be found by itself. '
            'In Windows, the address is under Settings > Network.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: '192.168.1.5',
              helperText:
                  'Port ${widget.defaultPort} is used unless you add one',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
