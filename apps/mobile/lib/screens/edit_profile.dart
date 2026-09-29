import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _sports = ['run', 'ride', 'walk', 'yoga', 'other'];
const _sportLabels = {
  'run': 'Running', 'ride': 'Cycling', 'walk': 'Walking', 'yoga': 'Yoga', 'other': 'Other',
};

const _mobilityOptions = [
  ('none', 'None / Full Mobility', 'Standard training plans with jumping, lunges, full movement'),
  ('wheelchair', 'Wheelchair User', '100% seated, upper-body focused (shoulder press, bicep curls, seated cardio)'),
  ('mobility_impairment', 'Reduced Mobility / Cane / Walker', 'Low-impact standing, chair assistance, no jumping'),
  ('lower_body', 'Lower-Body Limitation', 'Avoid squats, lunges and high-impact leg strain'),
  ('upper_body', 'Upper-Body Limitation', 'Gentle core and lower-body cardio focus'),
  ('bedbound_gentle', 'Gentle Bed / Seated Mobility', 'Gentle flexibility, breathing, seated stretches'),
];

const _medicalConditionOptions = [
  ('fatty_liver', 'Fatty Liver (Grade 1/2)', 'Focus on low-GI, antioxidant-rich, zero added sugar diet'),
  ('diabetes', 'Type 2 Diabetes / Pre-diabetes', 'Strict glycemic index control, complex carbs, high fiber'),
  ('hypertension', 'High Blood Pressure (BP)', 'DASH diet focus: Low sodium, potassium & magnesium rich'),
  ('thyroid', 'Thyroid (Hypo / Hyper)', 'Iodine & selenium balance, anti-inflammatory whole foods'),
  ('gerd_acidity', 'Acidity & Bloating (GERD)', 'Alkaline meals, non-spicy, non-acidic, small frequent portions'),
  ('uric_acid_gout', 'High Uric Acid & Gout', 'Low purine: Avoid red meat & high fructose, stay hydrated'),
  ('pcos', 'PCOS / PCOD', 'Insulin-sensitizing, hormone-balancing nutritious meals'),
  ('cholesterol', 'High Cholesterol', 'Zero trans fat, high soluble fiber (oats, methi, flaxseed)'),
];

