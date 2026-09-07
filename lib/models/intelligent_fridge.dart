import 'package:future_project/models/cook_for_goal_recipe.dart';

class FridgeFoodReference {
  final String key;
  final String name;
  final String category;
  final double caloriesPer100G;
  final double proteinPer100G;
  final double carbsPer100G;
  final double fatPer100G;
  final String macroFocus;
  final Set<String> supportedDiets;
  final Set<String> allergens;
  final List<String> aliases;

  const FridgeFoodReference({
    required this.key,
    required this.name,
    required this.category,
    required this.caloriesPer100G,
    required this.proteinPer100G,
    required this.carbsPer100G,
    required this.fatPer100G,
    required this.macroFocus,
    required this.supportedDiets,
    this.allergens = const {},
    this.aliases = const [],
  });
}

class FridgeItem {
  final String? id;
  final String userId;
  final String ingredientKey;
  final String ingredientName;
  final String category;
  final double? quantity;
  final String? quantityUnit;
  final bool isAvailable;

  const FridgeItem({
    this.id,
    required this.userId,
    required this.ingredientKey,
    required this.ingredientName,
    required this.category,
    this.quantity,
    this.quantityUnit,
    this.isAvailable = true,
  });

  factory FridgeItem.fromMap(Map<String, dynamic> map) => FridgeItem(
    id: map['id']?.toString(),
    userId: map['user_id']?.toString() ?? '',
    ingredientKey: map['ingredient_key']?.toString() ?? '',
    ingredientName: map['ingredient_name']?.toString() ?? '',
    category: map['category']?.toString() ?? '',
    quantity: (map['quantity'] as num?)?.toDouble(),
    quantityUnit: map['quantity_unit']?.toString(),
    isAvailable: map['is_available'] != false,
  );
}

class FoodSourcePreference {
  final String ingredientKey;
  final double weight;

  const FoodSourcePreference({
    required this.ingredientKey,
    required this.weight,
  });
}

class WeeklyFoodRequirement {
  final FridgeFoodReference food;
  final double suggestedGrams;
  final double inFridgeGrams;

  const WeeklyFoodRequirement({
    required this.food,
    required this.suggestedGrams,
    required this.inFridgeGrams,
  });

  double get purchaseGrams =>
      (suggestedGrams - inFridgeGrams).clamp(0, double.infinity);
}

class FridgeRecipeMatch {
  final RankedCookForGoalRecipe rankedRecipe;
  final List<RecipeIngredient> missingIngredients;
  final int availableCount;

  const FridgeRecipeMatch({
    required this.rankedRecipe,
    required this.missingIngredients,
    required this.availableCount,
  });

  int get totalCount => rankedRecipe.recipe.ingredients.length;
  bool get ready => missingIngredients.isEmpty;
  String get status => ready
      ? 'Ready to Cook'
      : missingIngredients.length == 1
      ? 'Almost Ready'
      : 'Missing ${missingIngredients.length} ingredients';
}

class CommercePartner {
  final String id;
  final String name;
  final String market;
  final String country;
  final Uri destinationUrl;
  final bool active;

  const CommercePartner({
    required this.id,
    required this.name,
    required this.market,
    required this.country,
    required this.destinationUrl,
    required this.active,
  });
}

class PurchaseQuantityMatch {
  final int packageCount;
  final double packageGrams;
  final double remainingGrams;

  const PurchaseQuantityMatch({
    required this.packageCount,
    required this.packageGrams,
    required this.remainingGrams,
  });
}

class IntelligentFridgeState {
  final List<FridgeItem> inventory;
  final Set<String> preferredFoodKeys;
  final List<WeeklyFoodRequirement> recommendations;
  final List<FridgeRecipeMatch> recipeMatches;
  final List<WeeklyFoodRequirement> groceryList;

  const IntelligentFridgeState({
    required this.inventory,
    required this.preferredFoodKeys,
    required this.recommendations,
    required this.recipeMatches,
    required this.groceryList,
  });
}
