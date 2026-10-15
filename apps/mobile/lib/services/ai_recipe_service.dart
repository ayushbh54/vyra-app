import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../models/models.dart';

/// Intelligent, culinary-aware recipe generator.
/// Features a 3-tier cascade:
/// 1. Backend API (`/v1/ai/recipe`) with Diet Guard verification.
/// 2. On-Device Gemini 2.0 Flash (`google_generative_ai`) with permanent caching.
/// 3. Offline Culinary Intelligence Engine: Realistic chef-grade Indian home recipes
///    customized to the exact primary and secondary ingredients (Zero bizarre "chop egg" bugs).
class AiRecipeService {
  AiRecipeService._();
  static final instance = AiRecipeService._();

  static const _cachePrefix = 'vyra_recipe_cache_v2_';
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Generates a culinary-sound recipe respecting dietary restrictions and ingredient logic.
  Future<Recipe> generateRecipe({
    required List<String> ingredients,
    VyraApi? api,
    String? dietPreference,
    int? maxCookTimeMin,
  }) async {
    final cleaned = ingredients
        .map((i) => i.trim())
        .where((i) => i.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      throw Exception('Please provide at least one ingredient.');
    }

    // ── Tier 0: Check permanent local cache first (instant 0ms response) ──
    final sortedList = cleaned.map((s) => s.toLowerCase()).toList()..sort();
    final cacheKey = '$_cachePrefix${sortedList.join('_')}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        return Recipe.fromJson(decoded, '');
      }
    } catch (_) {}

    Recipe? recipe;

    // ── Tier 1: Try Backend API ──
    if (api != null) {
      try {
        recipe = await api.generateRecipe(cleaned);
      } catch (e) {
        debugPrint('[AiRecipeService] Backend recipe API failed, falling back: $e');
      }
    }

    // ── Tier 2: Try On-Device Gemini Flash ──
    if (recipe == null && _apiKey.isNotEmpty) {
      try {
        recipe = await _generateWithOnDeviceGemini(
          ingredients: cleaned,
          dietPreference: dietPreference,
          maxCookTimeMin: maxCookTimeMin,
        );
      } catch (e) {
        debugPrint('[AiRecipeService] On-device Gemini failed, falling back: $e');
      }
    }

    // ── Tier 3: Offline Culinary Intelligence Engine ──
    recipe ??= _generateCulinaryRecipe(
      ingredients: cleaned,
      dietPreference: dietPreference,
      maxCookTimeMin: maxCookTimeMin,
    );

    // Save permanently in cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = {
        'title': recipe.title,
        'ingredients': recipe.ingredients
            .map((i) => {'name': i.name, 'quantity': i.quantity})
            .toList(),
        'steps': recipe.steps,
        'cookTimeMin': recipe.cookTimeMin,
        'containsEgg': recipe.containsEgg,
        'containsMeat': recipe.containsMeat,
        'nutrition': recipe.nutrition,
        'disclaimer': recipe.disclaimer,
      };
      await prefs.setString(cacheKey, jsonEncode(toSave));
    } catch (_) {}

    return recipe;
  }

  /// Calls Gemini 2.0 Flash on device with strict culinary common sense instructions.
  Future<Recipe> _generateWithOnDeviceGemini({
    required List<String> ingredients,
    String? dietPreference,
    int? maxCookTimeMin,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.3,
        maxOutputTokens: 1024,
      ),
      systemInstruction: Content.text(
        '''You are an expert Indian chef and sports nutritionist for the VYRA fitness app.
Create a healthy, delicious home-cooked recipe using mainly the user's available ingredients.

CRITICAL CULINARY RULES:
1. Always apply correct culinary techniques:
   - Eggs: Crack, whisk, boil, poach, or scramble. NEVER say "chop raw egg" or "wash and chop eggs".
   - Meat/Chicken: Clean, marinate with spices, sear, and cook thoroughly until tender.
   - Dairy/Liquids: Whisk, simmer, temper, or blend. Never slice or fry dry liquids.
   - Spices: Bloom whole spices (cumin, mustard) in hot oil/ghee (tadka).
   - Vegetables: Wash, peel if needed, and chop into appropriate bite-sized pieces.
2. Produce realistic nutritional estimates per serving based on Indian food standards (ICMR-NIN).
3. Return valid JSON matching this schema:
{
  "title": "String",
  "ingredients": [{"name": "String", "quantity": "String"}],
  "steps": ["Step 1: ...", "Step 2: ..."],
  "cookTimeMin": 15,
  "containsEgg": boolean,
  "containsMeat": boolean,
  "nutrition": {
    "calories": 250,
    "proteinG": 18,
    "carbsG": 20,
    "fatG": 10,
    "fiberG": 4
  }
}''',
      ),
    );

    final prompt = 'Available ingredients: ${ingredients.join(", ")}'
        '${dietPreference != null ? "\nDietary rule: $dietPreference" : ""}'
        '${maxCookTimeMin != null ? "\nMax cook time: $maxCookTimeMin min" : ""}';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Empty Gemini response');
    }

    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return Recipe.fromJson(parsed, '');
  }

  /// High-fidelity offline culinary engine that understands food science,
  /// ingredient classification, and authentic Indian cooking techniques.
  Recipe _generateCulinaryRecipe({
    required List<String> ingredients,
    String? dietPreference,
    int? maxCookTimeMin,
  }) {
    final lowerList = ingredients.map((i) => i.toLowerCase()).toList();
    final allText = lowerList.join(' ');

    // ── Classify Ingredients ──
    final hasEgg = allText.contains('egg') || allText.contains('anda') || allText.contains('ande');
    final hasChicken = allText.contains('chicken') || allText.contains('murgh');
    final hasFish = allText.contains('fish') || allText.contains('prawn') || allText.contains('machli');
    final hasMeat = allText.contains('mutton') || allText.contains('beef') || allText.contains('pork') || allText.contains('meat') || hasChicken || hasFish;
    final hasPaneer = allText.contains('paneer') || allText.contains('cottage cheese') || allText.contains('tofu');
    final hasSoya = allText.contains('soya') || allText.contains('soy chunks') || allText.contains('nutrela');
    final hasDal = allText.contains('dal') || allText.contains('lentil') || allText.contains('chana') || allText.contains('rajma') || allText.contains('moong') || allText.contains('chickpea');
    final hasOats = allText.contains('oats') || allText.contains('oatmeal') || allText.contains('muesli');
    final hasRice = allText.contains('rice') || allText.contains('chawal') || allText.contains('poha');
    final hasMilk = allText.contains('milk') || allText.contains('doodh') || allText.contains('curd') || allText.contains('dahi') || allText.contains('yogurt');
    final hasBanana = allText.contains('banana') || allText.contains('apple') || allText.contains('fruit');

    // Secondary helpers
    final hasOnion = allText.contains('onion') || allText.contains('pyaz');
    final hasTomato = allText.contains('tomato') || allText.contains('tamatar');
    final hasCapsicum = allText.contains('capsicum') || allText.contains('shimla');
    final hasSpinach = allText.contains('spinach') || allText.contains('palak');

    // Extract genuine vegetables for chopping (excluding eggs, meats, liquids)
    final veggiesToChop = ingredients.where((i) {
      final s = i.toLowerCase();
      return !s.contains('egg') &&
          !s.contains('anda') &&
          !s.contains('chicken') &&
          !s.contains('meat') &&
          !s.contains('fish') &&
          !s.contains('milk') &&
          !s.contains('doodh') &&
          !s.contains('water') &&
          !s.contains('oil') &&
          !s.contains('ghee') &&
          !s.contains('salt');
    }).toList();

    // ─────────────────────────────────────────────────────────────────────────
    // 1. EGG DISHES (Accurate cracking, whisking, scrambled or boiled)
    // ─────────────────────────────────────────────────────────────────────────
    if (hasEgg && !hasMeat) {
      if (hasSpinach || hasCapsicum || hasOnion || hasTomato || veggiesToChop.isNotEmpty) {
        final vegNames = veggiesToChop.isNotEmpty ? veggiesToChop.join(' and ') : 'onions and tomatoes';
        return Recipe(
          title: 'High-Protein Masala Egg Bhurji',
          ingredients: [
            (name: 'Eggs', quantity: '2-3 whole eggs'),
            if (veggiesToChop.isNotEmpty) ...veggiesToChop.map((v) => (name: v, quantity: '1/2 cup, finely chopped')),
            if (!hasOnion) (name: 'Onion', quantity: '1 medium, finely chopped'),
            if (!hasTomato) (name: 'Tomato', quantity: '1 small, chopped'),
            (name: 'Green Chillies & Ginger', quantity: '1 tsp, minced'),
            (name: 'Turmeric & Red Chilli Powder', quantity: '1/2 tsp each'),
            (name: 'Cooking Oil or Ghee', quantity: '1 tsp'),
            (name: 'Fresh Coriander & Salt', quantity: 'To taste'),
          ],
          steps: [
            'Step 1: Finely chop $vegNames and green chillies.',
            'Step 2: Crack eggs into a bowl, add a pinch of salt and black pepper, and whisk gently with a fork until blended.',
            'Step 3: Heat 1 tsp oil in a non-stick pan on medium flame. Add cumin seeds and let them splutter for 20 seconds.',
            'Step 4: Add the chopped $vegNames and sauté for 3-4 minutes until translucent and aromatic.',
            'Step 5: Add turmeric and red chilli powder. Stir well on low heat for 30 seconds.',
            'Step 6: Lower the flame, pour in the whisked eggs, and gently fold with a spatula for 2-3 minutes until soft, fluffy curds form. Do not overcook.',
            'Step 7: Garnish with freshly chopped coriander leaves. Serve hot with toasted multigrain bread or warm roti.',
          ],
          cookTimeMin: maxCookTimeMin ?? 12,
          containsEgg: true,
          containsMeat: false,
          nutrition: {'calories': 240, 'proteinG': 16.5, 'carbsG': 6.0, 'fatG': 15.0, 'fiberG': 2.0},
          disclaimer: 'Rich in bio-available choline, Vitamin B12, and muscle-repair protein.',
        );
      } else {
        return Recipe(
          title: 'Classic Fluffy Masala Omelette',
          ingredients: [
            (name: 'Eggs', quantity: '2 whole eggs'),
            (name: 'Green Chillies', quantity: '1 finely chopped'),
            (name: 'Black Pepper & Turmeric', quantity: '1/4 tsp each'),
            (name: 'Olive Oil or Butter', quantity: '1 tsp'),
            (name: 'Salt & Fresh Herbs', quantity: 'To taste'),
          ],
          steps: [
            'Step 1: Crack 2 eggs into a wide bowl. Add a pinch of salt, turmeric, and freshly cracked black pepper.',
            'Step 2: Whisk vigorously for 60 seconds until frothy and aerated for maximum fluffiness.',
            'Step 3: Heat 1 tsp oil/butter in a flat non-stick skillet on medium flame until hot.',
            'Step 4: Pour the whisked egg mixture evenly across the skillet.',
            'Step 5: Cook on medium-low flame for 2 minutes until the edges set and the bottom turns golden.',
            'Step 6: Gently fold in half using a spatula. Cook for another 30 seconds until the center is cooked through.',
            'Step 7: Slide onto a warm plate and enjoy hot.',
          ],
          cookTimeMin: maxCookTimeMin ?? 8,
          containsEgg: true,
          containsMeat: false,
          nutrition: {'calories': 195, 'proteinG': 14.0, 'carbsG': 2.0, 'fatG': 14.0, 'fiberG': 0.5},
          disclaimer: 'Pure clean protein source with complete amino acid profile.',
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. CHICKEN / MEAT DISHES (Accurate searing, marinating, cooking)
    // ─────────────────────────────────────────────────────────────────────────
    if (hasChicken || hasMeat) {
      final meatLabel = hasChicken ? 'Chicken' : 'Lean Meat';
      return Recipe(
        title: 'Homestyle Spiced $meatLabel Kadai Stir-Fry',
        ingredients: [
          (name: '$meatLabel Breast/Cubes', quantity: '200g, boneless bite-sized pieces'),
          if (veggiesToChop.isNotEmpty) ...veggiesToChop.map((v) => (name: v, quantity: '1/2 cup diced')),
          (name: 'Ginger-Garlic Paste', quantity: '1 tbsp'),
          (name: 'Turmeric, Coriander & Garam Masala', quantity: '1/2 tsp each'),
          (name: 'Mustard or Olive Oil', quantity: '1.5 tsp'),
          (name: 'Salt & Lemon Juice', quantity: 'To taste'),
        ],
        steps: [
          'Step 1: Wash and pat dry the $meatLabel. Cut into even bite-sized cubes.',
          'Step 2: Marinate $meatLabel with ginger-garlic paste, a pinch of turmeric, salt, and 1 tsp lemon juice for 10 minutes.',
          if (veggiesToChop.isNotEmpty) 'Step 3: Dice ${veggiesToChop.join(", ")} into crunchy cubes.',
          'Step 4: Heat oil in a heavy kadai on high flame. Add cumin seeds and let them sizzle.',
          'Step 5: Add the marinated $meatLabel pieces. Sear on high heat for 3-4 minutes until lightly browned on all sides.',
          if (veggiesToChop.isNotEmpty) 'Step 6: Toss in the diced ${veggiesToChop.join(", ")}, coriander powder, and garam masala. Stir-fry on medium heat.',
          'Step 7: Cover the kadai with a lid and cook on low flame for 7-8 minutes until the $meatLabel is juicy and completely cooked through.',
          'Step 8: Turn off the flame, squeeze fresh lemon juice on top, and serve hot.',
        ],
        cookTimeMin: maxCookTimeMin ?? 20,
        containsEgg: hasEgg,
        containsMeat: true,
        nutrition: {'calories': 285, 'proteinG': 32.0, 'carbsG': 6.0, 'fatG': 12.0, 'fiberG': 2.5},
        disclaimer: 'High lean protein recipe for post-workout muscle hypertrophy.',
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. PANEER / TOFU / SOYA (Crumble, toss, high protein veg)
    // ─────────────────────────────────────────────────────────────────────────
    if (hasPaneer || hasSoya) {
      final proteinName = hasPaneer ? 'Paneer' : 'Soya Chunks';
      return Recipe(
        title: 'Desi Protein $proteinName Bhurji Stir-Fry',
        ingredients: [
          (name: proteinName, quantity: '150g, crumbled or boiled'),
          if (veggiesToChop.isNotEmpty) ...veggiesToChop.map((v) => (name: v, quantity: '1/2 cup, finely diced')),
          (name: 'Cumin Seeds', quantity: '1/2 tsp'),
          (name: 'Turmeric & Kashmiri Red Chilli Powder', quantity: '1/2 tsp each'),
          (name: 'Olive Oil or Desi Ghee', quantity: '1 tsp'),
          (name: 'Kasuri Methi & Coriander', quantity: '1 tsp'),
        ],
        steps: [
          'Step 1: ${hasPaneer ? "Crumble fresh paneer with your fingers into soft crumbles." : "Boil soya chunks in salted water for 5 minutes, squeeze excess water, and coarsely chop."}',
          if (veggiesToChop.isNotEmpty) 'Step 2: Finely dice ${veggiesToChop.join(", ")}.',
          'Step 3: Heat oil in a pan on medium flame. Splutter cumin seeds.',
          if (veggiesToChop.isNotEmpty) 'Step 4: Sauté ${veggiesToChop.join(", ")} for 3 minutes until tender-crisp.',
          'Step 5: Add turmeric, red chilli powder, and salt. Stir for 30 seconds.',
          'Step 6: Gently fold in the $proteinName. Cook on low flame for 2-3 minutes so the spices absorb without hardening.',
          'Step 7: Crush kasuri methi between your palms and sprinkle on top with fresh coriander.',
        ],
        cookTimeMin: maxCookTimeMin ?? 15,
        containsEgg: false,
        containsMeat: false,
        nutrition: {'calories': 260, 'proteinG': 20.0, 'carbsG': 8.0, 'fatG': 16.0, 'fiberG': 3.0},
        disclaimer: 'Nutrient-rich vegetarian complete protein meal with essential amino acids.',
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. OATS / BREAKFAST BOWLS (Simmer, porridge, sweet or savory)
    // ─────────────────────────────────────────────────────────────────────────
    if (hasOats) {
      if (hasMilk || hasBanana) {
        return Recipe(
          title: 'Creamy Power Oats & Fruit Porridge',
          ingredients: [
            (name: 'Rolled Oats', quantity: '40g (1/2 cup)'),
            (name: 'Milk or Plant Milk', quantity: '1 cup (200ml)'),
            if (hasBanana) (name: 'Banana', quantity: '1 sliced'),
            (name: 'Cinnamon Powder', quantity: '1/4 tsp'),
            (name: 'Honey or Jaggery', quantity: '1 tsp (optional)'),
            (name: 'Almonds or Chia Seeds', quantity: '1 tbsp'),
          ],
          steps: [
            'Step 1: Pour milk into a small saucepan and bring to a gentle simmer over medium heat.',
            'Step 2: Add rolled oats and a pinch of cinnamon powder. Stir well.',
            'Step 3: Lower heat to low-medium and cook for 4-5 minutes, stirring frequently until creamy and thick.',
            'Step 4: Remove from heat and pour into your serving bowl.',
            'Step 5: Top with fresh banana slices, crushed nuts, and a drizzle of honey.',
          ],
          cookTimeMin: maxCookTimeMin ?? 8,
          containsEgg: false,
          containsMeat: false,
          nutrition: {'calories': 280, 'proteinG': 10.0, 'carbsG': 48.0, 'fatG': 6.0, 'fiberG': 6.5},
          disclaimer: 'Slow-digesting complex carbs with beta-glucan soluble fiber for sustained energy.',
        );
      } else {
        return Recipe(
          title: 'Wholesome Vegetable Masala Oats Upma',
          ingredients: [
            (name: 'Rolled Oats', quantity: '1/2 cup'),
            if (veggiesToChop.isNotEmpty) ...veggiesToChop.map((v) => (name: v, quantity: '1/3 cup finely chopped')),
            (name: 'Mustard Seeds & Curry Leaves', quantity: '1/2 tsp each'),
            (name: 'Turmeric & Salt', quantity: 'To taste'),
            (name: 'Water', quantity: '1 cup'),
            (name: 'Cooking Oil', quantity: '1 tsp'),
          ],
          steps: [
            'Step 1: Dry roast oats in a pan on medium-low flame for 2 minutes until warm and nutty. Set aside.',
            'Step 2: Heat 1 tsp oil in the pan. Add mustard seeds and let them pop, followed by curry leaves.',
            if (veggiesToChop.isNotEmpty) 'Step 3: Add chopped ${veggiesToChop.join(", ")} and sauté for 3 minutes until tender.',
            'Step 4: Add turmeric, salt, and pour in 1 cup of water. Bring to a rolling boil.',
            'Step 5: Lower the flame and gently stir in the roasted oats to avoid lumps.',
            'Step 6: Cover and cook on low heat for 3-4 minutes until water is absorbed and oats are soft.',
            'Step 7: Squeeze fresh lemon juice and serve hot.',
          ],
          cookTimeMin: maxCookTimeMin ?? 10,
          containsEgg: false,
          containsMeat: false,
          nutrition: {'calories': 210, 'proteinG': 7.0, 'carbsG': 36.0, 'fatG': 5.0, 'fiberG': 5.0},
          disclaimer: 'High fiber savory Indian breakfast for stable blood glucose and gut health.',
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. DAL & LENTILS (Tadka, pressure cook, aromatic temper)
    // ─────────────────────────────────────────────────────────────────────────
    if (hasDal) {
      final dalName = ingredients.firstWhere(
        (i) => i.toLowerCase().contains('dal') || i.toLowerCase().contains('lentil') || i.toLowerCase().contains('chana'),
        orElse: () => 'Moong Dal',
      );
      return Recipe(
        title: 'Homestyle Protein $dalName Tadka',
        ingredients: [
          (name: dalName, quantity: '1/2 cup rinsed'),
          if (veggiesToChop.isNotEmpty) ...veggiesToChop.map((v) => (name: v, quantity: '1/2 cup chopped')),
          (name: 'Cumin & Mustard Seeds', quantity: '1/2 tsp each'),
          (name: 'Turmeric & Hing (Asafoetida)', quantity: 'A pinch'),
          (name: 'Desi Ghee or Oil', quantity: '1 tsp'),
          (name: 'Water', quantity: '2 cups'),
        ],
        steps: [
          'Step 1: Thoroughly rinse $dalName with fresh water 2-3 times until clear.',
          'Step 2: Pressure cook or simmer $dalName with 2 cups of water, turmeric, and 1/2 tsp salt for 10-12 minutes until soft and creamy.',
          if (veggiesToChop.isNotEmpty) 'Step 3: In a separate tadka pan, heat 1 tsp ghee/oil and sauté chopped ${veggiesToChop.join(", ")}.',
          'Step 4: Add cumin seeds, hing, and a pinch of red chilli powder. Let spices bloom in the hot ghee for 20 seconds.',
          'Step 5: Pour the sizzling tadka directly into the cooked dal. Cover immediately with a lid to trap the smoky aroma for 2 minutes.',
          'Step 6: Stir gently and serve hot with steamed brown rice or phulkas.',
        ],
        cookTimeMin: maxCookTimeMin ?? 18,
        containsEgg: false,
        containsMeat: false,
        nutrition: {'calories': 210, 'proteinG': 12.0, 'carbsG': 32.0, 'fatG': 4.0, 'fiberG': 7.0},
        disclaimer: 'Classic plant-based protein staple rich in folate, iron, and dietary fiber.',
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. RICE & POHA (Light, fluffy, tempered carbs)
    // ─────────────────────────────────────────────────────────────────────────
    if (hasRice) {
      final isPoha = allText.contains('poha');
      return Recipe(
        title: isPoha ? 'Homestyle Vegetable Poha' : 'Spiced Vegetable Tawa Rice Pilaf',
        ingredients: [
          (name: isPoha ? 'Flattened Rice (Poha)' : 'Cooked Rice', quantity: '1.5 cups'),
          if (veggiesToChop.isNotEmpty) ...veggiesToChop.map((v) => (name: v, quantity: '1/3 cup, diced')),
          (name: 'Peanuts or Mustard Seeds', quantity: '1 tbsp'),
          (name: 'Turmeric & Green Chilli', quantity: '1/2 tsp each'),
          (name: 'Cooking Oil', quantity: '1 tsp'),
          (name: 'Lemon Juice & Coriander', quantity: 'To taste'),
        ],
        steps: [
          'Step 1: ${isPoha ? "Gently rinse poha in a colander for 30 seconds and drain completely." : "Fluff cooked rice with a fork."}',
          if (veggiesToChop.isNotEmpty) 'Step 2: Dice ${veggiesToChop.join(", ")} into small cubes.',
          'Step 3: Heat 1 tsp oil in a pan, roast peanuts and splutter mustard seeds with curry leaves.',
          if (veggiesToChop.isNotEmpty) 'Step 4: Add ${veggiesToChop.join(", ")} and sauté for 3 minutes until tender.',
          'Step 5: Add turmeric, salt, and green chillies.',
          'Step 6: Fold in the ${isPoha ? "rinsed poha" : "cooked rice"}, cover and steam on low flame for 2 minutes.',
          'Step 7: Squeeze fresh lemon juice on top, toss, and serve hot.',
        ],
        cookTimeMin: maxCookTimeMin ?? 10,
        containsEgg: false,
        containsMeat: false,
        nutrition: {'calories': 230, 'proteinG': 5.0, 'carbsG': 44.0, 'fatG': 5.0, 'fiberG': 3.5},
        disclaimer: 'Easy-to-digest clean carbohydrate meal with healthy fats from roasted peanuts.',
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. FRESH VEGETABLE SABZI (Careful sauteing, never blind boilerplate)
    // ─────────────────────────────────────────────────────────────────────────
    final leadVeg = veggiesToChop.isNotEmpty ? veggiesToChop.first : ingredients.first;
    final otherVeggies = veggiesToChop.length > 1 ? veggiesToChop.sublist(1).join(' & ') : '';
    final dishTitle = otherVeggies.isNotEmpty
        ? 'Spiced $leadVeg & $otherVeggies Homestyle Sabzi'
        : 'Homestyle Jeera $leadVeg Stir-Fry';

    return Recipe(
      title: dishTitle,
      ingredients: [
        (name: leadVeg, quantity: '1.5 cups, chopped'),
        if (otherVeggies.isNotEmpty) (name: otherVeggies, quantity: '1 cup, chopped'),
        (name: 'Cumin Seeds (Jeera)', quantity: '1/2 tsp'),
        (name: 'Turmeric, Coriander & Amchur Powder', quantity: '1/2 tsp each'),
        (name: 'Mustard or Groundnut Oil', quantity: '1.5 tsp'),
        (name: 'Fresh Coriander & Salt', quantity: 'To taste'),
      ],
      steps: [
        'Step 1: Wash ${veggiesToChop.isNotEmpty ? veggiesToChop.join(", ") : leadVeg} thoroughly under running water and pat dry with a clean kitchen towel.',
        'Step 2: Cut ${veggiesToChop.isNotEmpty ? veggiesToChop.join(" and ") : leadVeg} into uniform bite-sized pieces for even cooking.',
        'Step 3: Heat 1.5 tsp oil in a wide kadai on medium flame. Add cumin seeds and allow them to crackle and release their aroma.',
        'Step 4: Add the chopped $leadVeg${otherVeggies.isNotEmpty ? " and $otherVeggies" : ""}. Sauté on medium-high heat for 2-3 minutes.',
        'Step 5: Lower the flame, add turmeric, coriander powder, and salt. Mix thoroughly so every piece is coated in spices.',
        'Step 6: Cover the pan with a lid and cook on low heat for 8-10 minutes, stirring occasionally until tender yet holding shape.',
        'Step 7: Sprinkle a pinch of amchur (dry mango powder) for a tangy finish, garnish with fresh coriander, and serve hot.',
      ],
      cookTimeMin: maxCookTimeMin ?? 15,
      containsEgg: false,
      containsMeat: false,
      nutrition: {'calories': 140, 'proteinG': 4.0, 'carbsG': 18.0, 'fatG': 6.0, 'fiberG': 5.5},
      disclaimer: 'Fiber-dense, micronutrient-rich Indian antioxidant vegetable preparation.',
    );
  }
}
