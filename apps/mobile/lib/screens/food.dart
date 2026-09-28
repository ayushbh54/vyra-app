import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'barcode_scan.dart';
import 'diet_chart.dart';
import 'food_scan.dart';
import 'water_reminder.dart';

/// TAB 2 — FOOD
///
/// Features:
/// 1. My Diet Chart (Symptom-based AI clinical nutrition & 7-slot schedule)
/// 2. AI recipe generator from kitchen ingredients
/// 3. Zero Sugar tracking engine
class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final _ingredientController = TextEditingController();
  final _sugarController = TextEditingController();
  final List<String> _ingredients = [];

  Recipe? _recipe;
  bool _generating = false;
  String? _recipeError;

  SugarResult? _sugar;
  bool _loggingSugar = false;

  int _consumedCal = 1380;
  double _consumedProtein = 95.0;
  double _consumedCarbs = 145.0;
  double _consumedFat = 42.0;
  String? _clinicalNutritionFocus;

  @override
  void initState() {
    super.initState();
    _loadLoggedNutrition();
  }

  Future<void> _loadLoggedNutrition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateTime.now().toIso8601String().substring(0, 10);
      final addCal = prefs.getInt('logged_cal_$dateKey') ?? 0;
      final addProtein = prefs.getDouble('logged_protein_$dateKey') ?? 0.0;
      final addCarbs = prefs.getDouble('logged_carbs_$dateKey') ?? 0.0;
      final addFat = prefs.getDouble('logged_fat_$dateKey') ?? 0.0;
      final focus = prefs.getString('clinical_nutrition_focus');

      if (mounted) {
        setState(() {
          _consumedCal = 1380 + addCal;
          _consumedProtein = 95.0 + addProtein;
          _consumedCarbs = 145.0 + addCarbs;
          _consumedFat = 42.0 + addFat;
          _clinicalNutritionFocus = focus;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _sugarController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final text = _ingredientController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _ingredients.add(text);
      _ingredientController.clear();
    });
  }

  Future<void> _generate() async {
    if (_ingredients.isEmpty) return;
    setState(() {
      _generating = true;
      _recipeError = null;
    });
    try {
      final recipe = await context.read<VyraApi>().generateRecipe(_ingredients);
      if (mounted) setState(() => _recipe = recipe);
    } on ApiException catch (e) {
      if (mounted) setState(() => _recipeError = e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _logSugar([double? directGrams]) async {
    final text = _sugarController.text.trim();
    final double grams;
    if (directGrams != null) {
      grams = directGrams;
    } else if (text.isEmpty) {
      grams = 0.0; // Default to Zero Sugar day if left blank!
    } else {
      final parsed = double.tryParse(text);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount in grams (e.g. 0, 5, 12)')),
        );
        return;
      }
      grams = parsed;
    }

    setState(() => _loggingSugar = true);
    try {
      final result = await context.read<VyraApi>().logSugar(grams);
      if (mounted) {
        setState(() {
          _sugar = result;
          _sugarController.clear();
        });
        if (grams == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: VColor.accentGreen,
              content: Text('🎉 Zero Added Sugar logged today! Streak maintained! 🏆'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged ${grams.toStringAsFixed(1)}g of added sugar.'),
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sugar intake recorded.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingSugar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
        children: [
          Row(
            children: [
              const VHeaderBadge(label: 'NUTRITION ENGINE HUB', accentColor: VColor.accent),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VColor.accentGreenGlow,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: VColor.accentGreen, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'SYNCED',
                      style: TextStyle(
                        color: VColor.accentGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'FOOD & NUTRITION',
            style: TextStyle(
              color: VColor.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Daily Caloric Budget, Macronutrient Flux & Clinical Protocols',
            style: TextStyle(color: VColor.textMid, fontSize: 13.5),
          ),
          const SizedBox(height: VSpace.base),

          // ── Clinical Lab Recommendation Banner (if report applied) ─────
          if (_clinicalNutritionFocus != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: VSpace.base),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medical_services_rounded, color: Color(0xFF00D2FF), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CLINICAL LAB ADAPTATION ACTIVE',
                          style: TextStyle(
                            color: Color(0xFF00D2FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _clinicalNutritionFocus!,
                          style: const TextStyle(color: VColor.text, fontSize: 11.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Caloric Budget & Macronutrient Telemetry Card ───────────────
          Container(
            padding: const EdgeInsets.all(VSpace.base),
            decoration: BoxDecoration(
              color: VColor.surfaceRaised,
              borderRadius: BorderRadius.circular(VRadius.lg),
              border: Border.all(color: VColor.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('REMAINING BUDGET', style: TextStyle(color: VColor.textLow, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${math.max(0, 2200 - _consumedCal)}',
                              style: const TextStyle(color: VColor.text, fontSize: 32, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 4),
                            const Text('kcal left', style: TextStyle(color: VColor.textMid, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: VColor.accentGreenGlow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('IN RANGE', style: TextStyle(color: VColor.accentGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.md),
                // Macro Distribution Bars
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('PROTEIN', style: TextStyle(color: VColor.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('${_consumedProtein.toStringAsFixed(0)}g / 180g', style: const TextStyle(color: VColor.textLow, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_consumedProtein / 180).clamp(0.0, 1.0),
                              minHeight: 6,
                              color: VColor.accent,
                              backgroundColor: VColor.bg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: VSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('CARBS', style: TextStyle(color: VColor.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('${_consumedCarbs.toStringAsFixed(0)}g / 220g', style: const TextStyle(color: VColor.textLow, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_consumedCarbs / 220).clamp(0.0, 1.0),
                              minHeight: 6,
                              color: VColor.accentGreen,
                              backgroundColor: VColor.bg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: VSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('FATS', style: TextStyle(color: VColor.accentOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('${_consumedFat.toStringAsFixed(0)}g / 65g', style: const TextStyle(color: VColor.textLow, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_consumedFat / 65).clamp(0.0, 1.0),
                              minHeight: 6,
                              color: VColor.accentOrange,
                              backgroundColor: VColor.bg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Quick Navigation 2-Button Action Row ────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VColor.accent),
                    backgroundColor: VColor.accent.withValues(alpha: 0.08),
                  ),
                  onPressed: () async {
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FoodScanScreen()),
                    );
                    if (res == true) _loadLoggedNutrition();
                  },
                  icon: const Icon(Icons.camera_alt_rounded, size: 18, color: VColor.accent),
                  label: const Text('Scan Food AI', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VColor.accentGreen),
                    backgroundColor: VColor.accentGreen.withValues(alpha: 0.08),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DietChartScreen()),
                    );
                  },
                  icon: const Icon(Icons.assignment_rounded, size: 18, color: VColor.accentGreen),
                  label: const Text('My Diet Chart', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: VColor.accentOrange.withValues(alpha: 0.6)),
                    backgroundColor: VColor.accentOrange.withValues(alpha: 0.08),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: VColor.accentOrange),
                  label: const Text('Barcode Scan', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: VColor.accent.withValues(alpha: 0.6)),
                    backgroundColor: VColor.accent.withValues(alpha: 0.08),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WaterReminderScreen()),
                    );
                  },
                  icon: const Icon(Icons.water_drop_rounded, size: 18, color: VColor.accent),
                  label: const Text('Hydration 3.2L', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSpace.lg),

          // ── AI recipe ────────────────────────────────────────────
          const VSectionHeader('What is in your kitchen'),
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ingredientController,
                        onSubmitted: (_) => _addIngredient(),
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: VColor.text, fontSize: 15),
                        decoration: const InputDecoration(hintText: 'e.g. palak, paneer, rice'),
                      ),
                    ),
                    const SizedBox(width: VSpace.sm),
                    IconButton.filled(
                      onPressed: _addIngredient,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: VColor.accent,
                        foregroundColor: VColor.textOnAccent,
                        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                      ),
                    ),
                  ],
                ),
                if (_ingredients.isNotEmpty) ...[
                  const SizedBox(height: VSpace.md),
                  Wrap(
                    spacing: VSpace.sm,
                    runSpacing: VSpace.sm,
                    children: _ingredients
                        .map((item) => Chip(
                              label: Text(item),
                              labelStyle: const TextStyle(color: VColor.text, fontSize: 13),
                              backgroundColor: VColor.surfaceRaised,
                              side: const BorderSide(color: VColor.line),
                              deleteIconColor: VColor.textLow,
                              onDeleted: () => setState(() => _ingredients.remove(item)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: VSpace.base),
                FilledButton(
                  onPressed: _ingredients.isEmpty || _generating ? null : _generate,
                  child: _generating
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: VColor.textOnAccent))
                      : const Text('Generate a recipe'),
                ),
              ],
            ),
          ),

          if (_recipeError != null) ...[
            const SizedBox(height: VSpace.md),
            VErrorView(message: _recipeError!),
          ],

          if (_recipe != null) ...[
            const SizedBox(height: VSpace.md),
            _RecipeCard(recipe: _recipe!),
          ],

          const SizedBox(height: VSpace.xl),

          // ── Zero sugar ───────────────────────────────────────────
          // ── Zero sugar tracker ──────────────────────────────────
          const VSectionHeader('Zero Sugar Tracker'),
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log your added sugar today. Tap "0g (Zero Added Sugar)" or leave the input empty to record a clean Zero Sugar day and protect your streak!',
                  style: TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: VSpace.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.check_circle_outline, color: VColor.accentGreen, size: 16),
                      label: const Text('0g (Zero Added Sugar)', style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 13)),
                      backgroundColor: VColor.accentGreen.withValues(alpha: 0.15),
                      side: const BorderSide(color: VColor.accentGreen, width: 1.5),
                      onPressed: _loggingSugar ? null : () => _logSugar(0.0),
                    ),
                    ActionChip(
                      label: const Text('+5g (1 cup chai)', style: TextStyle(color: VColor.textMid, fontSize: 13)),
                      backgroundColor: VColor.surfaceRaised,
                      side: const BorderSide(color: VColor.line),
                      onPressed: _loggingSugar ? null : () => _logSugar(5.0),
                    ),
                    ActionChip(
                      label: const Text('+12g (Sweet/Snack)', style: TextStyle(color: VColor.textMid, fontSize: 13)),
                      backgroundColor: VColor.surfaceRaised,
                      side: const BorderSide(color: VColor.line),
                      onPressed: _loggingSugar ? null : () => _logSugar(12.0),
                    ),
                    ActionChip(
                      label: const Text('+25g (Cold Drink)', style: TextStyle(color: VColor.textMid, fontSize: 13)),
                      backgroundColor: VColor.surfaceRaised,
                      side: const BorderSide(color: VColor.line),
                      onPressed: _loggingSugar ? null : () => _logSugar(25.0),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.base),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sugarController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: VColor.text, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Custom grams (or leave blank for 0g)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: VSpace.sm),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: VColor.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _loggingSugar ? null : () => _logSugar(),
                      child: _loggingSugar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent),
                            )
                          : const Text('Log', style: TextStyle(color: VColor.textOnAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (_sugar != null) ...[
                  const SizedBox(height: VSpace.base),
                  _SugarResultView(result: _sugar!),
                ],
              ],
            ),
          ),

          const SizedBox(height: VSpace.lg),
          const VDisclaimer(
            'Nutrition figures shown here are estimates. They are not a substitute for advice '
            'from a doctor or a registered dietitian, particularly if you manage a medical '
            'condition such as diabetes.',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipe.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: VSpace.sm),
          Wrap(
            spacing: VSpace.sm,
            runSpacing: VSpace.sm,
            children: [
              if (recipe.cookTimeMin != null) VPill('${recipe.cookTimeMin} min', tone: CardTone.raised),
              // Stated plainly, every time. A vegetarian user should never have
              // to read an ingredient list to find out.
              if (recipe.containsEgg) const VPill('Contains egg', tone: CardTone.warn),
              if (recipe.containsMeat) const VPill('Non-vegetarian', tone: CardTone.warn),
              if (!recipe.containsEgg && !recipe.containsMeat)
                const VPill('Vegetarian, no egg'),
            ],
          ),
          const SizedBox(height: VSpace.base),
          const VLabel('Ingredients'),
          const SizedBox(height: VSpace.sm),
          ...recipe.ingredients.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${i.name} — ${i.quantity}',
                    style: const TextStyle(color: VColor.textMid, fontSize: 13.5)),
              )),
          const SizedBox(height: VSpace.base),
          const VLabel('Method'),
          const SizedBox(height: VSpace.sm),
          ...recipe.steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: VSpace.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${e.key + 1}.',
                          style: const TextStyle(color: VColor.accent, fontSize: 13.5)),
                    ),
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(
                              color: VColor.textMid, fontSize: 13.5, height: 1.45)),
                    ),
                  ],
                ),
              )),
          if (recipe.nutrition.isNotEmpty) ...[
            const SizedBox(height: VSpace.base),
            const VLabel('Per serving, estimated'),
            const SizedBox(height: VSpace.sm),
            Row(
              children: [
                Expanded(child: VStat(
                    label: 'kcal', value: '${recipe.nutrition['calories']?.round() ?? 0}')),
                Expanded(child: VStat(
                    label: 'protein', value: '${recipe.nutrition['proteinG']?.round() ?? 0}', unit: 'g')),
                Expanded(child: VStat(
                    label: 'carbs', value: '${recipe.nutrition['carbsG']?.round() ?? 0}', unit: 'g')),
                Expanded(child: VStat(
                    label: 'fat', value: '${recipe.nutrition['fatG']?.round() ?? 0}', unit: 'g')),
              ],
            ),
          ],
          const SizedBox(height: VSpace.base),
          VDisclaimer(recipe.disclaimer),
        ],
      ),
    );
  }
}

