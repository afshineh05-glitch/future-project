import 'package:future_project/models/grocery_deals.dart';
import 'package:future_project/services/intelligent_fridge_service.dart';

class FoodSearchCatalog {
  FoodSearchCatalog._();

  static const Map<String, List<String>> _approvedTerms = {
    'chicken_breast': ['chicken breast'],
    'chicken_thigh': ['chicken thigh', 'chicken thighs'],
    'turkey': ['turkey', 'turkey breast'],
    'lean_beef': ['lean beef'],
    'ground_beef': ['lean ground beef', 'ground beef'],
    'steak': ['steak'],
    'salmon': ['salmon', 'salmon fillet'],
    'tuna': ['tuna'],
    'shrimp': ['shrimp'],
    'eggs': ['eggs'],
    'egg_whites': ['egg whites'],
    'greek_yogurt': ['greek yogurt'],
    'cottage_cheese': ['cottage cheese'],
    'tofu': ['tofu'],
    'white_rice': ['rice', 'white rice'],
    'brown_rice': ['rice', 'brown rice'],
    'basmati_rice': ['rice', 'basmati rice'],
    'oats': ['oats', 'rolled oats'],
    'pasta': ['pasta'],
    'potatoes': ['potatoes', 'potato'],
    'sweet_potatoes': ['sweet potatoes', 'sweet potato'],
    'bread': ['bread'],
    'tortilla': ['tortillas', 'tortilla'],
    'milk': ['milk'],
    'skim_milk': ['skim milk'],
    'cheese': ['cheese'],
    'lentils': ['lentils'],
    'chickpeas': ['chickpeas'],
    'black_beans': ['beans', 'black beans'],
    'kidney_beans': ['beans', 'kidney beans'],
    'peanut_butter': ['peanut butter'],
    'olive_oil': ['olive oil'],
  };

  static final List<FoodSearchItem> items = FridgeFoodCatalog.foods
      .where((food) => _approvedTerms.containsKey(food.key))
      .map(
        (food) => FoodSearchItem(
          foodId: food.key,
          canonicalName: food.name,
          allowedSearchTerms: List.unmodifiable(_approvedTerms[food.key]!),
          category: food.category,
          searchEnabled: true,
          unitType:
              food.key == 'milk' ||
                  food.key == 'skim_milk' ||
                  food.key == 'olive_oil'
              ? FoodUnitType.volume
              : FoodUnitType.mass,
        ),
      )
      .toList(growable: false);

  static FoodSearchItem? byFoodId(String foodId) => items
      .where((item) => item.foodId == foodId && item.searchEnabled)
      .firstOrNull;

  static FoodSearchItem? resolveApprovedTerm(String value) {
    final normalized = normalize(value);
    return items
        .where(
          (item) => item.allowedSearchTerms.any(
            (term) => normalize(term) == normalized,
          ),
        )
        .firstOrNull;
  }

  static bool productMatches(FoodSearchItem food, String productName) {
    final product = ' ${normalize(productName)} ';
    return food.allowedSearchTerms.any(
      (term) => product.contains(' ${normalize(term)} '),
    );
  }

  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
