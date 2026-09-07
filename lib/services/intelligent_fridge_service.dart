import 'dart:math' as math;

import 'package:future_project/models/cook_for_goal_recipe.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/models/performance_fuel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FridgeFoodCatalog {
  static final foods = <FridgeFoodReference>[
    _food(
      'chicken_breast',
      'Chicken Breast',
      'Protein',
      protein: 31,
      calories: 165,
      fat: 3.6,
      diets: _meat,
    ),
    _food(
      'chicken_thigh',
      'Chicken Thigh',
      'Protein',
      protein: 26,
      calories: 209,
      fat: 11,
      diets: _meat,
    ),
    _food(
      'turkey',
      'Turkey Breast',
      'Protein',
      protein: 29,
      calories: 135,
      fat: 1.8,
      diets: _meat,
      aliases: ['lean turkey', 'turkey'],
    ),
    _food(
      'lean_ground_turkey',
      'Lean Ground Turkey',
      'Protein',
      protein: 27,
      calories: 170,
      fat: 7,
      diets: _meat,
    ),
    _food(
      'lean_beef',
      'Lean Beef',
      'Protein',
      protein: 26,
      calories: 210,
      fat: 11,
      diets: _meat,
    ),
    _food(
      'ground_beef',
      'Ground Beef',
      'Protein',
      protein: 26,
      calories: 250,
      fat: 17,
      diets: _meat,
    ),
    _food(
      'steak',
      'Steak',
      'Protein',
      protein: 27,
      calories: 250,
      fat: 15,
      diets: _meat,
    ),
    _food(
      'pork_tenderloin',
      'Pork Tenderloin',
      'Protein',
      protein: 26,
      calories: 143,
      fat: 3.5,
      diets: _meat,
    ),
    _food(
      'eggs',
      'Eggs',
      'Protein',
      protein: 13,
      calories: 143,
      carbs: 1.1,
      fat: 9.5,
      diets: _vegetarian,
      allergens: {'eggs'},
    ),
    _food(
      'egg_whites',
      'Egg Whites',
      'Protein',
      protein: 11,
      calories: 52,
      carbs: .7,
      fat: .2,
      diets: _vegetarian,
      allergens: {'eggs'},
    ),
    _food(
      'tofu',
      'Tofu',
      'Protein',
      protein: 17,
      calories: 144,
      carbs: 3,
      fat: 9,
      allergens: {'soy'},
      aliases: ['extra-firm tofu', 'tofu'],
    ),
    _food(
      'tempeh',
      'Tempeh',
      'Protein',
      protein: 20,
      calories: 195,
      carbs: 8,
      fat: 11,
      allergens: {'soy'},
    ),
    _food(
      'fish',
      'Fish',
      'Fish & Seafood',
      protein: 22,
      calories: 140,
      fat: 5,
      diets: _seafood,
      allergens: {'seafood'},
    ),
    _food(
      'salmon',
      'Salmon',
      'Fish & Seafood',
      protein: 20,
      calories: 208,
      fat: 13,
      diets: _seafood,
      allergens: {'seafood'},
      aliases: ['salmon fillet', 'salmon'],
    ),
    _food(
      'tuna',
      'Tuna',
      'Fish & Seafood',
      protein: 29,
      calories: 132,
      fat: 1,
      diets: _seafood,
      allergens: {'seafood'},
    ),
    _food(
      'cod',
      'Cod',
      'Fish & Seafood',
      protein: 23,
      calories: 105,
      fat: .9,
      diets: _seafood,
      allergens: {'seafood'},
    ),
    _food(
      'tilapia',
      'Tilapia',
      'Fish & Seafood',
      protein: 26,
      calories: 128,
      fat: 2.7,
      diets: _seafood,
      allergens: {'seafood'},
    ),
    _food(
      'trout',
      'Trout',
      'Fish & Seafood',
      protein: 24,
      calories: 168,
      fat: 7,
      diets: _seafood,
      allergens: {'seafood'},
    ),
    _food(
      'shrimp',
      'Shrimp',
      'Fish & Seafood',
      protein: 24,
      calories: 99,
      fat: .3,
      diets: _seafood,
      allergens: {'shellfish'},
    ),
    _food(
      'sardines',
      'Sardines',
      'Fish & Seafood',
      protein: 25,
      calories: 208,
      fat: 11,
      diets: _seafood,
      allergens: {'seafood'},
    ),
    _food(
      'greek_yogurt',
      'Greek Yogurt',
      'Dairy',
      protein: 10,
      calories: 73,
      carbs: 3.9,
      fat: 2,
      macro: 'protein',
      diets: _vegetarian,
      allergens: {'dairy'},
      aliases: ['plain greek yogurt', 'greek yogurt'],
    ),
    _food(
      'cottage_cheese',
      'Cottage Cheese',
      'Dairy',
      protein: 11,
      calories: 98,
      carbs: 3.4,
      fat: 4.3,
      macro: 'protein',
      diets: _vegetarian,
      allergens: {'dairy'},
    ),
    _food(
      'milk',
      'Milk',
      'Dairy',
      protein: 3.2,
      calories: 61,
      carbs: 4.8,
      fat: 3.3,
      diets: _vegetarian,
      allergens: {'dairy'},
    ),
    _food(
      'skim_milk',
      'Skim Milk',
      'Dairy',
      protein: 3.4,
      calories: 34,
      carbs: 5,
      fat: .1,
      diets: _vegetarian,
      allergens: {'dairy'},
    ),
    _food(
      'cheese',
      'Cheese',
      'Dairy',
      protein: 25,
      calories: 400,
      carbs: 1.3,
      fat: 33,
      diets: _vegetarian,
      allergens: {'dairy'},
    ),
    _food(
      'mozzarella',
      'Mozzarella',
      'Dairy',
      protein: 24,
      calories: 300,
      carbs: 2.2,
      fat: 22,
      diets: _vegetarian,
      allergens: {'dairy'},
    ),
    _food(
      'feta',
      'Feta',
      'Dairy',
      protein: 14,
      calories: 264,
      carbs: 4.1,
      fat: 21,
      diets: _vegetarian,
      allergens: {'dairy'},
    ),
    _carb('white_rice', 'White Rice', 28, 130),
    _carb(
      'brown_rice',
      'Brown Rice',
      26,
      123,
      aliases: ['cooked brown rice', 'rice'],
    ),
    _carb('basmati_rice', 'Basmati Rice', 25, 121),
    _carb(
      'oats',
      'Oats',
      68,
      379,
      allergens: {'gluten'},
      aliases: ['rolled oats', 'oats'],
    ),
    _carb('potatoes', 'Potatoes', 20, 87),
    _carb('sweet_potatoes', 'Sweet Potatoes', 20, 90),
    _carb('pasta', 'Pasta', 31, 157, allergens: {'gluten'}),
    _carb(
      'whole_wheat_pasta',
      'Whole Wheat Pasta',
      27,
      149,
      allergens: {'gluten'},
    ),
    _carb('quinoa', 'Quinoa', 21, 120, aliases: ['cooked quinoa', 'quinoa']),
    _carb('bread', 'Bread', 49, 265, allergens: {'gluten'}),
    _carb(
      'whole_wheat_bread',
      'Whole Wheat Bread',
      43,
      247,
      allergens: {'gluten'},
    ),
    _carb('tortilla', 'Tortilla', 48, 312, allergens: {'gluten'}),
    _carb('couscous', 'Couscous', 23, 112, allergens: {'gluten'}),
    for (final entry in const [
      ('broccoli', 'Broccoli'),
      ('spinach', 'Spinach'),
      ('lettuce', 'Lettuce'),
      ('tomato', 'Tomato'),
      ('cucumber', 'Cucumber'),
      ('bell_pepper', 'Bell Pepper'),
      ('onion', 'Onion'),
      ('carrot', 'Carrot'),
      ('mushroom', 'Mushroom'),
      ('zucchini', 'Zucchini'),
      ('asparagus', 'Asparagus'),
      ('green_beans', 'Green Beans'),
      ('cauliflower', 'Cauliflower'),
      ('cabbage', 'Cabbage'),
    ])
      _produce(entry.$1, entry.$2, 'Vegetables'),
    for (final entry in const [
      ('banana', 'Banana'),
      ('apple', 'Apple'),
      ('orange', 'Orange'),
      ('berries', 'Berries'),
      ('blueberries', 'Blueberries'),
      ('strawberries', 'Strawberries'),
      ('grapes', 'Grapes'),
      ('mango', 'Mango'),
      ('pineapple', 'Pineapple'),
      ('avocado', 'Avocado'),
    ])
      _produce(
        entry.$1,
        entry.$2,
        'Fruits',
        aliases: entry.$1 == 'berries'
            ? ['mixed berries', 'berries']
            : const [],
      ),
    _food(
      'lentils',
      'Lentils',
      'Legumes',
      protein: 9,
      calories: 116,
      carbs: 20,
      fat: .4,
      aliases: ['cooked lentils', 'lentils'],
    ),
    _food(
      'chickpeas',
      'Chickpeas',
      'Legumes',
      protein: 8.9,
      calories: 164,
      carbs: 27,
      fat: 2.6,
      aliases: ['cooked chickpeas', 'chickpeas'],
    ),
    _food(
      'black_beans',
      'Black Beans',
      'Legumes',
      protein: 8.9,
      calories: 132,
      carbs: 24,
      fat: .5,
    ),
    _food(
      'kidney_beans',
      'Kidney Beans',
      'Legumes',
      protein: 8.7,
      calories: 127,
      carbs: 23,
      fat: .5,
    ),
    _food(
      'edamame',
      'Edamame',
      'Legumes',
      protein: 12,
      calories: 121,
      carbs: 9,
      fat: 5,
      allergens: {'soy'},
    ),
    _fat('olive_oil', 'Olive Oil', 100, 884, aliases: ['olive oil']),
    _fat('peanut_butter', 'Peanut Butter', 50, 588, allergens: {'peanuts'}),
    _fat('almond_butter', 'Almond Butter', 56, 614, allergens: {'tree nuts'}),
    _fat('almonds', 'Almonds', 50, 579, allergens: {'tree nuts'}),
    _fat('walnuts', 'Walnuts', 65, 654, allergens: {'tree nuts'}),
    _fat('cashews', 'Cashews', 44, 553, allergens: {'tree nuts'}),
    _fat('chia_seeds', 'Chia Seeds', 31, 486),
    _fat('flax_seeds', 'Flax Seeds', 42, 534),
    for (final entry in const [
      ('salt', 'Salt'),
      ('black_pepper', 'Black Pepper'),
      ('garlic', 'Garlic'),
      ('lemon', 'Lemon'),
      ('tomato_sauce', 'Tomato Sauce'),
      ('mustard', 'Mustard'),
      ('honey', 'Honey'),
      ('hot_sauce', 'Hot Sauce'),
    ])
      _pantry(entry.$1, entry.$2),
    _pantry(
      'soy_sauce',
      'Soy Sauce',
      allergens: {'soy'},
      aliases: ['reduced-sodium soy sauce', 'soy sauce'],
    ),
  ];

  static const _allDiets = {'omnivore', 'vegetarian', 'vegan', 'pescatarian'};
  static const _vegetarian = {'omnivore', 'vegetarian', 'pescatarian'};
  static const _seafood = {'omnivore', 'pescatarian'};
  static const _meat = {'omnivore'};

  static FridgeFoodReference _food(
    String key,
    String name,
    String category, {
    double calories = 0,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    String macro = 'protein',
    Set<String> diets = _allDiets,
    Set<String> allergens = const {},
    List<String> aliases = const [],
  }) => FridgeFoodReference(
    key: key,
    name: name,
    category: category,
    caloriesPer100G: calories,
    proteinPer100G: protein,
    carbsPer100G: carbs,
    fatPer100G: fat,
    macroFocus: macro,
    supportedDiets: diets,
    allergens: allergens,
    aliases: aliases,
  );
  static FridgeFoodReference _carb(
    String key,
    String name,
    double carbs,
    double calories, {
    Set<String> allergens = const {},
    List<String> aliases = const [],
  }) => _food(
    key,
    name,
    'Carbs & Grains',
    carbs: carbs,
    calories: calories,
    macro: 'carbs',
    allergens: allergens,
    aliases: aliases,
  );
  static FridgeFoodReference _produce(
    String key,
    String name,
    String category, {
    List<String> aliases = const [],
  }) => _food(key, name, category, macro: 'produce', aliases: aliases);
  static FridgeFoodReference _fat(
    String key,
    String name,
    double fat,
    double calories, {
    Set<String> allergens = const {},
    List<String> aliases = const [],
  }) => _food(
    key,
    name,
    'Fats & Nuts',
    fat: fat,
    calories: calories,
    macro: 'fat',
    allergens: allergens,
    aliases: aliases,
  );
  static FridgeFoodReference _pantry(
    String key,
    String name, {
    Set<String> allergens = const {},
    List<String> aliases = const [],
  }) => _food(
    key,
    name,
    'Pantry / Condiments',
    macro: 'pantry',
    allergens: allergens,
    aliases: aliases,
  );

  static List<FridgeFoodReference> allowedFor(NutritionProfile profile) =>
      foods.where((food) => _foodAllowed(food, profile)).toList();
}

