import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'diet_chart.dart';

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

  Future<void> _logSugar() async {
    final grams = double.tryParse(_sugarController.text.trim());
    if (grams == null || grams < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the grams of added sugar, for example 12')),
      );
      return;
    }
    setState(() => _loggingSugar = true);
    try {
      final result = await context.read<VyraApi>().logSugar(grams);
      if (mounted) {
        setState(() {
          _sugar = result;
          _sugarController.clear();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Food & Nutrition', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: VSpace.md),

          // ── My AI Diet Chart Banner (Top Option) ─────────────────────────
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DietChartScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(VSpace.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    VColor.accent.withValues(alpha: 0.22),
                    VColor.accentGreen.withValues(alpha: 0.15),
                    VColor.surfaceRaised,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(VRadius.lg),
                border: Border.all(color: VColor.accent.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: VColor.accent.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: VColor.accent.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_outlined, color: VColor.accent, size: 26),
                  ),
                  const SizedBox(width: VSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'My Diet Chart',
                              style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(width: 6),
                            VPill('AI Clinical', tone: CardTone.accent),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Symptom-based recommendations: What to eat, what NOT to eat, & full day meal plan.',
                          style: TextStyle(color: VColor.textMid, fontSize: 12.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: VColor.accent, size: 18),
                ],
              ),
            ),
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
          const VSectionHeader('Zero Sugar'),
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log the added sugar you have had today. Not the sugar in fruit or milk — '
                  'just what was added: in tea, sweets, cold drinks, biscuits.',
                  style: TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: VSpace.base),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sugarController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: VColor.text, fontSize: 15),
                        decoration: const InputDecoration(hintText: 'grams, e.g. 12'),
                      ),
                    ),
                    const SizedBox(width: VSpace.sm),
                    FilledButton(
                      onPressed: _loggingSugar ? null : _logSugar,
                      child: const Text('Log'),
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
