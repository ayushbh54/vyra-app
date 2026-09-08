import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../theme.dart';

const _sports = ['run', 'ride', 'walk', 'yoga', 'other'];
const _sportLabels = {
  'run': 'Running', 'ride': 'Cycling', 'walk': 'Walking', 'yoga': 'Yoga', 'other': 'Other',
};

/// Edit the identity fields shown on the profile header — the Strava
/// equivalent of "Primary Sport", location, and weight (used for calorie
/// estimates elsewhere in the app).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.initialName,
    required this.initialCity,
    required this.initialPrimarySport,
    required this.initialWeightKg,
    super.key,
  });

  final String initialName;
  final String initialCity;
  final String initialPrimarySport;
  final double initialWeightKg;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _cityController = TextEditingController(text: widget.initialCity);
  late final _weightController =
      TextEditingController(text: widget.initialWeightKg.toStringAsFixed(1));
  late String _sport =
      _sports.contains(widget.initialPrimarySport) ? widget.initialPrimarySport : 'run';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<VyraApi>().updateProfile(
            name: _nameController.text.trim(),
            city: _cityController.text.trim(),
            primarySport: _sport,
            weightKg: double.tryParse(_weightController.text),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(VSpace.base),
      children: [
        TextField(
          controller: _nameController,
          style: const TextStyle(color: VColor.text),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: VSpace.base),
        TextField(
          controller: _cityController,
          style: const TextStyle(color: VColor.text),
          decoration: const InputDecoration(labelText: 'City'),
        ),
        const SizedBox(height: VSpace.base),
        DropdownButtonFormField<String>(
          value: _sport,
          dropdownColor: VColor.surfaceRaised,
          style: const TextStyle(color: VColor.text),
          decoration: const InputDecoration(labelText: 'Primary sport'),
          items: [
            for (final s in _sports) DropdownMenuItem(value: s, child: Text(_sportLabels[s]!)),
          ],
          onChanged: (v) => setState(() => _sport = v ?? _sport),
        ),
        const SizedBox(height: VSpace.base),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: VColor.text),
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            helperText: 'Used to estimate calories burned during activities.',
          ),
        ),
        const SizedBox(height: VSpace.lg),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
              : const Text('Save'),
        ),
      ],
    );
  }
}
