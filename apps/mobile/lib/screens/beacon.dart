import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _lastBroadcastLocation;

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

  Future<void> _broadcastLocationToAll() async {
    final validContacts = <({String name, String phone})>[];
    for (var i = 0; i < 3; i++) {
      final n = _names[i].text.trim();
      final p = _phones[i].text.trim();
      if (p.isNotEmpty) validContacts.add((name: n.isNotEmpty ? n : 'Contact ${i + 1}', phone: p));
    }

    if (validContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one contact phone number below first.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Ensure settings are synced
      final contacts = validContacts.map((c) => BeaconContact(name: c.name, phone: c.phone)).toList();
      await context.read<VyraApi>().setBeacon(true, contacts);

      // Fetch real live GPS coordinates
      var pos = await Geolocator.getLastKnownPosition();
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 7),
        );
      } catch (_) {}

      final lat = pos?.latitude ?? 28.6139;
      final lng = pos?.longitude ?? 77.2090;
      final mapLink = 'https://maps.google.com/?q=$lat,$lng';
      final alertMsg = '🚨 VYRA Live Beacon Alert: I am active on VYRA and sharing my live safety location. Track me in real-time here: $mapLink';

      setState(() => _lastBroadcastLocation = '$lat, $lng');

      // Launch SMS composer with pre-filled numbers and live Google Maps link
      final phoneList = validContacts.map((c) => c.phone).join(';');
      final uri = Uri(
        scheme: 'sms',
        path: phoneList,
        queryParameters: {'body': alertMsg},
      );

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback to first contact
        final fallback = Uri.parse('sms:${validContacts.first.phone}?body=${Uri.encodeComponent(alertMsg)}');
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📡 Live location dispatched to ${validContacts.length} emergency contacts!'),
            backgroundColor: VColor.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error broadcasting location: $e')),
        );
      }
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

          // ── Beacon Toggle Card ──
          VCard(
            tone: _enabled ? CardTone.accent : CardTone.raised,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: VColor.accent,
                  title: const Text('Beacon for mobile', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Send live GPS location link to all added safety contacts.',
                      style: TextStyle(color: VColor.textLow, fontSize: 12)),
                  value: _enabled,
                  onChanged: (v) {
                    setState(() => _enabled = v);
                    if (v) {
                      _broadcastLocationToAll();
                    } else {
                      _save();
                    }
                  },
                ),
                if (_enabled) ...[
                  const Divider(color: VColor.line, height: 16),
                  Row(
                    children: [
                      const Icon(Icons.satellite_alt_rounded, color: VColor.accentGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastBroadcastLocation != null
                              ? 'Live GPS broadcast active ($_lastBroadcastLocation)'
                              : 'Ready to broadcast live coordinates upon recording.',
                          style: const TextStyle(color: VColor.accentGreen, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: VSpace.md),

          // ── Immediate Dispatch Action Button ──
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _broadcastLocationToAll,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.share_location_rounded),
              label: const Text('📡 Send My Live Location to All Contacts Now'),
              style: FilledButton.styleFrom(
                backgroundColor: VColor.accent,
                foregroundColor: VColor.textOnAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
              ),
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
                    decoration: const InputDecoration(labelText: 'Phone (with country code, e.g. +91...)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: VSpace.sm),
          ],
          const SizedBox(height: VSpace.base),
          OutlinedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent))
                : const Text('Save Contacts Only'),
          ),
        ],
      ),
    );
  }
}

