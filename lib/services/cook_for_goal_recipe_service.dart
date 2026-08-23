import 'dart:math' as math;

import 'package:future_project/models/cook_for_goal_recipe.dart';
import 'package:future_project/models/nutrition_food_log.dart';
import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/models/performance_fuel.dart';

abstract interface class CookForGoalRecipeProvider {
  Future<List<CookForGoalRecipe>> loadRecipes();
}

class LocalCookForGoalRecipeProvider implements CookForGoalRecipeProvider {
  const LocalCookForGoalRecipeProvider();

  @override
  Future<List<CookForGoalRecipe>> loadRecipes() async => _recipes;

  static const _recipes = <CookForGoalRecipe>[
    CookForGoalRecipe(
      id: 'chicken_quinoa_bowl',
      name: 'Lemon Chicken Quinoa Bowl',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 610,
        proteinG: 52,
        carbsG: 58,
        fatG: 18,
      ),
      servings: 1,
      preparationMinutes: 10,
      cookingMinutes: 20,
      ingredients: [
        RecipeIngredient(name: 'chicken breast', quantity: '180 g'),
        RecipeIngredient(name: 'cooked quinoa', quantity: '170 g'),
        RecipeIngredient(name: 'broccoli florets', quantity: '100 g'),
        RecipeIngredient(name: 'olive oil', quantity: '2 tsp'),
        RecipeIngredient(name: 'lemon juice', quantity: '1 tbsp'),
        RecipeIngredient(name: 'garlic powder', quantity: '1/2 tsp'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text:
              'Season the chicken with garlic powder and half the lemon juice.',
        ),
        RecipeInstruction(
          step: 2,
          text:
              'Heat 1 teaspoon oil in a skillet and cook the chicken for 6–7 minutes per side, until cooked through.',
        ),
        RecipeInstruction(
          step: 3,
          text:
              'Steam the broccoli until tender-crisp and warm the cooked quinoa.',
        ),
        RecipeInstruction(
          step: 4,
          text:
              'Slice the chicken and serve over quinoa with broccoli, remaining oil, and lemon juice.',
        ),
      ],
      supportedDiets: {'omnivore'},
      allergens: {},
      tags: {'high_protein', 'strength_recovery'},
    ),
    CookForGoalRecipe(
      id: 'salmon_potato_plate',
      name: 'Herbed Salmon and Potato Plate',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 575,
        proteinG: 42,
        carbsG: 52,
        fatG: 22,
      ),
      servings: 1,
      preparationMinutes: 10,
      cookingMinutes: 25,
      ingredients: [
        RecipeIngredient(name: 'salmon fillet', quantity: '160 g'),
        RecipeIngredient(name: 'baby potatoes', quantity: '250 g'),
        RecipeIngredient(name: 'green beans', quantity: '120 g'),
        RecipeIngredient(name: 'olive oil', quantity: '2 tsp'),
        RecipeIngredient(name: 'dried dill', quantity: '1/2 tsp'),
        RecipeIngredient(name: 'lemon', quantity: '1/2'),
      ],
      instructions: [
        RecipeInstruction(step: 1, text: 'Heat the oven to 220°C.'),
        RecipeInstruction(
          step: 2,
          text:
              'Halve the potatoes, toss with 1 teaspoon oil, and roast for 15 minutes.',
        ),
        RecipeInstruction(
          step: 3,
          text:
              'Add salmon and green beans to the tray. Brush with remaining oil and season with dill.',
        ),
        RecipeInstruction(
          step: 4,
          text:
              'Roast for 10–12 minutes more, until the salmon flakes easily. Finish with lemon.',
        ),
      ],
      supportedDiets: {'omnivore', 'pescatarian'},
      allergens: {'seafood'},
      tags: {'high_protein', 'recovery_carbs'},
    ),
    CookForGoalRecipe(
      id: 'turkey_tomato_pasta',
      name: 'Turkey Tomato Protein Pasta',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 640,
        proteinG: 48,
        carbsG: 76,
        fatG: 16,
      ),
      servings: 1,
      preparationMinutes: 8,
      cookingMinutes: 22,
      ingredients: [
        RecipeIngredient(name: 'lean ground turkey', quantity: '170 g'),
        RecipeIngredient(name: 'whole-wheat pasta', quantity: '85 g dry'),
        RecipeIngredient(name: 'crushed tomatoes', quantity: '180 ml'),
        RecipeIngredient(name: 'baby spinach', quantity: '60 g'),
        RecipeIngredient(name: 'olive oil', quantity: '1 tsp'),
        RecipeIngredient(name: 'Italian seasoning', quantity: '1 tsp'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text:
              'Cook the pasta according to the package directions; reserve 60 ml cooking water.',
        ),
        RecipeInstruction(
          step: 2,
          text:
              'Heat the oil and cook the turkey, breaking it apart, until no pink remains.',
        ),
        RecipeInstruction(
          step: 3,
          text: 'Add tomatoes and seasoning and simmer for 8 minutes.',
        ),
        RecipeInstruction(
          step: 4,
          text:
              'Fold in spinach and pasta, adding reserved water as needed to coat.',
        ),
      ],
      supportedDiets: {'omnivore'},
      allergens: {'gluten'},
      tags: {'high_protein', 'recovery_carbs'},
    ),
    CookForGoalRecipe(
      id: 'tofu_rice_bowl',
      name: 'Crispy Tofu Rice Bowl',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 560,
        proteinG: 30,
        carbsG: 72,
        fatG: 19,
      ),
      servings: 1,
      preparationMinutes: 12,
      cookingMinutes: 20,
      ingredients: [
        RecipeIngredient(name: 'extra-firm tofu', quantity: '220 g'),
        RecipeIngredient(name: 'cooked brown rice', quantity: '180 g'),
        RecipeIngredient(name: 'red bell pepper', quantity: '100 g'),
        RecipeIngredient(name: 'shelled edamame', quantity: '70 g'),
        RecipeIngredient(name: 'reduced-sodium soy sauce', quantity: '1 tbsp'),
        RecipeIngredient(name: 'sesame oil', quantity: '1 tsp'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text:
              'Pat the tofu dry, cut into cubes, and toss with half the soy sauce.',
        ),
        RecipeInstruction(
          step: 2,
          text:
              'Heat sesame oil in a skillet and cook tofu for 8–10 minutes, turning until crisp.',
        ),
        RecipeInstruction(
          step: 3,
          text: 'Add pepper and edamame and cook for 4 minutes.',
        ),
        RecipeInstruction(
          step: 4,
          text:
              'Serve over warm rice and drizzle with the remaining soy sauce.',
        ),
      ],
      supportedDiets: {'omnivore', 'vegetarian', 'vegan', 'pescatarian'},
      allergens: {'soy'},
      tags: {'plant_based', 'recovery_carbs'},
    ),
    CookForGoalRecipe(
      id: 'lentil_chickpea_curry',
      name: 'Lentil Chickpea Spinach Curry',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 520,
        proteinG: 27,
        carbsG: 78,
        fatG: 13,
      ),
      servings: 1,
      preparationMinutes: 10,
      cookingMinutes: 25,
      ingredients: [
        RecipeIngredient(name: 'cooked lentils', quantity: '170 g'),
        RecipeIngredient(name: 'cooked chickpeas', quantity: '120 g'),
        RecipeIngredient(name: 'crushed tomatoes', quantity: '180 ml'),
        RecipeIngredient(name: 'baby spinach', quantity: '70 g'),
        RecipeIngredient(name: 'light coconut milk', quantity: '80 ml'),
        RecipeIngredient(name: 'curry powder', quantity: '2 tsp'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text:
              'Add tomatoes, coconut milk, and curry powder to a saucepan and bring to a gentle simmer.',
        ),
        RecipeInstruction(
          step: 2,
          text: 'Stir in lentils and chickpeas and simmer for 15 minutes.',
        ),
        RecipeInstruction(
          step: 3,
          text: 'Fold in spinach and cook for 2–3 minutes until wilted.',
        ),
        RecipeInstruction(
          step: 4,
          text:
              'Rest for 2 minutes before serving so the curry thickens slightly.',
        ),
      ],
      supportedDiets: {'omnivore', 'vegetarian', 'vegan', 'pescatarian'},
      allergens: {},
      tags: {'plant_based', 'recovery_carbs'},
    ),
    CookForGoalRecipe(
      id: 'greek_yogurt_oats',
      name: 'Greek Yogurt Berry Oat Bowl',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 430,
        proteinG: 32,
        carbsG: 57,
        fatG: 9,
      ),
      servings: 1,
      preparationMinutes: 8,
      cookingMinutes: 0,
      ingredients: [
        RecipeIngredient(name: 'plain Greek yogurt', quantity: '250 g'),
        RecipeIngredient(name: 'rolled oats', quantity: '50 g'),
        RecipeIngredient(name: 'mixed berries', quantity: '120 g'),
        RecipeIngredient(name: 'chia seeds', quantity: '10 g'),
        RecipeIngredient(name: 'honey', quantity: '1 tsp'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text: 'Stir the oats and chia seeds into the Greek yogurt.',
        ),
        RecipeInstruction(
          step: 2,
          text: 'Let the mixture stand for 5 minutes to soften the oats.',
        ),
        RecipeInstruction(
          step: 3,
          text: 'Top with berries and drizzle with honey before serving.',
        ),
      ],
      supportedDiets: {'omnivore', 'vegetarian', 'pescatarian'},
      allergens: {'dairy', 'gluten'},
      tags: {'high_protein', 'lighter_meal'},
    ),
    CookForGoalRecipe(
      id: 'egg_vegetable_rice',
      name: 'Egg and Vegetable Fried Rice',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 505,
        proteinG: 25,
        carbsG: 67,
        fatG: 16,
      ),
      servings: 1,
      preparationMinutes: 10,
      cookingMinutes: 15,
      ingredients: [
        RecipeIngredient(name: 'cooked jasmine rice', quantity: '190 g'),
        RecipeIngredient(name: 'eggs', quantity: '2 large'),
        RecipeIngredient(name: 'frozen peas and carrots', quantity: '130 g'),
        RecipeIngredient(name: 'reduced-sodium soy sauce', quantity: '1 tbsp'),
        RecipeIngredient(name: 'sesame oil', quantity: '1 tsp'),
        RecipeIngredient(name: 'green onion', quantity: '1'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text:
              'Heat half the sesame oil in a skillet and scramble the eggs; transfer to a plate.',
        ),
        RecipeInstruction(
          step: 2,
          text:
              'Add remaining oil and cook the peas and carrots for 4 minutes.',
        ),
        RecipeInstruction(
          step: 3,
          text:
              'Add rice and soy sauce and stir-fry until hot and lightly crisp.',
        ),
        RecipeInstruction(
          step: 4,
          text: 'Fold the eggs back in and finish with sliced green onion.',
        ),
      ],
      supportedDiets: {'omnivore', 'vegetarian', 'pescatarian'},
      allergens: {'eggs', 'soy'},
      tags: {'quick', 'recovery_carbs'},
    ),
    CookForGoalRecipe(
      id: 'white_bean_quinoa_salad',
      name: 'White Bean Quinoa Crunch Salad',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 455,
        proteinG: 23,
        carbsG: 62,
        fatG: 14,
      ),
      servings: 1,
      preparationMinutes: 15,
      cookingMinutes: 0,
      ingredients: [
        RecipeIngredient(name: 'cooked quinoa', quantity: '160 g'),
        RecipeIngredient(name: 'cannellini beans', quantity: '150 g'),
        RecipeIngredient(name: 'cucumber', quantity: '100 g'),
        RecipeIngredient(name: 'cherry tomatoes', quantity: '120 g'),
        RecipeIngredient(name: 'olive oil', quantity: '2 tsp'),
        RecipeIngredient(name: 'lemon juice', quantity: '1 tbsp'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text:
              'Rinse and drain the beans, then add them to a large bowl with the quinoa.',
        ),
        RecipeInstruction(
          step: 2,
          text:
              'Dice the cucumber, halve the tomatoes, and fold them into the bowl.',
        ),
        RecipeInstruction(
          step: 3,
          text: 'Whisk olive oil with lemon juice and toss through the salad.',
        ),
      ],
      supportedDiets: {'omnivore', 'vegetarian', 'vegan', 'pescatarian'},
      allergens: {},
      tags: {'plant_based', 'lighter_meal'},
    ),
    CookForGoalRecipe(
      id: 'chickpea_avocado_cups',
      name: 'Chickpea Avocado Lettuce Cups',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 390,
        proteinG: 18,
        carbsG: 48,
        fatG: 16,
      ),
      servings: 1,
      preparationMinutes: 12,
      cookingMinutes: 0,
      ingredients: [
        RecipeIngredient(name: 'cooked chickpeas', quantity: '180 g'),
        RecipeIngredient(name: 'avocado', quantity: '70 g'),
        RecipeIngredient(name: 'romaine lettuce leaves', quantity: '6 large'),
        RecipeIngredient(name: 'diced tomato', quantity: '100 g'),
        RecipeIngredient(name: 'lime juice', quantity: '1 tbsp'),
        RecipeIngredient(name: 'ground cumin', quantity: '1/2 tsp'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text:
              'Mash half the chickpeas with the avocado, lime juice, and cumin.',
        ),
        RecipeInstruction(
          step: 2,
          text: 'Fold in the remaining chickpeas and diced tomato.',
        ),
        RecipeInstruction(
          step: 3,
          text:
              'Spoon the mixture evenly into the lettuce leaves and serve immediately.',
        ),
      ],
      supportedDiets: {'omnivore', 'vegetarian', 'vegan', 'pescatarian'},
      allergens: {},
      tags: {'plant_based', 'lighter_meal', 'quick'},
    ),
    CookForGoalRecipe(
      id: 'black_bean_corn_bowl',
      name: 'Black Bean Corn Quinoa Bowl',
      imageAssetPath: null,
      nutrition: RecipeNutrition(
        calories: 475,
        proteinG: 22,
        carbsG: 75,
        fatG: 11,
      ),
      servings: 1,
      preparationMinutes: 10,
      cookingMinutes: 3,
      ingredients: [
        RecipeIngredient(name: 'cooked black beans', quantity: '160 g'),
        RecipeIngredient(name: 'cooked quinoa', quantity: '150 g'),
        RecipeIngredient(name: 'corn kernels', quantity: '100 g'),
        RecipeIngredient(name: 'prepared salsa', quantity: '60 g'),
        RecipeIngredient(name: 'lime juice', quantity: '1 tbsp'),
        RecipeIngredient(name: 'fresh cilantro', quantity: '1 tbsp'),
      ],
      instructions: [
        RecipeInstruction(
          step: 1,
          text:
              'Warm the black beans, quinoa, and corn together in a covered skillet for 3 minutes.',
        ),
        RecipeInstruction(
          step: 2,
          text: 'Transfer to a bowl and spoon the salsa over the top.',
        ),
        RecipeInstruction(
          step: 3,
          text: 'Finish with lime juice and chopped cilantro.',
        ),
      ],
      supportedDiets: {'omnivore', 'vegetarian', 'vegan', 'pescatarian'},
      allergens: {},
      tags: {'plant_based', 'recovery_carbs', 'quick'},
    ),
  ];
}

