import 'package:future_project/models/performance_fuel.dart';

class NutritionFoodLogEntry {
  final String id;
  final DateTime consumedAt;
  final String foodName;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? fiberG;
  final String source;
  final String? analysisReference;

  const NutritionFoodLogEntry({
    required this.id,
    required this.consumedAt,
    required this.foodName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.source,
    required this.analysisReference,
  });

  factory NutritionFoodLogEntry.fromMap(Map<String, dynamic> map) {
    return NutritionFoodLogEntry(
      id: map['id'].toString(),
      consumedAt: DateTime.parse(map['consumed_at'].toString()),
      foodName: map['food_name']?.toString() ?? 'Meal',
      calories: (map['calories'] as num? ?? 0).toDouble(),
      proteinG: (map['protein_g'] as num? ?? 0).toDouble(),
      carbsG: (map['carbs_g'] as num? ?? 0).toDouble(),
      fatG: (map['fat_g'] as num? ?? 0).toDouble(),
      fiberG: (map['fiber_g'] as num?)?.toDouble(),
      source: map['source']?.toString() ?? 'unknown',
      analysisReference: map['analysis_reference']?.toString(),
    );
  }
}

class NutritionFoodTotals {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? fiberG;

  const NutritionFoodTotals({
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.fiberG,
  });

  factory NutritionFoodTotals.fromEntries(List<NutritionFoodLogEntry> entries) {
    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var fiber = 0.0;
    var hasFiber = false;
    for (final entry in entries) {
      calories += entry.calories;
      protein += entry.proteinG;
      carbs += entry.carbsG;
      fat += entry.fatG;
      if (entry.fiberG != null) {
        fiber += entry.fiberG!;
        hasFiber = true;
      }
    }
    return NutritionFoodTotals(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fiberG: hasFiber ? fiber : null,
    );
  }
}

class NutritionFoodRemaining {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? fiberG;

  const NutritionFoodRemaining({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });
}

class NutritionFoodDay {
  final List<NutritionFoodLogEntry> entries;
  final NutritionFoodTotals totals;

  const NutritionFoodDay({required this.entries, required this.totals});

  factory NutritionFoodDay.fromEntries(List<NutritionFoodLogEntry> entries) {
    return NutritionFoodDay(
      entries: List.unmodifiable(entries),
      totals: NutritionFoodTotals.fromEntries(entries),
    );
  }

  NutritionFoodRemaining remainingFor(PerformanceFuel fuel) {
    return NutritionFoodRemaining(
      calories: (fuel.calories.target - totals.calories).clamp(
        0,
        double.infinity,
      ),
      proteinG: (fuel.proteinG - totals.proteinG).clamp(0, double.infinity),
      carbsG: (fuel.carbsG - totals.carbsG).clamp(0, double.infinity),
      fatG: (fuel.fatG - totals.fatG).clamp(0, double.infinity),
      fiberG: totals.fiberG == null
          ? null
          : (fuel.fiberG - totals.fiberG!).clamp(0, double.infinity),
    );
  }
}
