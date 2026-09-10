import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _kMaxContacts = 3;
const _kRelationships = ['Family', 'Doctor', 'Friend', 'Coach', 'Other'];

/// EMERGENCY CONTACTS — a hard "call now" feature, separate from Beacon
/// (beacon.dart), which shares live location during a recorded activity.
/// This screen is about a phone call, not a live map.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContact>? _contacts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<VyraApi>().emergencyContacts();
      if (mounted) setState(() { _contacts = items; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _call(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the dialer.')),
        );
      }
    }
  }

  /// Dials 112 immediately — no confirmation dialog. This is a "help is on
  /// the way right now" button, and every extra tap works against that.
  Future<void> _call112() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the dialer.')),
        );
      }
    }
  }

  Future<void> _addContact() async {
    final result = await showDialog<({String name, String phone, String relationship})>(
      context: context,
      builder: (_) => const _ContactDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await context.read<VyraApi>().addEmergencyContact(
            name: result.name,
            phone: result.phone,
            relationship: result.relationship,
          );
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// The contract has no PATCH for a single contact, so "editing" is done as
  /// delete-then-recreate. If the delete succeeds but the add fails, the
  /// contact is lost — flagged clearly to the person via the error message,
  /// but worth the backend adding a real PATCH endpoint eventually.
  Future<void> _editContact(EmergencyContact contact) async {
    final result = await showDialog<({String name, String phone, String relationship})>(
      context: context,
      builder: (_) => _ContactDialog(
        initialName: contact.name,
        initialPhone: contact.phone,
        initialRelationship: contact.relationship,
      ),
    );
    if (result == null || !mounted) return;
    try {
      final api = context.read<VyraApi>();
      await api.deleteEmergencyContact(contact.id);
      await api.addEmergencyContact(
        name: result.name,
        phone: result.phone,
        relationship: result.relationship,
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        title: const Text('Remove contact?', style: TextStyle(color: VColor.text)),
        content: Text('${contact.name} will no longer be listed here.',
            style: const TextStyle(color: VColor.textMid)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: VColor.crit)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<VyraApi>().deleteEmergencyContact(contact.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final atLimit = (_contacts?.length ?? 0) >= _kMaxContacts;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
        children: [
          Text('Emergency Contacts', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: VSpace.sm),
          const VDisclaimer(
            'Keep up to three people you trust here, so you can reach them fast if '
            'something goes wrong. This is separate from Beacon, which shares your '
            'live location while you record an activity.',
          ),
          const SizedBox(height: VSpace.base),

          // Fixed, prominent emergency button — no confirmation, dials immediately.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _call112,
              icon: const Icon(Icons.emergency_outlined),
              label: const Text('Emergency — Call 112'),
              style: FilledButton.styleFrom(
                backgroundColor: VColor.crit,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, kMinTouchTarget),
              ),
            ),
          ),
          const SizedBox(height: VSpace.lg),

          if (_error != null) VErrorView(message: _error!, onRetry: _load),
          if (_error == null && _contacts == null) const VLoading(label: 'Loading contacts'),

          if (_contacts != null) ...[
            const VSectionHeader('Your contacts'),
            if (_contacts!.isEmpty)
              const VEmptyState(
                title: 'No contacts yet',
                body: 'Add up to three people you\'d want called if something happened.',
              ),
            for (final c in _contacts!) ...[
              VCard(
                tone: CardTone.raised,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.name, style: const TextStyle(
                                  color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(width: VSpace.sm),
                              VPill(c.relationship, tone: CardTone.normal),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(c.phone, style: const TextStyle(color: VColor.textMid, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: VColor.good),
                      tooltip: 'Call',
                      onPressed: () => _call(c.phone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: VColor.textMid),
                      tooltip: 'Edit',
                      onPressed: () => _editContact(c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: VColor.crit),
                      tooltip: 'Remove',
                      onPressed: () => _removeContact(c),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VSpace.sm),
            ],
            const SizedBox(height: VSpace.sm),
            if (!atLimit)
              OutlinedButton.icon(
                onPressed: _addContact,
                icon: const Icon(Icons.add),
                label: const Text('Add contact'),
              )
            else
              const Text(
                'You\'ve reached the limit of 3 contacts. Remove one to add another.',
                style: TextStyle(color: VColor.textLow, fontSize: 12.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.initialName = '', this.initialPhone = '', this.initialRelationship});
  final String initialName;
  final String initialPhone;
  final String? initialRelationship;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _phone = TextEditingController(text: widget.initialPhone);
  late String _relationship = widget.initialRelationship ?? _kRelationships.first;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VColor.surface,
      title: Text(widget.initialName.isEmpty ? 'Add contact' : 'Edit contact',
          style: const TextStyle(color: VColor.text)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            style: const TextStyle(color: VColor.text),
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: VSpace.sm),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: VColor.text),
            decoration: const InputDecoration(labelText: 'Phone (with country code)'),
          ),
          const SizedBox(height: VSpace.sm),
          DropdownButtonFormField<String>(
            initialValue: _relationship,
            dropdownColor: VColor.surfaceRaised,
            style: const TextStyle(color: VColor.text),
            decoration: const InputDecoration(labelText: 'Relationship'),
            items: _kRelationships
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _relationship = v ?? _relationship),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            final phone = _phone.text.trim();
            if (name.isEmpty || phone.isEmpty) return;
            Navigator.pop(context, (name: name, phone: phone, relationship: _relationship));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
