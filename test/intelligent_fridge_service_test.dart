import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/cook_for_goal_recipe.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/models/performance_fuel.dart';
import 'package:future_project/services/intelligent_fridge_service.dart';

void main() {
  const fuel = PerformanceFuel(
    goal: 'fitness',
    calories: PerformanceFuelCalories(
      target: 2200,
      rangeMin: 2100,
      rangeMax: 2300,
    ),
    proteinG: 140,
    carbsG: 240,
    fatG: 70,
    fiberG: 30,
    hydrationL: 2.5,
    micronutrientFocus: [],
    why: '',
    calculationVersion: 'test',
    generatedAt: null,
    cached: false,
  );

  const omnivore = NutritionProfile(
    userId: 'user',
    dietType: 'Omnivore',
    foodAllergies: [],
    foodsToAvoid: [],
    dislikedFoods: [],
    mealsPerDay: '3',
    maximumCookingTime: '45',
    cookingSkill: 'Beginner',
    foodBudget: 'Moderate',
  );

  test('inventory persists and is subtracted from weekly need', () async {
    final repository = _MemoryRepository();
    await repository.saveItem(
      const FridgeItem(
        userId: 'user',
        ingredientKey: 'chicken_breast',
        ingredientName: 'Chicken Breast',
        category: 'Protein',
        quantity: 600,
        quantityUnit: 'g',
      ),
    );
    await repository.savePreferredFoodKeys({'chicken_breast', 'eggs'});

    final state = await IntelligentFridgeService(
      repository: repository,
    ).load(fuel: fuel, profile: omnivore, trainingDays: 4, recipes: const []);
    final chicken = state.recommendations.firstWhere(
      (item) => item.food.key == 'chicken_breast',
    );
    final eggs = state.recommendations.firstWhere(
      (item) => item.food.key == 'eggs',
    );

    expect(state.inventory.single.quantity, 600);
    expect(chicken.inFridgeGrams, 600);
    expect(chicken.purchaseGrams, chicken.suggestedGrams - 600);
    expect(chicken.suggestedGrams, lessThan(140 * 7 / .31));
    expect(eggs.suggestedGrams, greaterThan(0));
    expect(
      state.groceryList.map((item) => item.food.key).toSet().length,
      state.groceryList.length,
    );
  });

  test('diet and allergy restrictions filter deterministic references', () {
    const veganWithSoyAllergy = NutritionProfile(
      userId: 'user',
      dietType: 'Vegan',
      foodAllergies: ['Soy'],
      foodsToAvoid: [],
      dislikedFoods: [],
      mealsPerDay: '3',
      maximumCookingTime: '45',
      cookingSkill: 'Beginner',
      foodBudget: 'Moderate',
    );
    final result = const WeeklyFoodRequirementCalculator().calculate(
      fuel: fuel,
      profile: veganWithSoyAllergy,
      trainingDays: 3,
      inventory: const [],
      preferredFoodKeys: const {'chicken_breast', 'tofu', 'lentils'},
    );

    expect(result.any((item) => item.food.key == 'chicken_breast'), isFalse);
    expect(result.any((item) => item.food.key == 'tofu'), isFalse);
    expect(result.any((item) => item.food.key == 'lentils'), isTrue);
  });

  test('recipe availability is secondary to nutrition score', () {
    final strong = _ranked('strong', 10, ['Chicken Breast', 'Broccoli']);
    final weaker = _ranked('weaker', 8, ['Chicken Breast']);
    final matches = const RecipeFridgeMatcher().match(
      [strong, weaker],
      const [
        FridgeItem(
          userId: 'user',
          ingredientKey: 'chicken_breast',
          ingredientName: 'Chicken Breast',
          category: 'Protein',
        ),
      ],
    );

    expect(matches.first.rankedRecipe.recipe.id, 'strong');
    expect(matches.first.status, 'Almost Ready');
    expect(matches.last.status, 'Ready to Cook');
  });

  test('commerce package matching and outbound URL remain commerce-safe', () {
    const service = CommercePartnerService();
    final package = service.matchPackage(neededGrams: 1500, packageGrams: 1000);
    final partner = CommercePartner(
      id: 'store',
      name: 'Store',
      market: 'grocery',
      country: 'CA',
      destinationUrl: Uri.parse('https://example.test/shop'),
      active: true,
    );
    final uri = service.outboundUri(partner, 'chicken_breast');

    expect(package.packageCount, 2);
    expect(package.remainingGrams, 500);
    expect(uri.queryParameters, {'ingredient': 'chicken_breast'});
    expect(service.activeForCountry('CA'), isNull);
  });
}

RankedCookForGoalRecipe _ranked(
  String id,
  double score,
  List<String> ingredients,
) => RankedCookForGoalRecipe(
  score: score,
  reason: 'test',
  recipe: CookForGoalRecipe(
    id: id,
    name: id,
    imageAssetPath: null,
    nutrition: const RecipeNutrition(
      calories: 500,
      proteinG: 40,
      carbsG: 50,
      fatG: 15,
    ),
    servings: 1,
    preparationMinutes: 10,
    cookingMinutes: 20,
    ingredients: ingredients
        .map((name) => RecipeIngredient(name: name, quantity: '1'))
        .toList(),
    instructions: const [],
    supportedDiets: const {'omnivore'},
    allergens: const {},
    tags: const {},
  ),
);

class _MemoryRepository implements FridgeInventoryRepository {
  final Map<String, FridgeItem> items = {};
  Set<String> preferences = {};

  @override
  Future<List<FridgeItem>> load() async => items.values.toList();

  @override
  Future<Set<String>> loadPreferredFoodKeys() async => {...preferences};

  @override
  Future<void> removeItem(String ingredientKey) async {
    items.remove(ingredientKey);
  }

  @override
  Future<void> saveItem(FridgeItem item) async {
    items[item.ingredientKey] = item;
  }

  @override
  Future<void> savePreferredFoodKeys(Set<String> keys) async {
    preferences = {...keys};
  }
}
