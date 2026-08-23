import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/models/performance_fuel.dart';
import 'package:future_project/models/meal_builder_result.dart';

class NutritionEngineService {
  final SupabaseClient _supabase;

  NutritionEngineService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<PerformanceFuel> loadPerformanceFuel() async {
    if (_supabase.auth.currentUser == null) {
      throw const NutritionEngineException(
        'Please sign in to load Performance Fuel.',
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'nutrition-engine',
        body: const <String, dynamic>{'mode': 'performance_fuel'},
      );
      final data = response.data;
      if (data is! Map) {
        throw const NutritionEngineException(
          'Nutrition Engine returned an invalid response.',
        );
      }
      return PerformanceFuel.fromMap(Map<String, dynamic>.from(data));
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map
          ? details['error']?.toString()
          : details?.toString();
      throw NutritionEngineException(
        message?.trim().isNotEmpty == true
            ? message!
            : 'Performance Fuel is temporarily unavailable.',
      );
    } on NutritionEngineException {
      rethrow;
    } catch (error) {
      throw NutritionEngineException(
        'Performance Fuel is temporarily unavailable: $error',
      );
    }
  }

  Future<MealBuilderResult> buildMeal() async {
    if (_supabase.auth.currentUser == null) {
      throw const NutritionEngineException('Please sign in to build a meal.');
    }

    try {
      final response = await _supabase.functions.invoke(
        'nutrition-engine',
        body: <String, dynamic>{
          'mode': 'meal_builder',
          'timezone_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const NutritionEngineException(
          'Nutrition Engine returned an invalid Meal Builder response.',
        );
      }
      return MealBuilderResult.fromMap(Map<String, dynamic>.from(data));
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map
          ? details['error']?.toString()
          : details?.toString();
      throw NutritionEngineException(
        message?.trim().isNotEmpty == true
            ? message!
            : 'Meal Builder is temporarily unavailable.',
      );
    } on NutritionEngineException {
      rethrow;
    } catch (error) {
      throw NutritionEngineException(
        'Meal Builder is temporarily unavailable: $error',
      );
    }
  }
}

class NutritionEngineException implements Exception {
  final String message;

  const NutritionEngineException(this.message);

  @override
  String toString() => message;
}
