class RecipeNutrition {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const RecipeNutrition({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

class RecipeIngredient {
  final String name;
  final String quantity;

  const RecipeIngredient({required this.name, required this.quantity});
}

class RecipeInstruction {
  final int step;
  final String text;

  const RecipeInstruction({required this.step, required this.text});
}

class CookForGoalRecipe {
  final String id;
  final String name;
  final String? imageAssetPath;
  final RecipeNutrition nutrition;
  final int servings;
  final int preparationMinutes;
  final int cookingMinutes;
  final List<RecipeIngredient> ingredients;
  final List<RecipeInstruction> instructions;
  final Set<String> supportedDiets;
  final Set<String> allergens;
  final Set<String> tags;

  const CookForGoalRecipe({
    required this.id,
    required this.name,
    required this.imageAssetPath,
    required this.nutrition,
    required this.servings,
    required this.preparationMinutes,
    required this.cookingMinutes,
    required this.ingredients,
    required this.instructions,
    required this.supportedDiets,
    required this.allergens,
    required this.tags,
  });

  int get totalMinutes => preparationMinutes + cookingMinutes;
}

class RankedCookForGoalRecipe {
  final CookForGoalRecipe recipe;
  final String reason;
  final double score;

  const RankedCookForGoalRecipe({
    required this.recipe,
    required this.reason,
    required this.score,
  });
}

class CookForGoalNeeds {
  final double remainingCalories;
  final double remainingProteinG;
  final double remainingCarbsG;
  final double remainingFatG;
  final double mealCalories;
  final double mealProteinG;
  final double mealCarbsG;
  final double mealFatG;

  const CookForGoalNeeds({
    required this.remainingCalories,
    required this.remainingProteinG,
    required this.remainingCarbsG,
    required this.remainingFatG,
    required this.mealCalories,
    required this.mealProteinG,
    required this.mealCarbsG,
    required this.mealFatG,
  });
}
