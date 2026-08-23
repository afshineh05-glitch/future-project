import 'package:flutter/foundation.dart';

import 'package:future_project/models/meal_builder_result.dart';
import 'package:future_project/models/nutrition_profile.dart';

class MealBuilderSubstitution {
  final MealBuilderResult result;
  final int alternativeIndex;

  const MealBuilderSubstitution({
    required this.result,
    required this.alternativeIndex,
  });
}

class MealBuilderSubstitutionService {
  const MealBuilderSubstitutionService();

  static const List<_SubstitutionFood> _catalog = [
    _SubstitutionFood(
      'turkey',
      'Turkey',
      'protein',
      135,
      29,
      0,
      1.8,
      80,
      220,
      10,
      ['omnivore'],
    ),
    _SubstitutionFood(
      'chicken_breast',
      'Chicken Breast',
      'protein',
      165,
      31,
      0,
      3.6,
      80,
      220,
      10,
      ['omnivore'],
    ),
    _SubstitutionFood(
      'tuna',
      'Tuna',
      'protein',
      132,
      29,
      0,
      1,
      80,
      200,
      10,
      ['omnivore', 'pescatarian'],
      ['seafood'],
    ),
    _SubstitutionFood(
      'salmon',
      'Salmon',
      'protein',
      208,
      20,
      0,
      13,
      90,
      200,
      10,
      ['omnivore', 'pescatarian'],
      ['seafood'],
    ),
    _SubstitutionFood(
      'lean_beef',
      'Lean Beef',
      'protein',
      217,
      26,
      0,
      12,
      80,
      200,
      10,
      ['omnivore'],
    ),
    _SubstitutionFood(
      'eggs',
      'Eggs',
      'protein',
      143,
      13,
      0.7,
      9.5,
      50,
      200,
      50,
      ['omnivore', 'pescatarian', 'vegetarian'],
      ['eggs'],
    ),
    _SubstitutionFood(
      'egg_whites',
      'Egg Whites',
      'protein',
      52,
      11,
      0.7,
      0.2,
      100,
      300,
      25,
      ['omnivore', 'pescatarian', 'vegetarian'],
      ['eggs'],
    ),
    _SubstitutionFood(
      'greek_yogurt',
      'Greek Yogurt',
      'protein',
      73,
      10,
      3.9,
      2,
      100,
      300,
      25,
      ['omnivore', 'pescatarian', 'vegetarian'],
      ['dairy'],
    ),
    _SubstitutionFood(
      'cottage_cheese',
      'Cottage Cheese',
      'protein',
      98,
      11,
      3.4,
      4.3,
      100,
      250,
      25,
      ['omnivore', 'pescatarian', 'vegetarian'],
      ['dairy'],
    ),
    _SubstitutionFood(
      'tofu',
      'Tofu',
      'protein',
      144,
      17,
      2.8,
      8.7,
      100,
      300,
      25,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'tempeh',
      'Tempeh',
      'protein',
      193,
      20,
      7.6,
      11,
      80,
      260,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'lentils',
      'Lentils',
      'protein',
      116,
      9,
      20,
      0.4,
      100,
      300,
      25,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'beans',
      'Beans',
      'protein',
      127,
      8.7,
      23,
      0.5,
      100,
      300,
      25,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood('rice', 'Rice', 'carb', 130, 2.7, 28, 0.3, 80, 300, 20, [
      'omnivore',
      'pescatarian',
      'vegetarian',
      'vegan',
    ]),
    _SubstitutionFood(
      'rice_brown',
      'Brown Rice',
      'carb',
      123,
      2.7,
      26,
      1,
      80,
      300,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'potato',
      'Potato',
      'carb',
      87,
      1.9,
      20,
      0.1,
      120,
      400,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'sweet_potato',
      'Sweet Potato',
      'carb',
      90,
      2,
      21,
      0.2,
      120,
      350,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'quinoa',
      'Quinoa',
      'carb',
      120,
      4.4,
      21,
      1.9,
      80,
      300,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood('oats', 'Oats', 'carb', 379, 13, 68, 6.5, 30, 100, 10, [
      'omnivore',
      'pescatarian',
      'vegetarian',
      'vegan',
    ]),
    _SubstitutionFood(
      'whole_grain_bread',
      'Whole-grain Bread',
      'carb',
      247,
      13,
      41,
      4.2,
      30,
      150,
      30,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
      ['gluten'],
    ),
    _SubstitutionFood(
      'pasta',
      'Pasta',
      'carb',
      158,
      5.8,
      31,
      0.9,
      80,
      250,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
      ['gluten'],
    ),
    _SubstitutionFood(
      'beans',
      'Beans',
      'carb',
      127,
      8.7,
      23,
      0.5,
      100,
      300,
      25,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'lentils',
      'Lentils',
      'carb',
      116,
      9,
      20,
      0.4,
      100,
      300,
      25,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'mixed_vegetables',
      'Mixed Vegetables',
      'vegetable',
      65,
      3,
      12,
      0.5,
      80,
      220,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'broccoli',
      'Broccoli',
      'vegetable',
      35,
      2.4,
      7.2,
      0.4,
      80,
      200,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'spinach',
      'Spinach',
      'vegetable',
      23,
      2.9,
      3.6,
      0.4,
      60,
      180,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'green_beans',
      'Green Beans',
      'vegetable',
      35,
      1.9,
      7.9,
      0.3,
      80,
      220,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'mixed_salad',
      'Mixed Salad',
      'vegetable',
      25,
      1.5,
      4.5,
      0.3,
      80,
      220,
      20,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'olive_oil',
      'Olive Oil',
      'fat',
      884,
      0,
      0,
      100,
      3,
      15,
      1,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'avocado',
      'Avocado',
      'fat',
      160,
      2,
      8.5,
      15,
      30,
      120,
      10,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
    ),
    _SubstitutionFood(
      'almonds',
      'Almonds',
      'fat',
      579,
      21,
      22,
      50,
      10,
      35,
      5,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
      ['nuts'],
    ),
    _SubstitutionFood(
      'walnuts',
      'Walnuts',
      'fat',
      654,
      15,
      14,
      65,
      10,
      35,
      5,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
      ['nuts'],
    ),
    _SubstitutionFood(
      'peanut_butter',
      'Peanut Butter',
      'fat',
      588,
      25,
      20,
      50,
      10,
      35,
      5,
      ['omnivore', 'pescatarian', 'vegetarian', 'vegan'],
      ['nuts'],
    ),
    _SubstitutionFood('seeds', 'Seeds', 'fat', 560, 20, 18, 47, 10, 35, 5, [
      'omnivore',
      'pescatarian',
      'vegetarian',
      'vegan',
    ]),
  ];

  MealBuilderSubstitution? nextAlternative({
    required MealBuilderResult currentResult,
    required int foodIndex,
    required NutritionProfile profile,
    int? currentAlternativeIndex,
  }) {
    if (foodIndex < 0 || foodIndex >= currentResult.foods.length) return null;
    final currentFood = currentResult.foods[foodIndex];
    final normalizedCurrent = _normalize(
      currentFood.foodKey.isNotEmpty
          ? currentFood.foodKey
          : currentFood.displayName,
    );
    final role = currentFood.role.isNotEmpty
        ? _normalize(currentFood.role)
        : switch (foodIndex) {
            0 => 'protein',
            1 => 'carb',
            2 => 'vegetable',
            _ => 'fat',
          };
    final roleCandidates = _catalog.where((food) => food.role == role).toList();
    final rejectionReasons = <String>[];
    final validCandidates = roleCandidates.where((food) {
      final reason = _rejectionReason(food, profile);
      if (reason != null) rejectionReasons.add('${food.displayName}: $reason');
      return reason == null;
    }).toList();

    debugPrint('SUBSTITUTION DEBUG');
    debugPrint('currentFood: ${currentFood.displayName}');
    debugPrint('normalizedCurrentFood: $normalizedCurrent');
    debugPrint('role: $role');
    debugPrint('candidateCountBeforeFiltering: ${roleCandidates.length}');
    debugPrint(
      'candidatesBeforeFiltering: ${roleCandidates.map((food) => food.displayName).toList()}',
    );
    debugPrint('candidateCountAfterFiltering: ${validCandidates.length}');
    debugPrint(
      'candidatesAfterFiltering: ${validCandidates.map((food) => food.displayName).toList()}',
    );

    final usedKeys = currentResult.foods
        .asMap()
        .entries
        .where((entry) => entry.key != foodIndex)
        .map(
          (entry) => _normalize(
            entry.value.foodKey.isNotEmpty
                ? entry.value.foodKey
                : entry.value.displayName,
          ),
        )
        .toSet();
    final startingIndex =
        currentAlternativeIndex ??
        validCandidates.indexWhere((food) => food.key == normalizedCurrent);
    for (var offset = 1; offset <= validCandidates.length; offset++) {
      final index =
          ((startingIndex < 0 ? -1 : startingIndex) + offset) %
          validCandidates.length;
      final candidate = validCandidates[index];
      if (candidate.key == normalizedCurrent ||
          usedKeys.contains(candidate.key)) {
        continue;
      }
      final amount = _replacementAmount(currentFood, candidate, role);
      final replacement = candidate.toMealBuilderFood(amount, role);
      debugPrint('selectedAlternative: ${candidate.displayName}');
      debugPrint('rejectionReasons: $rejectionReasons');
      return MealBuilderSubstitution(
        result: currentResult.replacingFood(foodIndex, replacement),
        alternativeIndex: index,
      );
    }
    debugPrint('selectedAlternative: none');
    debugPrint('rejectionReasons: $rejectionReasons');
    return null;
  }

  String? _rejectionReason(_SubstitutionFood food, NutritionProfile profile) {
    final diet = _normalize(profile.dietType);
    if (!food.diets.contains(diet)) return 'diet type $diet';
    final allergies = profile.foodAllergies
        .map(_normalize)
        .where((item) => item != 'none' && item != 'other')
        .toSet();
    final blockedAllergy = food.allergens.where(allergies.contains).toList();
    if (blockedAllergy.isNotEmpty) {
      return 'allergy ${blockedAllergy.join(', ')}';
    }
    for (final value in profile.foodsToAvoid) {
      if (_matchesFood(value, food)) return 'foods to avoid: $value';
    }
    for (final value in profile.dislikedFoods) {
      if (_matchesFood(value, food)) return 'disliked food: $value';
    }
    return null;
  }

  bool _matchesFood(String value, _SubstitutionFood food) {
    final term = _normalize(value);
    return term.isNotEmpty &&
        (term == food.key ||
            food.key.contains(term) ||
            term.contains(food.key));
  }

  int _replacementAmount(
    MealBuilderFood current,
    _SubstitutionFood food,
    String role,
  ) {
    final desired = switch (role) {
      'protein' => current.nutrition.proteinG.toDouble(),
      'carb' => current.nutrition.carbsG.toDouble(),
      'fat' => current.nutrition.fatG.toDouble(),
      _ => current.nutrition.calories.toDouble(),
    };
    final per100 = switch (role) {
      'protein' => food.protein,
      'carb' => food.carbs,
      'fat' => food.fat,
      _ => food.calories,
    };
    final raw = per100 > 0
        ? desired / per100 * 100
        : current.amountG.toDouble();
    final bounded = raw.clamp(food.minG.toDouble(), food.maxG.toDouble());
    return ((bounded / food.stepG).round() * food.stepG)
        .clamp(food.minG, food.maxG)
        .toInt();
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

class _SubstitutionFood {
  final String key;
  final String displayName;
  final String role;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int minG;
  final int maxG;
  final int stepG;
  final List<String> diets;
  final List<String> allergens;

  const _SubstitutionFood(
    this.key,
    this.displayName,
    this.role,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.minG,
    this.maxG,
    this.stepG,
    this.diets, [
    this.allergens = const [],
  ]);

  MealBuilderFood toMealBuilderFood(int amountG, String currentRole) {
    final scale = amountG / 100;
    return MealBuilderFood(
      foodKey: key,
      displayName: displayName,
      amountG: amountG,
      role: currentRole,
      alternatives: const [],
      nutrition: MealBuilderMacros(
        calories: (calories * scale).round(),
        proteinG: (protein * scale).round(),
        carbsG: (carbs * scale).round(),
        fatG: (fat * scale).round(),
      ),
    );
  }
}
