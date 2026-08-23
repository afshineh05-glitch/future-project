import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/models/performance_fuel.dart';
import 'package:future_project/models/recovery_nutrition.dart';

class RecoveryNutritionEngine {
  const RecoveryNutritionEngine();

  RecoveryNutritionRecommendation calculate({
    required RecoveryNutritionContext context,
    required RecoveryWorkoutSource source,
    RecoveryWorkout? differentWorkout,
  }) {
    if (source == RecoveryWorkoutSource.restDay) {
      return RecoveryNutritionRecommendation(
        source: source,
        workout: null,
        estimatedCaloriesBurned: null,
        proteinG: null,
        carbsG: null,
        hydrationMl: null,
        dailyHydrationL: context.performanceFuelHydrationL,
      );
    }

    final workout = source == RecoveryWorkoutSource.trainingPlan
        ? context.trainingPlanWorkout
        : differentWorkout;
    if (workout == null) {
      return RecoveryNutritionRecommendation(
        source: source,
        workout: null,
        estimatedCaloriesBurned: null,
        proteinG: null,
        carbsG: null,
        hydrationMl: null,
        dailyHydrationL: context.performanceFuelHydrationL,
      );
    }

    final intensityIndex = workout.intensity.index;
    final proteinPerKg = switch (workout.intensity) {
      RecoveryWorkoutIntensity.veryLight => 0.20,
      RecoveryWorkoutIntensity.light => 0.22,
      RecoveryWorkoutIntensity.moderate => 0.25,
      RecoveryWorkoutIntensity.hard => 0.30,
      RecoveryWorkoutIntensity.veryHard => 0.30,
    };
    var protein = context.weightKg * proteinPerKg;
    if (_isStrength(workout.type) || _isMuscleGoal(context.primaryGoal)) {
      protein = math.max(protein, context.weightKg * 0.25);
    }
    protein = protein.clamp(15, 45);
    if (context.performanceFuelProteinG != null) {
      protein = math.min(protein, context.performanceFuelProteinG! * 0.35);
    }

    const carbsPerKg = <double>[0.20, 0.30, 0.50, 0.70, 0.90];
    final durationFactor = switch (workout.durationMinutes) {
      <= 30 => 0.60,
      <= 60 => 1.00,
      <= 90 => 1.25,
      _ => 1.50,
    };
    var typeFactor = 1.0;
    if (_isStrength(workout.type)) typeFactor = 0.85;
    if (_isEndurance(workout.type)) typeFactor = 1.15;
    final goalFactor = _isFatLossGoal(context.primaryGoal) ? 0.85 : 1.0;
    var carbs =
        context.weightKg *
        carbsPerKg[intensityIndex] *
        durationFactor *
        typeFactor *
        goalFactor;
    carbs = carbs.clamp(10, context.weightKg * 1.2);
    if (context.performanceFuelCarbsG != null) {
      carbs = math.min(carbs, context.performanceFuelCarbsG! * 0.40);
    }

    final intensityHydrationFactor = switch (workout.intensity) {
      RecoveryWorkoutIntensity.veryLight => 0.85,
      RecoveryWorkoutIntensity.light => 0.95,
      RecoveryWorkoutIntensity.moderate => 1.0,
      RecoveryWorkoutIntensity.hard => 1.15,
      RecoveryWorkoutIntensity.veryHard => 1.25,
    };
    var hydration =
        (context.weightKg * 5 + workout.durationMinutes * 3) *
        intensityHydrationFactor;
    hydration = hydration.clamp(300, 1500);
    if (context.performanceFuelHydrationL != null) {
      hydration = math.min(
        hydration,
        context.performanceFuelHydrationL! * 1000 * 0.40,
      );
    }

    final met = _metFor(workout.type, workout.intensity);
    final calories =
        met * 3.5 * context.weightKg / 200 * workout.durationMinutes;

    return RecoveryNutritionRecommendation(
      source: source,
      workout: workout,
      estimatedCaloriesBurned: calories.round(),
      proteinG: protein.round(),
      carbsG: carbs.round(),
      hydrationMl: (hydration / 50).round() * 50,
      dailyHydrationL: context.performanceFuelHydrationL,
    );
  }