class CookForGoalRecipeService {
  final CookForGoalRecipeProvider provider;

  const CookForGoalRecipeService({required this.provider});

  CookForGoalNeeds calculateNeeds({
    required PerformanceFuel fuel,
    required NutritionFoodDay consumedToday,
  }) {
    final totals = consumedToday.totals;
    final remainingCalories = math.max(
      0.0,
      fuel.calories.target - totals.calories,
    );
    final remainingProtein = math.max(0.0, fuel.proteinG - totals.proteinG);
    final remainingCarbs = math.max(0.0, fuel.carbsG - totals.carbsG);
    final remainingFat = math.max(0.0, fuel.fatG - totals.fatG);
    double mealTarget(double remaining, double fraction, double maximum) {
      if (remaining <= 0) return 0;
      return math.min(
        maximum,
        math.max(remaining * fraction, remaining * 0.30),
      );
    }

    return CookForGoalNeeds(
      remainingCalories: remainingCalories,
      remainingProteinG: remainingProtein,
      remainingCarbsG: remainingCarbs,
      remainingFatG: remainingFat,
      mealCalories: remainingCalories <= 400
          ? math.max(250.0, remainingCalories)
          : math.min(700.0, remainingCalories * 0.50),
      mealProteinG: mealTarget(remainingProtein, 0.50, 55),
      mealCarbsG: mealTarget(remainingCarbs, 0.45, 85),
      mealFatG: mealTarget(remainingFat, 0.40, 25),
    );
  }

