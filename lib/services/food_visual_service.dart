import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/models/food_visual.dart';

class FoodVisualService {
  static final Map<String, FoodVisual> _resolvedVisuals = {};
  static final Map<String, Future<FoodVisual>> _pendingResolutions = {};

  final SupabaseClient _supabase;

  FoodVisualService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<FoodVisual> resolveFoodImage(String foodName) async {
    final displayName = foodName.trim();
    if (displayName.isEmpty) {
      return FoodVisual.unavailable(
        displayName: displayName,
        errorCode: 'invalid_food_name',
        message: 'A food name is required.',
      );
    }

    final requestKey = displayName.toLowerCase();
    final resolved = _resolvedVisuals[requestKey];
    if (resolved != null) return resolved;

    final pending = _pendingResolutions[requestKey];
    if (pending != null) return pending;

    final resolution = _resolveFoodImage(displayName);
    _pendingResolutions[requestKey] = resolution;
    final visual = await resolution;
    _pendingResolutions.remove(requestKey);
    if (visual.isReady) {
      _resolvedVisuals[requestKey] = visual;
    }
    return visual;
  }

  Future<FoodVisual> _resolveFoodImage(String displayName) async {
    if (_supabase.auth.currentUser == null) {
      return FoodVisual.unavailable(
        displayName: displayName,
        errorCode: 'unauthorized',
        message: 'Please sign in to load ingredient imagery.',
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'resolve-food-image',
        body: <String, dynamic>{'food_name': displayName},
      );
      final data = response.data;
      if (data is Map) {
        return FoodVisual.fromMap(Map<String, dynamic>.from(data));
      }
      return FoodVisual.unavailable(
        displayName: displayName,
        errorCode: 'invalid_response',
        message: 'Ingredient imagery returned an invalid response.',
      );
    } on FunctionException catch (error) {
      debugPrint(
        'resolve-food-image FunctionException: '
        'status=${error.status}, reasonPhrase=${error.reasonPhrase}, '
        'details=${error.details}',
      );
      final details = error.details;
      if (details is Map) {
        return FoodVisual.fromMap(Map<String, dynamic>.from(details));
      }
      return FoodVisual.unavailable(
        displayName: displayName,
        errorCode: 'function_error',
        message: 'Ingredient imagery is temporarily unavailable.',
      );
    } catch (error, stackTrace) {
      debugPrint('resolve-food-image error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return FoodVisual.unavailable(
        displayName: displayName,
        errorCode: 'unavailable',
        message: 'Ingredient imagery is temporarily unavailable.',
      );
    }
  }
}