  double _metFor(String type, RecoveryWorkoutIntensity intensity) {
    final base = switch (intensity) {
      RecoveryWorkoutIntensity.veryLight => 2.5,
      RecoveryWorkoutIntensity.light => 3.5,
      RecoveryWorkoutIntensity.moderate => 5.0,
      RecoveryWorkoutIntensity.hard => 6.5,
      RecoveryWorkoutIntensity.veryHard => 8.0,
    };
    if (_isStrength(type)) return math.min(base, 6.0);
    if (_isEndurance(type)) return base + 0.5;
    if (type.toLowerCase().contains('mobility')) return math.min(base, 3.0);
    return base;
  }

  bool _isStrength(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('strength') ||
        normalized.contains('resistance') ||
        normalized.contains('weight') ||
        normalized.contains('muscle');
  }

  bool _isEndurance(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('cardio') ||
        normalized.contains('endurance') ||
        normalized.contains('running') ||
        normalized.contains('cycling') ||
        normalized.contains('hiit') ||
        normalized.contains('sport');
  }

  bool _isMuscleGoal(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('muscle') || normalized.contains('strength');
  }

  bool _isFatLossGoal(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('fat') || normalized.contains('lose');
  }
}

class RecoveryNutritionService {
  final SupabaseClient _supabase;

  RecoveryNutritionService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<RecoveryNutritionContext> loadContext({PerformanceFuel? fuel}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const RecoveryNutritionException(
        'Please sign in to load recovery nutrition.',
      );
    }

