import 'package:flutter/material.dart';

/// Asks for a link's web address. Pops with the address, an empty text to
/// remove the link, or null when cancelled. Only `http://` and `https://`
/// addresses are taken; a bare "uni.example" gets `https://` in front.
class LinkDialog extends StatefulWidget {
  final String? current;

  const LinkDialog({super.key, this.current});

  static Future<String?> show(BuildContext context, {String? current}) =>
      showDialog<String>(
        context: context,
        builder: (_) => LinkDialog(current: current),
      );

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  late final _address = TextEditingController(text: widget.current ?? '');
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _save() {
    var text = _address.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context, '');
      return;
    }
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!ok) {
      setState(() => _error = 'Enter a web address (https://…)');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.current == null ? 'Add link' : 'Link'),
    content: TextField(
      controller: _address,
      autofocus: true,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(labelText: 'Web address', errorText: _error),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      if (widget.current != null)
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Remove link'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
