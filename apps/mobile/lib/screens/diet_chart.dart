import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// MY DIET CHART — Targeted Clinical & Ayurvedic Indian Diet Plan
/// Tailored according to specific symptoms and body issues.
/// Clearly delineates "What NOT to eat" and "What to eat" with a 7-slot daily schedule.
class DietChartScreen extends StatefulWidget {
  const DietChartScreen({super.key});

  @override
  State<DietChartScreen> createState() => _DietChartScreenState();
}

class _DietChartScreenState extends State<DietChartScreen> {
  final Set<String> _selectedSymptoms = {'🔥 Acidity & Bloating (GERD)'};
  final TextEditingController _customController = TextEditingController();
  String _dietPreference = 'vegetarian';

  DietChart? _chart;
  bool _loading = false;
  String? _error;

  static const List<String> _commonSymptoms = [
    '🔥 Acidity & Bloating (GERD)',
    '🩸 High Blood Sugar (Diabetes)',
    '🦋 Thyroid / PCOS / PCOD',
    '🫀 High Cholesterol & BP',
    '🥩 High Uric Acid & Gout',
    '🩺 Fatty Liver (Grade 1/2)',
    '🦴 Joint Pain & Arthritis',
    '⚖️ Belly Fat & Weight Loss',
    '💪 Muscle Building & High Protein',
    '✨ Skin Acne & Hair Fall',
    '⚡ Chronic Fatigue & Low Energy',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileAndFetchChart();
  }

  Future<void> _loadProfileAndFetchChart() async {
    try {
      final p = await context.read<VyraApi>().getProfile();
      if (p.medicalConditions.isNotEmpty) {
        final mapped = <String>{};
        for (final c in p.medicalConditions) {
          switch (c) {
            case 'fatty_liver':
              mapped.add('🩺 Fatty Liver (Grade 1/2)');
              break;
            case 'diabetes':
              mapped.add('🩸 High Blood Sugar (Diabetes)');
              break;
            case 'hypertension':
            case 'cholesterol':
              mapped.add('🫀 High Cholesterol & BP');
              break;
            case 'thyroid':
            case 'pcos':
              mapped.add('🦋 Thyroid / PCOS / PCOD');
              break;
            case 'gerd_acidity':
              mapped.add('🔥 Acidity & Bloating (GERD)');
              break;
            case 'uric_acid_gout':
              mapped.add('🥩 High Uric Acid & Gout');
              break;
          }
        }
        if (mapped.isNotEmpty && mounted) {
          setState(() {
            _selectedSymptoms.clear();
            _selectedSymptoms.addAll(mapped);
          });
        }
      }
    } catch (_) {}
    if (mounted) _fetchChart();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggleSymptom(String symptom) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        if (_selectedSymptoms.length > 1) {
          _selectedSymptoms.remove(symptom);
        }
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  Future<void> _fetchChart() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<VyraApi>();
      final custom = _customController.text.trim();
      final chart = await api.generateDietChart(
        symptoms: _selectedSymptoms.toList(),
        customCondition: custom.isNotEmpty ? custom : null,
        preference: _dietPreference,
      );
      if (mounted) {
        setState(() {
          _chart = chart;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to generate diet chart right now. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: VColor.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My AI Diet Chart',
            style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: VColor.accent),
            tooltip: 'Regenerate',
            onPressed: _loading ? null : _fetchChart,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.xs, VSpace.base, VSpace.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Hero Banner
            Container(
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [VColor.accent.withValues(alpha: 0.15), VColor.surfaceRaised],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(VRadius.lg),
                border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: VColor.accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded, color: VColor.accent, size: 24),
                  ),
                  const SizedBox(width: VSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Symptom-Targeted Nutrition',
                            style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Select your body issues below — AI will prescribe exact foods to avoid & eat.',
                            style: TextStyle(color: VColor.textMid, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: VSpace.base),

            // ── Symptom / Body Issues Selector ──────────────────────────────
            const VLabel('SELECT BODY ISSUES & SYMPTOMS'),
            const SizedBox(height: VSpace.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonSymptoms.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  onSelected: (_) => _toggleSymptom(symptom),
                  selectedColor: VColor.accent.withValues(alpha: 0.25),
                  backgroundColor: VColor.surface,
                  checkmarkColor: VColor.accent,
                  labelStyle: TextStyle(
                    color: isSelected ? VColor.accent : VColor.textMid,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(color: isSelected ? VColor.accent : VColor.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                );
              }).toList(),
            ),
            const SizedBox(height: VSpace.sm),

            // Custom symptom input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customController,
                    style: const TextStyle(color: VColor.text, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Add other issues (e.g. migraine, constipation)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _fetchChart,
                  style: FilledButton.styleFrom(
                    backgroundColor: VColor.accent,
                    foregroundColor: VColor.textOnAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
                  ),
                  child: const Text('Update'),
                ),
              ],
            ),
            const SizedBox(height: VSpace.lg),

