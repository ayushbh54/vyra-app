import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// BEACON — share your location with up to three trusted contacts while
/// recording. This is a safety feature, not a social one: contacts are never
/// shown anywhere else in the app.
class BeaconScreen extends StatefulWidget {
  const BeaconScreen({super.key});

  @override
  State<BeaconScreen> createState() => _BeaconScreenState();
}

class _BeaconScreenState extends State<BeaconScreen> {
  bool _enabled = false;
  final List<TextEditingController> _names = [];
  final List<TextEditingController> _phones = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._names, ..._phones]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final state = await context.read<VyraApi>().beacon();
      _enabled = state.enabled;
      _names
        ..clear()
        ..addAll(List.generate(3, (i) =>
            TextEditingController(text: i < state.contacts.length ? state.contacts[i].name : '')));
      _phones
        ..clear()
        ..addAll(List.generate(3, (i) =>
            TextEditingController(text: i < state.contacts.length ? state.contacts[i].phone : '')));
      if (mounted) setState(() => _error = null);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final contacts = <BeaconContact>[];
    for (var i = 0; i < 3; i++) {
      final name = _names[i].text.trim();
      final phone = _phones[i].text.trim();
      if (name.isNotEmpty && phone.isNotEmpty) contacts.add(BeaconContact(name: name, phone: phone));
    }
    try {
      await context.read<VyraApi>().setBeacon(_enabled, contacts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beacon settings saved.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const VLoading(label: 'Loading Beacon');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
        children: [
          Text('Beacon', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: VSpace.sm),
          const VDisclaimer(
            'Share a Beacon with up to three safety contacts so they can see your '
            'live location while you record an activity. This is separate from '
            'anything you post — contacts never appear anywhere else in VYRA.',
          ),
          const SizedBox(height: VSpace.base),
          if (_error != null) VErrorView(message: _error!, onRetry: _load),
          VCard(
            tone: CardTone.raised,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: VColor.accent,
              title: const Text('Beacon for mobile'),
              subtitle: const Text('Send your location from this device while recording.',
                  style: TextStyle(color: VColor.textLow, fontSize: 12)),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
          const SizedBox(height: VSpace.base),
          const VSectionHeader('Safety contacts'),
          for (var i = 0; i < 3; i++) ...[
            VCard(
              tone: CardTone.raised,
              child: Column(
                children: [
                  TextField(
                    controller: _names[i],
                    style: const TextStyle(color: VColor.text),
                    decoration: InputDecoration(labelText: 'Contact ${i + 1} name'),
                  ),
                  const SizedBox(height: VSpace.sm),
                  TextField(
                    controller: _phones[i],
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: VColor.text),
                    decoration: const InputDecoration(labelText: 'Phone (with country code)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: VSpace.sm),
          ],
          const SizedBox(height: VSpace.base),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
                : const Text('Save Beacon settings'),
          ),
        ],
      ),
    );
  }
}
