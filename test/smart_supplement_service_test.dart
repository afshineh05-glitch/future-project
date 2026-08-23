import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/nutrition_food_log.dart';
import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/models/performance_fuel.dart';
import 'package:future_project/models/recovery_nutrition.dart';
import 'package:future_project/models/smart_supplement.dart';
import 'package:future_project/services/smart_supplement_service.dart';

void main() {
  test('stable resistance context recommends creatine on a rest day', () {
    final recommendations = const SmartSupplementService().recommend(
      profile: const NutritionProfile(
        userId: 'test',
        dietType: 'omnivore',
        foodAllergies: [],
        foodsToAvoid: [],
        dislikedFoods: [],
        mealsPerDay: '4',
        maximumCookingTime: '30',
        cookingSkill: 'intermediate',
        foodBudget: 'medium',
      ),
      fuel: const PerformanceFuel(
        goal: 'athletic_performance',
        calories: PerformanceFuelCalories(
          target: 2800,
          rangeMin: 2700,
          rangeMax: 2900,
        ),
        proteinG: 160,
        carbsG: 350,
        fatG: 80,
        fiberG: 35,
        hydrationL: 3.2,
        micronutrientFocus: [],
        why: '',
        calculationVersion: 'test',
        generatedAt: null,
        cached: false,
      ),
      consumedToday: const NutritionFoodDay(
        entries: [],
        totals: NutritionFoodTotals(),
      ),
      recoveryContext: const RecoveryNutritionContext(
        weightKg: 79,
        primaryGoal: 'athletic_performance',
        trainingLevel: 'advanced',
        trainingDaysPerWeek: 4,
        regularStrengthTraining: true,
        performanceFuelHydrationL: 3.2,
        performanceFuelProteinG: 160,
        performanceFuelCarbsG: 350,
        trainingPlanWorkout: null,
        savedSource: RecoveryWorkoutSource.restDay,
        savedDifferentWorkout: null,
      ),
      recoverySource: RecoveryWorkoutSource.restDay,
      selectedWorkout: null,
    );

    final creatine = recommendations.first;
    expect(creatine.id, 'creatine_monohydrate');
    expect(creatine.status, SupplementGuidanceStatus.recommended);
    expect(creatine.relevanceScore, 3.5);
    expect(creatine.reasons, [
      SupplementRelevanceReason.strengthTraining,
      SupplementRelevanceReason.highTrainingVolume,
      SupplementRelevanceReason.performanceGoal,
      SupplementRelevanceReason.experiencedTraining,
    ]);
  });
}