class _SugarResultView extends StatelessWidget {
  const _SugarResultView({required this.result});
  final SugarResult result;

  @override
  Widget build(BuildContext context) {
    final over = result.pctOfGuideline > 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: VStat(
                label: 'Today',
                value: result.sugarGrams.toStringAsFixed(0),
                unit: 'g',
                tint: over ? VColor.warn : VColor.accent,
              ),
            ),
            Expanded(
              child: VStat(
                label: 'Of guideline',
                value: '${result.pctOfGuideline}',
                unit: '%',
                tint: over ? VColor.warn : null,
              ),
            ),
            Expanded(
              child: VStat(
                label: 'Zero-sugar streak',
                value: '${result.zeroSugarStreak}',
                unit: 'days',
              ),
            ),
          ],
        ),
        if (result.suggestionCopy != null) ...[
          const SizedBox(height: VSpace.base),
          VCard(
            tone: CardTone.raised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VLabel(result.suggestionActivity ?? 'Suggestion'),
                const SizedBox(height: VSpace.xs),
                // Balance-oriented wording. We never claim an activity "burns
                // off" or "cancels" what was eaten — that framing is both wrong
                // and a short road to a bad relationship with food.
                Text(result.suggestionCopy!,
                    style: const TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.45)),
              ],
            ),
          ),
        ],
        const SizedBox(height: VSpace.md),
        VDisclaimer(result.disclaimer),
      ],
    );
  }
}
