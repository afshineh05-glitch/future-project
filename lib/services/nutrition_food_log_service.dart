import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/models/meal_analysis_result.dart';
import 'package:future_project/models/nutrition_food_log.dart';

class NutritionFoodLogService {
  final SupabaseClient _supabase;

  NutritionFoodLogService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<void> addConfirmedMeal({
    required MealAnalysisResult result,
    required String analysisReference,
    DateTime? consumedAt,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const NutritionFoodLogException('Please sign in to log food.');
    }

    try {
      await _supabase.from('nutrition_food_logs').upsert({
        'user_id': user.id,
        'consumed_at': (consumedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'food_name': result.mealName,
        'calories': result.calories,
        'protein_g': result.protein,
        'carbs_g': result.carbs,
        'fat_g': result.fat,
        'fiber_g': null,
        'source': 'calorie_magnifier',
        'analysis_reference': analysisReference,
      }, onConflict: 'user_id,analysis_reference');
    } catch (error) {
      throw NutritionFoodLogException('Could not add this meal: $error');
    }
  }

  Future<NutritionFoodDay> loadToday() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const NutritionFoodLogException(
        'Please sign in to load food logs.',
      );
    }

    final now = DateTime.now();
    final localStart = DateTime(now.year, now.month, now.day);
    final localEnd = localStart.add(const Duration(days: 1));

    try {
      final rows = await _supabase
          .from('nutrition_food_logs')
          .select()
          .eq('user_id', user.id)
          .gte('consumed_at', localStart.toUtc().toIso8601String())
          .lt('consumed_at', localEnd.toUtc().toIso8601String())
          .order('consumed_at');
      final entries = rows
          .map((row) => NutritionFoodLogEntry.fromMap(row))
          .toList(growable: false);
      return NutritionFoodDay.fromEntries(entries);
    } catch (error) {
      throw NutritionFoodLogException(
        'Could not load today\'s food log: $error',
      );
    }
  }
}

class NutritionFoodLogException implements Exception {
  final String message;

  const NutritionFoodLogException(this.message);

  @override
  String toString() => message;
}
