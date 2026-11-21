import 'package:flutter/material.dart';

import '../discovery/typed_address_store.dart';
import 'address_dialog.dart';
import 'paste_code_dialog.dart';
import 'pairing_data.dart';
import 'pairing_store.dart';
import 'qr_scan_screen.dart';

/// Shows who the phone is paired with, and lets you pair, re-pair or unpair.
class PairingScreen extends StatefulWidget {
  final PairingStore store;
  final TypedAddressStore addressStore;

  /// Opens the guide on keeping the app syncing while it is closed.
  final VoidCallback onShowBackgroundHelp;

  const PairingScreen({
    super.key,
    required this.store,
    required this.addressStore,
    required this.onShowBackgroundHelp,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  PairingData? _paired;
  String? _typedAddress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.store.load();
    final typed = await widget.addressStore.load();
    if (mounted) {
      setState(() {
        _paired = data;
        _typedAddress = typed;
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Validates [text] and saves it. Shows the reason if it is not valid.
  Future<void> _accept(String text) async {
    final PairingData data;
    try {
      data = PairingData.parse(text.trim());
    } on FormatException catch (e) {
      _toast(e.message);
      return;
    }
    await widget.store.save(data);
    if (!mounted) return;
    setState(() => _paired = data);
    _toast('Paired with ${data.name}');
  }

  Future<void> _scan() async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (text != null) await _accept(text);
  }

  Future<void> _paste() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const PasteCodeDialog(),
    );
    if (text != null) await _accept(text);
  }

  /// The last way of finding the PC: an address typed by hand, used when the
  /// automatic search is blocked and the QR address is out of date.
  Future<void> _editAddress(PairingData paired) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          AddressDialog(current: _typedAddress, defaultPort: paired.port),
    );
    if (result == null) return;
    if (result.isEmpty) {
      await widget.addressStore.clear();
    } else {
      await widget.addressStore.save(result);
    }
    if (mounted) setState(() => _typedAddress = result.isEmpty ? null : result);
  }

  Future<void> _unpair() async {
    await widget.store.clear();
    if (!mounted) return;
    setState(() => _paired = null);
    _toast('Unpaired');
  }

  @override
  Widget build(BuildContext context) {
    final paired = _paired;
    return Scaffold(
      appBar: AppBar(title: const Text('DeskPlan connection')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (paired != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link),
                    title: Text('Paired with ${paired.name}'),
                    subtitle: Text(
                      paired.hint == null
                          ? 'Port ${paired.port}'
                          : '${paired.hint}:${paired.port}',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_location_alt_outlined),
                    title: const Text('PC address (optional)'),
                    subtitle: Text(
                      _typedAddress ??
                          'Not set. Used if DeskPlan is not found by itself.',
                    ),
                    onTap: () => _editAddress(paired),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _scan,
                    child: const Text('Pair again'),
                  ),
                  TextButton(onPressed: _unpair, child: const Text('Unpair')),
                ] else ...[
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.link_off),
                    title: Text('Not paired'),
                    subtitle: Text(
                      'In DeskPlan, open Settings > Phone and scan the code.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR code'),
                  ),
                ],
                TextButton(
                  onPressed: _paste,
                  child: const Text('Paste code instead'),
                ),
                const Divider(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.battery_saver_outlined),
                  title: const Text('Keep syncing in the background'),
                  subtitle: const Text(
                    'Battery settings that let it sync while the app is closed',
                  ),
                  onTap: widget.onShowBackgroundHelp,
                ),
              ],
            ),
    );
  }
}
