import 'dart:convert';
import 'dart:typed_data';

import 'package:future_project/debug/ingredient_image_refresh_key.dart';
import 'package:future_project/models/food_visual.dart';
import 'package:future_project/services/food_visual_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IngredientImageService {
  final SupabaseClient _supabase;
  final FoodVisualService _visuals;

  IngredientImageService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client,
      _visuals = FoodVisualService(supabase: supabase);

  Future<FoodVisual> resolve({
    required String ingredientKey,
    required String displayName,
  }) => _visuals.resolveIngredientImage(
    ingredientKey: ingredientKey,
    displayName: displayName,
  );

  Future<void> invalidate(String ingredientKey) =>
      _visuals.invalidateIngredientImage(ingredientKey);

  Future<String> uploadManualCuratedImage({
    required String ingredientKey,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (_supabase.auth.currentSession == null) {
      throw StateError('A signed-in Supabase session is required.');
    }
    if (!IngredientImageRefreshKey.hasRefreshKey) {
      throw StateError('INGREDIENT_IMAGE_REFRESH_KEY was not supplied.');
    }
    final response = await _supabase.functions.invoke(
      'resolve-food-image',
      headers: {'x-image-refresh-key': IngredientImageRefreshKey.refreshKey},
      body: {
        'action': 'manual-upload',
        'ingredientKey': ingredientKey,
        'contentType': contentType,
        'imageBase64': base64Encode(bytes),
      },
    );
    final data = response.data;
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    if (map['ingredientKey']?.toString() != ingredientKey) {
      throw const FormatException('Manual upload ingredient mismatch.');
    }
    final imageUrl = map['imageUrl']?.toString().trim();
    if (imageUrl?.isNotEmpty != true) {
      throw const FormatException('Manual upload response was invalid.');
    }
    return imageUrl!;
  }
}
