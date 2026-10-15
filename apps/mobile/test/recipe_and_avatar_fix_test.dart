import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:vyra/services/ai_recipe_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiRecipeService Culinary Intelligence & Common Sense Tests', () {
    test('Egg recipes NEVER tell user to chop raw eggs', () async {
      final recipe = await AiRecipeService.instance.generateRecipe(
        ingredients: ['Egg', 'Onion', 'Tomato'],
      );

      expect(recipe.title.toLowerCase().contains('bhurji') || recipe.title.toLowerCase().contains('omelette'), isTrue);
      expect(recipe.containsEgg, isTrue);
      expect(recipe.containsMeat, isFalse);
      expect(recipe.nutrition['proteinG'], greaterThanOrEqualTo(12.0));

      for (final step in recipe.steps) {
        final s = step.toLowerCase();
        expect(s.contains('chop egg') || s.contains('wash and chop egg'), isFalse,
            reason: 'Recipe must never instruct user to chop raw eggs! Step was: $step');
      }

      // Verify authentic culinary actions
      final allSteps = recipe.steps.join(' ').toLowerCase();
      expect(allSteps.contains('crack') || allSteps.contains('whisk'), isTrue);
    });

    test('Egg solo ingredient generates fluffy omelette', () async {
      final recipe = await AiRecipeService.instance.generateRecipe(
        ingredients: ['Egg'],
      );

      expect(recipe.containsEgg, isTrue);
      expect(recipe.containsMeat, isFalse);
      expect(recipe.nutrition['proteinG'], greaterThanOrEqualTo(12.0));
      final allSteps = recipe.steps.join(' ').toLowerCase();
      expect(allSteps.contains('crack') && allSteps.contains('whisk'), isTrue);
    });

    test('Chicken ingredient produces authentic high-protein stir-fry', () async {
      final recipe = await AiRecipeService.instance.generateRecipe(
        ingredients: ['Chicken', 'Capsicum', 'Onion'],
      );

      expect(recipe.title.toLowerCase().contains('chicken'), isTrue);
      expect(recipe.containsMeat, isTrue);
      expect(recipe.nutrition['proteinG'], greaterThanOrEqualTo(25.0));

      final allSteps = recipe.steps.join(' ').toLowerCase();
      expect(allSteps.contains('marinate') || allSteps.contains('sear'), isTrue);
    });

    test('Paneer ingredient generates healthy paneer bhurji', () async {
      final recipe = await AiRecipeService.instance.generateRecipe(
        ingredients: ['Paneer', 'Tomato', 'Shimla Mirch'],
      );

      expect(recipe.title.toLowerCase().contains('paneer'), isTrue);
      expect(recipe.containsEgg, isFalse);
      expect(recipe.containsMeat, isFalse);
      expect(recipe.nutrition['proteinG'], greaterThanOrEqualTo(15.0));

      final allSteps = recipe.steps.join(' ').toLowerCase();
      expect(allSteps.contains('crumble'), isTrue);
    });

    test('Oats and milk produce nutrient-dense porridge bowl', () async {
      final recipe = await AiRecipeService.instance.generateRecipe(
        ingredients: ['Oats', 'Milk', 'Banana'],
      );

      expect(recipe.title.toLowerCase().contains('oats') || recipe.title.toLowerCase().contains('porridge'), isTrue);
      expect(recipe.containsEgg, isFalse);
      expect(recipe.containsMeat, isFalse);
      expect(recipe.nutrition['fiberG'], greaterThanOrEqualTo(4.0));
    });

    test('Dal produces homestyle tadka dal', () async {
      final recipe = await AiRecipeService.instance.generateRecipe(
        ingredients: ['Moong Dal', 'Tomato', 'Cumin'],
      );

      expect(recipe.title.toLowerCase().contains('dal'), isTrue);
      expect(recipe.containsEgg, isFalse);
      expect(recipe.containsMeat, isFalse);
      final allSteps = recipe.steps.join(' ').toLowerCase();
      expect(allSteps.contains('rinse') && allSteps.contains('tadka'), isTrue);
    });

    test('Vegetables produce authentic sabzi without bizarre instructions', () async {
      final recipe = await AiRecipeService.instance.generateRecipe(
        ingredients: ['Bhindi', 'Onion'],
      );

      expect(recipe.title.toLowerCase().contains('bhindi'), isTrue);
      expect(recipe.containsEgg, isFalse);
      expect(recipe.containsMeat, isFalse);
      final allSteps = recipe.steps.join(' ').toLowerCase();
      expect(allSteps.contains('wash') && allSteps.contains('sauté'), isTrue);
    });
  });

  group('Avatar Engine 3D Model Parity Tests', () {
    test('female_coach.glb is optimized and under 5 MB (prevents mobile WebGL crashes)', () async {
      final ByteData data = await rootBundle.load('assets/models/female_coach.glb');
      final sizeMb = data.lengthInBytes / (1024 * 1024);
      expect(sizeMb, lessThan(5.0), reason: 'female_coach.glb must be optimized to < 5MB to avoid Android WebView VRAM crashes');
      expect(sizeMb, greaterThan(1.0), reason: 'female_coach.glb must have complete skeletal geometry and animations');

      final magic = String.fromCharCodes(data.buffer.asUint8List(0, 4));
      expect(magic, equals('glTF'), reason: 'Model must be valid binary glTF');
    });

    test('male_coach.glb is valid and lightweight', () async {
      final ByteData data = await rootBundle.load('assets/models/male_coach.glb');
      final sizeMb = data.lengthInBytes / (1024 * 1024);
      expect(sizeMb, lessThan(3.0));
      final magic = String.fromCharCodes(data.buffer.asUint8List(0, 4));
      expect(magic, equals('glTF'));
    });
  });
}
