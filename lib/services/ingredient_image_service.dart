import 'package:future_project/models/food_visual.dart';
import 'package:future_project/services/food_visual_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IngredientImageService {
  final FoodVisualService _visuals;

  IngredientImageService({SupabaseClient? supabase})
    : _visuals = FoodVisualService(supabase: supabase);

  Future<FoodVisual> resolve({
    required String ingredientKey,
    required String displayName,
  }) => _visuals.resolveIngredientImage(
    ingredientKey: ingredientKey,
    displayName: displayName,
  );
}
