class MealBuilderMacros {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const MealBuilderMacros({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory MealBuilderMacros.fromMap(Map<String, dynamic> map) {
    return MealBuilderMacros(
      calories: (map['calories'] as num? ?? 0).round(),
      proteinG: (map['protein_g'] as num? ?? 0).round(),
      carbsG: (map['carbs_g'] as num? ?? 0).round(),
      fatG: (map['fat_g'] as num? ?? 0).round(),
    );
  }
}

class MealBuilderFoodAlternative {
  final String foodKey;
  final String displayName;
  final double caloriesPer100G;
  final double proteinPer100G;
  final double carbsPer100G;
  final double fatPer100G;
  final int minG;
  final int maxG;
  final int stepG;

  const MealBuilderFoodAlternative({
    required this.foodKey,
    required this.displayName,
    required this.caloriesPer100G,
    required this.proteinPer100G,
    required this.carbsPer100G,
    required this.fatPer100G,
    required this.minG,
    required this.maxG,
    required this.stepG,
  });

  factory MealBuilderFoodAlternative.fromMap(Map<String, dynamic> map) {
    return MealBuilderFoodAlternative(
      foodKey: map['food_key']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'Food',
      caloriesPer100G: (map['calories_per_100g'] as num? ?? 0).toDouble(),
      proteinPer100G: (map['protein_per_100g'] as num? ?? 0).toDouble(),
      carbsPer100G: (map['carbs_per_100g'] as num? ?? 0).toDouble(),
      fatPer100G: (map['fat_per_100g'] as num? ?? 0).toDouble(),
      minG: (map['min_g'] as num? ?? 0).round(),
      maxG: (map['max_g'] as num? ?? 0).round(),
      stepG: (map['step_g'] as num? ?? 1).round(),
    );
  }
}

class MealBuilderFood {
  final String foodKey;
  final String displayName;
  final int amountG;
  final MealBuilderMacros nutrition;
  final String role;
  final List<MealBuilderFoodAlternative> alternatives;

  const MealBuilderFood({
    required this.foodKey,
    required this.displayName,
    required this.amountG,
    required this.nutrition,
    required this.role,
    required this.alternatives,
  });

  factory MealBuilderFood.fromMap(Map<String, dynamic> map) {
    return MealBuilderFood(
      foodKey: map['food_key']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'Food',
      amountG: (map['amount_g'] as num? ?? 0).round(),
      nutrition: MealBuilderMacros.fromMap(map),
      role: map['role']?.toString() ?? '',
      alternatives: ((map['alternatives'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => MealBuilderFoodAlternative.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class MealBuilderResult {
  final MealBuilderMacros target;
  final List<MealBuilderFood> foods;
  final MealBuilderMacros totals;
  final String reason;
  final bool recoveryContext;
  final int mealsRemainingEstimate;

  const MealBuilderResult({
    required this.target,
    required this.foods,
    required this.totals,
    required this.reason,
    required this.recoveryContext,
    required this.mealsRemainingEstimate,
  });

  factory MealBuilderResult.fromMap(Map<String, dynamic> map) {
    final target = map['target'];
    final totals = map['totals'];
    if (target is! Map || totals is! Map || map['foods'] is! List) {
      throw const FormatException('Meal Builder returned an invalid result.');
    }
    return MealBuilderResult(
      target: MealBuilderMacros.fromMap(Map<String, dynamic>.from(target)),
      foods: (map['foods'] as List)
          .whereType<Map>()
          .map(
            (food) => MealBuilderFood.fromMap(Map<String, dynamic>.from(food)),
          )
          .toList(growable: false),
      totals: MealBuilderMacros.fromMap(Map<String, dynamic>.from(totals)),
      reason: map['reason']?.toString() ?? '',
      recoveryContext: map['recovery_context'] == true,
      mealsRemainingEstimate: (map['meals_remaining_estimate'] as num? ?? 1)
          .round(),
    );
  }

  MealBuilderResult replacingFood(int index, MealBuilderFood replacement) {
    final updatedFoods = [...foods]..[index] = replacement;
    final totals = updatedFoods.fold<MealBuilderMacros>(
      const MealBuilderMacros(calories: 0, proteinG: 0, carbsG: 0, fatG: 0),
      (sum, food) => MealBuilderMacros(
        calories: sum.calories + food.nutrition.calories,
        proteinG: sum.proteinG + food.nutrition.proteinG,
        carbsG: sum.carbsG + food.nutrition.carbsG,
        fatG: sum.fatG + food.nutrition.fatG,
      ),
    );
    return MealBuilderResult(
      target: target,
      foods: List.unmodifiable(updatedFoods),
      totals: totals,
      reason: reason,
      recoveryContext: recoveryContext,
      mealsRemainingEstimate: mealsRemainingEstimate,
    );
  }
}