/// Edit identity, sport, mobility profile and medical conditions so AI
/// tailors both workouts and diet recommendations accordingly.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    this.initialName = '',
    this.initialCity = '',
    this.initialPrimarySport = 'run',
    this.initialWeightKg = 70.0,
    this.initialDisabilityFlag = false,
    this.initialDisabilityType = 'none',
    this.initialMedicalConditions = const [],
    super.key,
  });

  final String initialName;
  final String initialCity;
  final String initialPrimarySport;
  final double initialWeightKg;
  final bool initialDisabilityFlag;
  final String initialDisabilityType;
  final List<String> initialMedicalConditions;

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

  late bool _disabilityFlag =
      widget.initialDisabilityFlag || (widget.initialDisabilityType.isNotEmpty && widget.initialDisabilityType != 'none');
  late String _disabilityType =
      widget.initialDisabilityType.isNotEmpty ? widget.initialDisabilityType : 'none';
  late final Set<String> _medicalConditions = Set<String>.from(widget.initialMedicalConditions);

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _toggleCondition(String key) {
    setState(() {
      if (_medicalConditions.contains(key)) {
        _medicalConditions.remove(key);
      } else {
        _medicalConditions.add(key);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final isAdaptive = _disabilityFlag && _disabilityType != 'none';
      await context.read<VyraApi>().updateProfile(
            name: _nameController.text.trim(),
            city: _cityController.text.trim(),
            primarySport: _sport,
            weightKg: double.tryParse(_weightController.text),
            disabilityFlag: isAdaptive,
            accessibilityMode: isAdaptive,
            disabilityType: isAdaptive ? _disabilityType : 'none',
            medicalConditions: _medicalConditions.toList(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile, adaptive settings & health preferences updated.')),
        );
        Navigator.of(context).pop(true);
      }
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
        const VSectionHeader('Athlete Identity'),
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                style: const TextStyle(color: VColor.text),
                decoration: const InputDecoration(labelText: 'Name', hintText: 'Your name or athlete handle'),
              ),
              const SizedBox(height: VSpace.base),
              TextField(
                controller: _cityController,
                style: const TextStyle(color: VColor.text),
                decoration: const InputDecoration(labelText: 'City', hintText: 'e.g. New Delhi, Mumbai, Bengaluru'),
              ),
              const SizedBox(height: VSpace.base),
              DropdownButtonFormField<String>(
                initialValue: _sport,
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
                  helperText: 'Used to calibrate calories burned and dietary macro ratios.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.lg),

        // ── Adaptive & Disability Support ────────────────────────────────────
        const VSectionHeader('Adaptive Training & Mobility'),
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _disabilityFlag,
                activeThumbColor: VColor.accent,
                title: const Text(
                  'Physically Differently Abled / Adaptive Mode',
                  style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: const Text(
                  'Tailor AI workout plans to 100% seated or low-impact adaptive exercises.',
                  style: TextStyle(color: VColor.textMid, fontSize: 12.5),
                ),
                onChanged: (val) {
                  setState(() {
                    _disabilityFlag = val;
                    if (val && _disabilityType == 'none') {
                      _disabilityType = 'wheelchair';
                    }
                  });
                },
              ),
              if (_disabilityFlag) ...[
                const Divider(color: VColor.line, height: 24),
                const Text(
                  'Select your mobility profile:',
                  style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: VSpace.sm),
                for (final opt in _mobilityOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(VRadius.md),
                      onTap: () => setState(() => _disabilityType = opt.$1),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _disabilityType == opt.$1
                              ? VColor.accent.withValues(alpha: 0.15)
                              : VColor.surfaceRaised,
                          borderRadius: BorderRadius.circular(VRadius.md),
                          border: Border.all(
                            color: _disabilityType == opt.$1 ? VColor.accent : VColor.line,
                            width: _disabilityType == opt.$1 ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _disabilityType == opt.$1
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: _disabilityType == opt.$1 ? VColor.accent : VColor.textDim,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.$2,
                                    style: TextStyle(
                                      color: _disabilityType == opt.$1 ? VColor.text : VColor.textMid,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    opt.$3,
                                    style: const TextStyle(color: VColor.textDim, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: VSpace.lg),

        // ── Medical Conditions / Body Health ─────────────────────────────────
        const VSectionHeader('Health & Medical Profile (Diet & Nutrition)'),
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select any conditions you currently manage. AI will tailor food recommendations, what to eat, and what strictly NOT to eat:',
                style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: VSpace.md),
              for (final cond in _medicalConditionOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VRadius.md),
                    onTap: () => _toggleCondition(cond.$1),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _medicalConditions.contains(cond.$1)
                            ? VColor.accentGreen.withValues(alpha: 0.15)
                            : VColor.surfaceRaised,
                        borderRadius: BorderRadius.circular(VRadius.md),
                        border: Border.all(
                          color: _medicalConditions.contains(cond.$1) ? VColor.accentGreen : VColor.line,
                          width: _medicalConditions.contains(cond.$1) ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _medicalConditions.contains(cond.$1)
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: _medicalConditions.contains(cond.$1) ? VColor.accentGreen : VColor.textDim,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cond.$2,
                                  style: TextStyle(
                                    color: _medicalConditions.contains(cond.$1) ? VColor.text : VColor.textMid,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cond.$3,
                                  style: const TextStyle(color: VColor.textDim, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.xl),

        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: VColor.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent),
                )
              : const Text(
                  'Save Profile & Preferences',
                  style: TextStyle(color: VColor.textOnAccent, fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),
        const SizedBox(height: VSpace.xl),
      ],
    );
  }
}