            // ── Dietary Preference Selector ─────────────────────────────────
            Row(
              children: [
                const VLabel('DIETARY PREFERENCE:'),
                const Spacer(),
                DropdownButton<String>(
                  value: _dietPreference,
                  dropdownColor: VColor.surfaceRaised,
                  style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.w700, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'vegetarian', child: Text('Vegetarian')),
                    DropdownMenuItem(value: 'eggetarian', child: Text('Eggetarian')),
                    DropdownMenuItem(value: 'non_vegetarian', child: Text('Non-Vegetarian')),
                    DropdownMenuItem(value: 'jain', child: Text('Jain (No Root Veg)')),
                  ],
                  onChanged: (val) {
                    if (val != null && val != _dietPreference) {
                      setState(() => _dietPreference = val);
                      _fetchChart();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: VSpace.md),

            // ── Loading / Error / Results ───────────────────────────────────
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: VSpace.xxl),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: VColor.accent),
                      SizedBox(height: VSpace.md),
                      Text('Consulting clinical database & tailoring Indian meal plan…',
                          style: TextStyle(color: VColor.textMid, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              VErrorView(message: _error!, onRetry: _fetchChart)
            else if (_chart != null)
              _buildChartContent(_chart!),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent(DietChart chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Clinical Overview
        VCard(
          tone: CardTone.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(chart.title,
                  style: const TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: VSpace.xs),
              Text(chart.conditionSummary,
                  style: const TextStyle(color: VColor.textMid, fontSize: 13, height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: VSpace.lg),

        // ── WHAT NOT TO EAT (STRICT FOODS TO AVOID) ─────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: VColor.warn.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(VRadius.sm),
            border: Border.all(color: VColor.warn.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.cancel_rounded, color: VColor.warn, size: 18),
              SizedBox(width: 8),
              Text('WHAT NOT TO EAT (TRIGGER FOODS TO AVOID)',
                  style: TextStyle(color: VColor.warn, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
            ],
          ),
        ),
        const SizedBox(height: VSpace.sm),
        for (final item in chart.foodsToAvoid)
          Padding(
            padding: const EdgeInsets.only(bottom: VSpace.sm),
            child: Container(
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(VRadius.md),
                border: Border.all(color: VColor.warn.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.not_interested_rounded, size: 16, color: VColor.warn),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(item.item,
                            style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 14.5)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: VColor.warn.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(VRadius.sm),
                        ),
                        child: Text(item.category,
                            style: const TextStyle(color: VColor.warn, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('⚠️ Why avoid: ${item.reason}',
                      style: const TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
          ),
        const SizedBox(height: VSpace.lg),

        // ── WHAT TO EAT (HEALING ESSENTIALS) ────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: VColor.accentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(VRadius.sm),
            border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: VColor.accentGreen, size: 18),
              SizedBox(width: 8),
              Text('WHAT TO EAT (HEALING SUPERFOODS & NOURISHMENT)',
                  style: TextStyle(
                      color: VColor.accentGreen, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
            ],
          ),
        ),
        const SizedBox(height: VSpace.sm),
        for (final item in chart.foodsToEat)
          Padding(
            padding: const EdgeInsets.only(bottom: VSpace.sm),
            child: Container(
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(VRadius.md),
                border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.eco_rounded, size: 16, color: VColor.accentGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(item.item,
                            style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 14.5)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: VColor.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(VRadius.sm),
                        ),
                        child: Text(item.category,
                            style:
                                const TextStyle(color: VColor.accentGreen, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('✨ Benefit: ${item.benefit}',
                      style: const TextStyle(color: VColor.text, fontSize: 12.5, height: 1.35)),
                  const SizedBox(height: 4),
                  Text('🥄 How to take: ${item.howToConsume}',
                      style: const TextStyle(color: VColor.textMid, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        const SizedBox(height: VSpace.lg),

        // ── FULL DAY MEAL TIMETABLE (7 SLOTS) ──────────────────────────────
        const VLabel('COMPLETE DAY-LONG MEAL SCHEDULE'),
        const SizedBox(height: VSpace.sm),
        for (final slot in chart.mealPlan)
          Padding(
            padding: const EdgeInsets.only(bottom: VSpace.md),
            child: VCard(
              tone: CardTone.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _slotIcon(slot.slot),
                          const SizedBox(width: 8),
                          Text(slot.slot,
                              style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: VColor.surfaceRaised,
                          borderRadius: BorderRadius.circular(VRadius.sm),
                          border: Border.all(color: VColor.line),
                        ),
                        child: Text(slot.timeRange,
                            style: const TextStyle(color: VColor.accent, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(slot.title,
                      style: const TextStyle(color: VColor.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: VSpace.sm),
                  const Divider(color: VColor.line, height: 12),
                  for (final item in slot.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 5, color: VColor.accentGreen),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(item,
                                  style: const TextStyle(color: VColor.text, fontSize: 13, height: 1.35))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text('💡 ${slot.rationale}',
                      style: const TextStyle(color: VColor.textMid, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
          ),
        const SizedBox(height: VSpace.md),

        // ── HYDRATION & HERBAL REMEDIES ─────────────────────────────────────
        if (chart.hydrationGuidelines.isNotEmpty) ...[
          const VLabel('HYDRATION & WATER TIMING RULES'),
          const SizedBox(height: VSpace.sm),
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in chart.hydrationGuidelines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.water_drop_rounded, size: 16, color: VColor.accent),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(rule, style: const TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.4))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),
        ],

        if (chart.herbalRemedies.isNotEmpty) ...[
          const VLabel('AYURVEDIC KITCHEN REMEDIES'),
          const SizedBox(height: VSpace.sm),
          for (final remedy in chart.herbalRemedies)
            Padding(
              padding: const EdgeInsets.only(bottom: VSpace.xs),
              child: VCard(
                tone: CardTone.raised,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_florist_rounded, size: 20, color: VColor.accentGreen),
                    const SizedBox(width: VSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(remedy.remedy,
                              style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('⏰ When: ${remedy.timing}',
                              style: const TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('🎯 Purpose: ${remedy.purpose}',
                              style: const TextStyle(color: VColor.textMid, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: VSpace.base),
        ],

        if (chart.goldenRules.isNotEmpty) ...[
          const VLabel('GOLDEN METABOLIC RULES'),
          const SizedBox(height: VSpace.sm),
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in chart.goldenRules)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: VColor.accentOrange),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(rule, style: const TextStyle(color: VColor.text, fontSize: 12.5, height: 1.4))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: VSpace.lg),
        const VDisclaimer(
          'This diet chart is powered by AI and clinical nutrition guidelines. It is for health optimization '
          'and metabolic balance, not a prescription. Consult your physician for medical management.',
        ),
      ],
    );
  }

  Widget _slotIcon(String slot) {
    final s = slot.toLowerCase();
    if (s.contains('morning') && s.contains('early')) {
      return const Icon(Icons.wb_twilight_rounded, color: VColor.accentOrange, size: 20);
    }
    if (s.contains('breakfast')) {
      return const Icon(Icons.bakery_dining_rounded, color: VColor.accent, size: 20);
    }
    if (s.contains('mid')) {
      return const Icon(Icons.local_cafe_rounded, color: VColor.accentGreen, size: 20);
    }
    if (s.contains('lunch')) {
      return const Icon(Icons.restaurant_rounded, color: VColor.accent, size: 20);
    }
    if (s.contains('evening')) {
      return const Icon(Icons.emoji_food_beverage_rounded, color: VColor.accentOrange, size: 20);
    }
    if (s.contains('dinner')) {
      return const Icon(Icons.soup_kitchen_rounded, color: VColor.accent, size: 20);
    }
    return const Icon(Icons.bedtime_rounded, color: VColor.accent, size: 20);
  }
}
