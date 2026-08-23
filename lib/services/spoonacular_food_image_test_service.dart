import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpoonacularFoodImageTestResult {
  final String requestedFoodName;
  final int? ingredientId;
  final String? matchedIngredientName;
  final String? imageUrl;
  final Map<String, dynamic> matchMetadata;
  final String? error;

  const SpoonacularFoodImageTestResult({
    required this.requestedFoodName,
    required this.ingredientId,
    required this.matchedIngredientName,
    required this.imageUrl,
    required this.matchMetadata,
    required this.error,
  });

  bool get hasImage => imageUrl?.trim().isNotEmpty == true;

  factory SpoonacularFoodImageTestResult.fromMap(Map<String, dynamic> map) {
    final metadata = map['match_metadata'];
    return SpoonacularFoodImageTestResult(
      requestedFoodName: map['requested_food_name']?.toString() ?? '',
      ingredientId: (map['ingredient_id'] as num?)?.toInt(),
      matchedIngredientName: map['matched_ingredient_name']?.toString(),
      imageUrl: map['image_url']?.toString(),
      matchMetadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : const {},
      error: map['error']?.toString(),
    );
  }
}

class SpoonacularFoodImageTestException implements Exception {
  final String message;

  const SpoonacularFoodImageTestException(this.message);

  @override
  String toString() => message;
}

class SpoonacularFoodImageTestService {
  final SupabaseClient _supabase;

  SpoonacularFoodImageTestService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<List<SpoonacularFoodImageTestResult>> loadTestImages() async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('An authenticated session is required.');
    }

    try {
      final response = await _supabase.functions.invoke(
        'test-spoonacular-food-images',
        body: const <String, dynamic>{},
      );
      final data = response.data;
      if (data is! Map || data['results'] is! List) {
        throw const FormatException('Invalid Spoonacular test response.');
      }
      return (data['results'] as List)
          .whereType<Map>()
          .map(
            (result) => SpoonacularFoodImageTestResult.fromMap(
              Map<String, dynamic>.from(result),
            ),
          )
          .toList(growable: false);
    } on FunctionException catch (error, stackTrace) {
      final completeError =
          'FunctionException(status: ${error.status}, '
          'reasonPhrase: ${error.reasonPhrase}, details: ${error.details})';
      if (kDebugMode) {
        debugPrint(
          'test-spoonacular-food-images complete error: $completeError',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      throw SpoonacularFoodImageTestException(completeError);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('test-spoonacular-food-images error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }
}
