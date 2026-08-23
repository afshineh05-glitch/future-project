enum RecoveryWorkoutSource { trainingPlan, differentWorkout, restDay }

enum RecoveryWorkoutIntensity { veryLight, light, moderate, hard, veryHard }

class RecoveryWorkout {
  final String name;
  final String type;
  final int durationMinutes;
  final RecoveryWorkoutIntensity intensity;
  final int? exerciseCount;
  final bool isScheduledWorkout;

  const RecoveryWorkout({
    required this.name,
    required this.type,
    required this.durationMinutes,
    required this.intensity,
    required this.exerciseCount,
    required this.isScheduledWorkout,
  });
}

class RecoveryNutritionContext {
  final double weightKg;
  final String primaryGoal;
  final String trainingLevel;
  final int trainingDaysPerWeek;
  final bool regularStrengthTraining;
  final double? performanceFuelHydrationL;
  final int? performanceFuelProteinG;
  final int? performanceFuelCarbsG;
  final RecoveryWorkout? trainingPlanWorkout;
  final RecoveryWorkoutSource savedSource;
  final RecoveryWorkout? savedDifferentWorkout;

  const RecoveryNutritionContext({
    required this.weightKg,
    required this.primaryGoal,
    required this.trainingLevel,
    required this.trainingDaysPerWeek,
    required this.regularStrengthTraining,
    required this.performanceFuelHydrationL,
    required this.performanceFuelProteinG,
    required this.performanceFuelCarbsG,
    required this.trainingPlanWorkout,
    required this.savedSource,
    required this.savedDifferentWorkout,
  });
}

class RecoveryNutritionRecommendation {
  final RecoveryWorkoutSource source;
  final RecoveryWorkout? workout;
  final int? estimatedCaloriesBurned;
  final int? proteinG;
  final int? carbsG;
  final int? hydrationMl;
  final double? dailyHydrationL;
  final bool timingCoverageAvailable;

  const RecoveryNutritionRecommendation({
    required this.source,
    required this.workout,
    required this.estimatedCaloriesBurned,
    required this.proteinG,
    required this.carbsG,
    required this.hydrationMl,
    required this.dailyHydrationL,
    this.timingCoverageAvailable = false,
  });

  bool get isRestDay => source == RecoveryWorkoutSource.restDay;
}