    try {
      final foundation = await _supabase
          .from('user_foundations')
          .select(
            'weight_kg, primary_goal, training_level, training_days_per_week, '
            'session_duration_minutes, lifestyle',
          )
          .eq('user_id', user.id)
          .maybeSingle();
      if (foundation == null) {
        throw const RecoveryNutritionException(
          'Complete My Foundation to calculate recovery nutrition.',
        );
      }

      final weightKg = (foundation['weight_kg'] as num?)?.toDouble();
      if (weightKg == null || weightKg <= 0) {
        throw const RecoveryNutritionException(
          'Add your body weight in My Foundation for recovery guidance.',
        );
      }

      final lifestyle = foundation['lifestyle'] is Map
          ? Map<String, dynamic>.from(foundation['lifestyle'] as Map)
          : const <String, dynamic>{};
      final duration =
          (foundation['session_duration_minutes'] as num?)?.round() ?? 45;
      final intensity = recoveryIntensityFromText(
        lifestyle['workout_intensity']?.toString(),
      );
      final trainingPlan = await _loadTrainingPlanContext(
        durationMinutes: duration,
        intensity: intensity,
      );
      final preferences = await SharedPreferences.getInstance();
      final key = _dailyKey(user.id);
      final source = recoverySourceFromText(
        preferences.getString('$key.source'),
      );
      final customType = preferences.getString('$key.type');
      final customDuration = preferences.getInt('$key.duration');
      final customIntensity = preferences.getString('$key.intensity');
      final customWorkout = customType == null || customDuration == null
          ? null
          : RecoveryWorkout(
              name: customType,
              type: customType,
              durationMinutes: customDuration,
              intensity: recoveryIntensityFromText(customIntensity),
              exerciseCount: null,
              isScheduledWorkout: true,
            );

      return RecoveryNutritionContext(
        weightKg: weightKg,
        primaryGoal: foundation['primary_goal']?.toString() ?? fuel?.goal ?? '',
        trainingLevel: foundation['training_level']?.toString() ?? '',
        trainingDaysPerWeek:
            (foundation['training_days_per_week'] as num?)?.round() ?? 0,
        regularStrengthTraining: trainingPlan.regularStrengthTraining,
        performanceFuelHydrationL: fuel?.hydrationL,
        performanceFuelProteinG: fuel?.proteinG,
        performanceFuelCarbsG: fuel?.carbsG,
        trainingPlanWorkout: trainingPlan.workout,
        savedSource: source,
        savedDifferentWorkout: customWorkout,
      );
    } on RecoveryNutritionException {
      rethrow;
    } catch (error) {
      throw RecoveryNutritionException(
        'Recovery nutrition is temporarily unavailable: $error',
      );
    }
  }

  Future<void> saveDailySelection({
    required RecoveryWorkoutSource source,
    RecoveryWorkout? differentWorkout,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final preferences = await SharedPreferences.getInstance();
    final key = _dailyKey(user.id);
    await preferences.setString('$key.source', source.name);
    if (differentWorkout != null) {
      await preferences.setString('$key.type', differentWorkout.type);
      await preferences.setInt(
        '$key.duration',
        differentWorkout.durationMinutes,
      );
      await preferences.setString(
        '$key.intensity',
        differentWorkout.intensity.name,
      );
    }
  }

  Future<({RecoveryWorkout workout, bool regularStrengthTraining})>
  _loadTrainingPlanContext({
    required int durationMinutes,
    required RecoveryWorkoutIntensity intensity,
  }) async {
    final plan = await _supabase
        .from('training_plans')
        .select('id, goal, cycle_start')
        .eq('user_id', _supabase.auth.currentUser!.id)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (plan == null) {
      return (
        workout: RecoveryWorkout(
          name: 'Training Plan Workout',
          type: 'Training',
          durationMinutes: durationMinutes,
          intensity: intensity,
          exerciseCount: null,
          isScheduledWorkout: false,
        ),
        regularStrengthTraining: false,
      );
    }

    final rows = await _supabase
        .from('training_days')
        .select('day_number, title, focus, training_exercises(id)')
        .eq('plan_id', plan['id'])
        .order('day_number');
    final days = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    Map<String, dynamic>? todayWorkout;
    final cycleStart = DateTime.tryParse(plan['cycle_start']?.toString() ?? '');
    if (cycleStart != null) {
      final today = DateTime.now();
      final localStart = DateTime(
        cycleStart.toLocal().year,
        cycleStart.toLocal().month,
        cycleStart.toLocal().day,
      );
      final elapsed = DateTime(
        today.year,
        today.month,
        today.day,
      ).difference(localStart).inDays;
      if (elapsed == 0) {
        todayWorkout = _dayNumber(days, 1);
      } else if (days.length == 7 && elapsed >= 0) {
        todayWorkout = _dayNumber(days, elapsed % 7 + 1);
      }
    }

    final title = todayWorkout?['title']?.toString().trim();
    final focus = todayWorkout?['focus']?.toString().trim();
    final exercises = todayWorkout?['training_exercises'] as List?;
    final planGoal = plan['goal']?.toString().trim();
    final regularStrengthTraining = days.any(
      (day) =>
          _isStrengthTraining(day['title']?.toString() ?? '') ||
          _isStrengthTraining(day['focus']?.toString() ?? ''),
    );
    return (
      workout: RecoveryWorkout(
        name: title?.isNotEmpty == true ? title! : 'Training Plan Workout',
        type: focus?.isNotEmpty == true
            ? focus!
            : planGoal?.isNotEmpty == true
            ? planGoal!
            : 'Training',
        durationMinutes: durationMinutes,
        intensity: intensity,
        exerciseCount: exercises?.length,
        isScheduledWorkout: todayWorkout != null,
      ),
      regularStrengthTraining: regularStrengthTraining,
    );
  }

  bool _isStrengthTraining(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.contains('strength') ||
        normalized.contains('resistance') ||
        normalized.contains('weight') ||
        normalized.contains('muscle') ||
        normalized.contains('hypertrophy') ||
        normalized.contains('chest') ||
        normalized.contains('back') ||
        normalized.contains('legs') ||
        normalized.contains('upper body') ||
        normalized.contains('lower body') ||
        normalized.contains('push') ||
        normalized.contains('pull') ||
        normalized.contains('full body');
  }

  Map<String, dynamic>? _dayNumber(
    List<Map<String, dynamic>> days,
    int dayNumber,
  ) {
    for (final day in days) {
      if ((day['day_number'] as num?)?.round() == dayNumber) return day;
    }
    return null;
  }

  String _dailyKey(String userId) {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return 'recovery_nutrition.$userId.$date';
  }
}

RecoveryWorkoutSource recoverySourceFromText(String? value) {
  return RecoveryWorkoutSource.values.firstWhere(
    (item) => item.name == value,
    orElse: () => RecoveryWorkoutSource.trainingPlan,
  );
}

RecoveryWorkoutIntensity recoveryIntensityFromText(String? value) {
  final normalized = value?.trim().toLowerCase().replaceAll(' ', '') ?? '';
  return switch (normalized) {
    'verylight' => RecoveryWorkoutIntensity.veryLight,
    'light' => RecoveryWorkoutIntensity.light,
    'hard' => RecoveryWorkoutIntensity.hard,
    'veryhard' => RecoveryWorkoutIntensity.veryHard,
    _ => RecoveryWorkoutIntensity.moderate,
  };
}

class RecoveryNutritionException implements Exception {
  final String message;

  const RecoveryNutritionException(this.message);

  @override
  String toString() => message;
}