  Future<List<RankedCookForGoalRecipe>> recommend({
    required PerformanceFuel fuel,
    required NutritionFoodDay consumedToday,
    required NutritionProfile profile,
    required bool demandingRecovery,
    int limit = 3,
  }) async {
    final needs = calculateNeeds(fuel: fuel, consumedToday: consumedToday);
    final recipes = await provider.loadRecipes();
    final allowed = recipes.where((recipe) => _isAllowed(recipe, profile));
    final ranked =
        allowed
            .map(
              (recipe) => RankedCookForGoalRecipe(
                recipe: recipe,
                reason: _reason(recipe, needs, demandingRecovery),
                score: _score(recipe, needs, fuel, demandingRecovery),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(limit).toList(growable: false);
  }

  bool _isAllowed(CookForGoalRecipe recipe, NutritionProfile profile) {
    final diet = _normalize(profile.dietType);
    if (diet.isNotEmpty && !recipe.supportedDiets.contains(diet)) return false;
    final excludedAllergens = profile.foodAllergies
        .map(_normalize)
        .where((value) => value != 'none' && value != 'other')
        .toSet();
    if (recipe.allergens.any(excludedAllergens.contains)) return false;
    final excludedFoods = {
      ...profile.foodsToAvoid.map(_normalize),
      ...profile.dislikedFoods.map(_normalize),
    }.where((value) => value.isNotEmpty).toSet();
    if (recipe.allergens.any(excludedFoods.contains)) return false;
    if (recipe.allergens.contains('seafood') &&
        excludedFoods.any((value) => value == 'fish')) {
      return false;
    }
    for (final ingredient in recipe.ingredients) {
      final ingredientName = _normalize(ingredient.name);
      if (excludedFoods.any(
        (excluded) =>
            ingredientName.contains(excluded) ||
            excluded.contains(ingredientName),
      )) {
        return false;
      }
    }
    final maximumMinutes = _maximumMinutes(profile.maximumCookingTime);
    return maximumMinutes == null || recipe.totalMinutes <= maximumMinutes;
  }

  double _score(
    CookForGoalRecipe recipe,
    CookForGoalNeeds needs,
    PerformanceFuel fuel,
    bool demandingRecovery,
  ) {
    final nutrition = recipe.nutrition;
    double fit(num actual, double target) {
      if (target <= 0) return actual == 0 ? 1 : 0;
      return 1 - ((actual - target).abs() / target).clamp(0, 1);
    }

    final proteinGap = needs.remainingProteinG / math.max(1, fuel.proteinG);
    final carbGap = needs.remainingCarbsG / math.max(1, fuel.carbsG);
    final fatGap = needs.remainingFatG / math.max(1, fuel.fatG);
    var score = fit(nutrition.calories, needs.mealCalories) * 3;
    score += fit(nutrition.proteinG, needs.mealProteinG) * (1 + proteinGap * 4);
    score += fit(nutrition.carbsG, needs.mealCarbsG) * (1 + carbGap * 3);
    score += fit(nutrition.fatG, needs.mealFatG) * (1 + fatGap * 2);
    if (nutrition.calories > needs.remainingCalories &&
        needs.remainingCalories > 0) {
      score -= 2;
    }
    if (demandingRecovery && recipe.tags.contains('recovery_carbs')) {
      score += 1.25;
    }
    if (proteinGap >= carbGap && recipe.tags.contains('high_protein')) {
      score += 1;
    }
    if (fuel.goal == 'muscle_gain' && recipe.tags.contains('high_protein')) {
      score += 0.75;
    }
    if (fuel.goal == 'fat_loss' && nutrition.calories <= needs.mealCalories) {
      score += 0.50;
    }
    return score;
  }

  String _reason(
    CookForGoalRecipe recipe,
    CookForGoalNeeds needs,
    bool demandingRecovery,
  ) {
    if (demandingRecovery && recipe.tags.contains('recovery_carbs')) {
      return 'Provides protein and carbohydrates suited to today’s demanding training.';
    }
    if (needs.remainingCalories <= 500 &&
        recipe.tags.contains('lighter_meal')) {
      return 'A lighter meal that fits today’s smaller remaining calorie allowance.';
    }
    final proteinShare =
        needs.remainingProteinG / math.max(1, needs.mealProteinG);
    final carbShare = needs.remainingCarbsG / math.max(1, needs.mealCarbsG);
    if (proteinShare >= carbShare && recipe.nutrition.proteinG >= 30) {
      return 'High in protein to help close today’s remaining protein target.';
    }
    if (recipe.nutrition.carbsG >= 50) {
      return 'Provides practical carbohydrates for today’s remaining needs.';
    }
    return 'Balanced for the calories and macros you have remaining today.';
  }

  int? _maximumMinutes(String value) {
    final match = RegExp(r'(\d+)').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