abstract interface class FridgeInventoryRepository {
  Future<List<FridgeItem>> load();
  Future<Set<String>> loadPreferredFoodKeys();
  Future<void> saveItem(FridgeItem item);
  Future<void> removeItem(String ingredientKey);
  Future<void> savePreferredFoodKeys(Set<String> keys);
}

class SupabaseFridgeInventoryRepository implements FridgeInventoryRepository {
  final SupabaseClient _supabase;

  SupabaseFridgeInventoryRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  User get _user =>
      _supabase.auth.currentUser ??
      (throw StateError('Sign in to use Intelligent Fridge.'));

  @override
  Future<List<FridgeItem>> load() async =>
      (await _supabase
              .from('user_fridge_items')
              .select()
              .eq('user_id', _user.id)
              .order('category')
              .order('ingredient_name'))
          .map((row) => FridgeItem.fromMap(Map<String, dynamic>.from(row)))
          .toList();

  @override
  Future<Set<String>> loadPreferredFoodKeys() async =>
      (await _supabase
              .from('user_food_source_preferences')
              .select('ingredient_key')
              .eq('user_id', _user.id))
          .map((row) => row['ingredient_key'].toString())
          .toSet();

  @override
  Future<void> saveItem(FridgeItem item) async {
    if (item.quantity != null &&
        (item.quantity! < 0 || item.quantity! > 100000)) {
      throw const FormatException(
        'Enter a practical quantity between 0 and 100,000 g.',
      );
    }
    await _supabase.from('user_fridge_items').upsert({
      'user_id': _user.id,
      'ingredient_key': item.ingredientKey,
      'ingredient_name': item.ingredientName,
      'category': item.category,
      'quantity': item.quantity,
      'quantity_unit': item.quantityUnit,
      'is_available': item.isAvailable,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,ingredient_key');
  }

  @override
  Future<void> removeItem(String ingredientKey) => _supabase
      .from('user_fridge_items')
      .delete()
      .eq('user_id', _user.id)
      .eq('ingredient_key', ingredientKey);

  @override
  Future<void> savePreferredFoodKeys(Set<String> keys) async {
    await _supabase
        .from('user_food_source_preferences')
        .delete()
        .eq('user_id', _user.id);
    if (keys.isNotEmpty) {
      await _supabase
          .from('user_food_source_preferences')
          .insert(
            keys
                .map((key) => {'user_id': _user.id, 'ingredient_key': key})
                .toList(),
          );
    }
  }
}

class WeeklyFoodRequirementCalculator {
  const WeeklyFoodRequirementCalculator();

  List<WeeklyFoodRequirement> calculate({
    required PerformanceFuel fuel,
    required NutritionProfile profile,
    required int trainingDays,
    required List<FridgeItem> inventory,
    required Set<String> preferredFoodKeys,
  }) {
    final allowed = FridgeFoodCatalog.allowedFor(profile);
    var proteins = allowed
        .where(
          (food) =>
              food.macroFocus == 'protein' &&
              preferredFoodKeys.contains(food.key),
        )
        .toList();
    if (proteins.isEmpty) {
      proteins = allowed
          .where((food) => food.macroFocus == 'protein')
          .take(4)
          .toList();
    }
    final result = <WeeklyFoodRequirement>[];
    void distribute(
      List<FridgeFoodReference> foods,
      double macroGrams,
      double Function(FridgeFoodReference) density,
    ) {
      if (foods.isEmpty) return;
      final share = macroGrams / foods.length;
      for (final food in foods) {
        final per100 = density(food);
        if (per100 <= 0) continue;
        final suggested = share / per100 * 100;
        result.add(
          WeeklyFoodRequirement(
            food: food,
            suggestedGrams: suggested,
            inFridgeGrams: _inventoryGrams(food.key, inventory),
          ),
        );
      }
    }

    distribute(
      proteins,
      fuel.proteinG * 7 * .70,
      (food) => food.proteinPer100G,
    );
    distribute(
      allowed
          .where((food) => food.macroFocus == 'carbs')
          .take(trainingDays > 0 ? 2 : 1)
          .toList(),
      fuel.carbsG * 7 * (trainingDays > 0 ? .65 : .50),
      (food) => food.carbsPer100G,
    );
    distribute(
      allowed.where((food) => food.macroFocus == 'fat').take(1).toList(),
      fuel.fatG * 7 * .45,
      (food) => food.fatPer100G,
    );
    for (final food
        in allowed.where((food) => food.macroFocus == 'produce').take(2)) {
      result.add(
        WeeklyFoodRequirement(
          food: food,
          suggestedGrams: 700 + trainingDays.clamp(0, 7) * 25,
          inFridgeGrams: _inventoryGrams(food.key, inventory),
        ),
      );
    }
    return result;
  }

  double _inventoryGrams(String key, List<FridgeItem> inventory) {
    final item = inventory
        .where((item) => item.ingredientKey == key && item.isAvailable)
        .firstOrNull;
    if (item?.quantity == null) return 0;
    return item!.quantityUnit == 'kg' ? item.quantity! * 1000 : item.quantity!;
  }
}

class GroceryListBuilder {
  const GroceryListBuilder();

  List<WeeklyFoodRequirement> build(
    List<WeeklyFoodRequirement> recommendations,
  ) => recommendations
      .where((item) => item.purchaseGrams >= 1)
      .toList(growable: false);
}

class RecipeFridgeMatcher {
  const RecipeFridgeMatcher();

  List<FridgeRecipeMatch> match(
    List<RankedCookForGoalRecipe> ranked,
    List<FridgeItem> inventory,
  ) {
    final available = inventory
        .where((item) => item.isAvailable)
        .map((item) => item.ingredientKey)
        .toSet();
    final indexed = ranked.indexed.map((entry) {
      final missing = entry.$2.recipe.ingredients
          .where((ingredient) => !_hasIngredient(ingredient.name, available))
          .toList();
      return (
        index: entry.$1,
        match: FridgeRecipeMatch(
          rankedRecipe: entry.$2,
          missingIngredients: missing,
          availableCount: entry.$2.recipe.ingredients.length - missing.length,
        ),
      );
    }).toList();
    indexed.sort((a, b) {
      final nutritionDifference =
          b.match.rankedRecipe.score - a.match.rankedRecipe.score;
      if (nutritionDifference.abs() >= .5) {
        return nutritionDifference > 0 ? 1 : -1;
      }
      final missing = a.match.missingIngredients.length.compareTo(
        b.match.missingIngredients.length,
      );
      return missing != 0 ? missing : a.index.compareTo(b.index);
    });
    return indexed.map((item) => item.match).toList();
  }

  bool _hasIngredient(String name, Set<String> available) {
    final normalized = _normalize(name);
    return FridgeFoodCatalog.foods.any(
      (food) =>
          available.contains(food.key) &&
          (food.aliases.any(
                (alias) => normalized.contains(_normalize(alias)),
              ) ||
              normalized.contains(_normalize(food.name))),
    );
  }
}

class CommercePartnerService {
  final SupabaseClient? supabase;
  final List<CommercePartner> partners;
  const CommercePartnerService({this.supabase, this.partners = const []});

  CommercePartner? activeForCountry(String country) => partners
      .where(
        (partner) =>
            partner.active &&
            partner.country.toLowerCase() == country.toLowerCase(),
      )
      .firstOrNull;

  PurchaseQuantityMatch matchPackage({
    required double neededGrams,
    required double packageGrams,
  }) {
    if (neededGrams < 0 || packageGrams <= 0) {
      throw const FormatException('Package quantities must be positive.');
    }
    final count = (neededGrams / packageGrams).ceil();
    return PurchaseQuantityMatch(
      packageCount: count,
      packageGrams: packageGrams,
      remainingGrams: math.max(0, count * packageGrams - neededGrams),
    );
  }

  Uri outboundUri(CommercePartner partner, String ingredientKey) =>
      partner.destinationUrl.replace(
        queryParameters: {
          ...partner.destinationUrl.queryParameters,
          'ingredient': ingredientKey,
        },
      );

  Future<void> recordEvent({
    required String partnerId,
    required String eventType,
    String? recipeId,
    String? ingredientKey,
  }) async {
    if (eventType != 'partner_impression' && eventType != 'outbound_click') {
      throw const FormatException('Unsupported commerce event.');
    }
    final client = supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    await client.from('commerce_events').insert({
      'user_id': user.id,
      'partner_id': partnerId,
      'event_type': eventType,
      'source': 'intelligent_fridge',
      'recipe_id': recipeId,
      'ingredient_key': ingredientKey,
    });
  }
}

class IntelligentFridgeService {
  final FridgeInventoryRepository repository;
  final WeeklyFoodRequirementCalculator calculator;
  final RecipeFridgeMatcher recipeMatcher;
  final GroceryListBuilder groceryListBuilder;
  const IntelligentFridgeService({
    required this.repository,
    this.calculator = const WeeklyFoodRequirementCalculator(),
    this.recipeMatcher = const RecipeFridgeMatcher(),
    this.groceryListBuilder = const GroceryListBuilder(),
  });

  Future<IntelligentFridgeState> load({
    required PerformanceFuel fuel,
    required NutritionProfile profile,
    required int trainingDays,
    required List<RankedCookForGoalRecipe> recipes,
  }) async {
    final inventory = await repository.load();
    final preferences = await repository.loadPreferredFoodKeys();
    final recommendations = calculator.calculate(
      fuel: fuel,
      profile: profile,
      trainingDays: trainingDays,
      inventory: inventory,
      preferredFoodKeys: preferences,
    );
    return IntelligentFridgeState(
      inventory: inventory,
      preferredFoodKeys: preferences,
      recommendations: recommendations,
      recipeMatches: recipeMatcher.match(recipes, inventory),
      groceryList: groceryListBuilder.build(recommendations),
    );
  }
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

bool _foodAllowed(FridgeFoodReference food, NutritionProfile profile) {
  final diet = _normalize(profile.dietType);
  if (diet.isNotEmpty && !food.supportedDiets.contains(diet)) return false;
  final exclusions = {
    ...profile.foodAllergies,
    ...profile.foodsToAvoid,
    ...profile.dislikedFoods,
  }.map(_normalize).where((value) => value != 'none' && value.isNotEmpty);
  return !exclusions.any(
    (excluded) =>
        food.allergens.contains(excluded) ||
        _normalize(food.name).contains(excluded),
  );
}
