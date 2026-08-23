class PerformanceFuelCalories {
  final int target;
  final int rangeMin;
  final int rangeMax;

  const PerformanceFuelCalories({
    required this.target,
    required this.rangeMin,
    required this.rangeMax,
  });

  factory PerformanceFuelCalories.fromMap(Map<String, dynamic> map) {
    return PerformanceFuelCalories(
      target: (map['target'] as num).round(),
      rangeMin: (map['range_min'] as num).round(),
      rangeMax: (map['range_max'] as num).round(),
    );
  }
}

class PerformanceFuel {
  final String goal;
  final PerformanceFuelCalories calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final double hydrationL;
  final List<String> micronutrientFocus;
  final String why;
  final String calculationVersion;
  final DateTime? generatedAt;
  final bool cached;

  const PerformanceFuel({
    required this.goal,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.hydrationL,
    required this.micronutrientFocus,
    required this.why,
    required this.calculationVersion,
    required this.generatedAt,
    required this.cached,
  });

  String get goalLabel {
    switch (goal) {
      case 'fat_loss':
        return 'Fat Loss';
      case 'muscle_gain':
        return 'Build Muscle';
      case 'athletic_performance':
        return 'Athletic Performance';
      case 'fitness':
        return 'Improve Fitness';
      case 'health':
        return 'Improve Health';
      default:
        return 'Maintain Weight';
    }
  }

  factory PerformanceFuel.fromMap(Map<String, dynamic> map) {
    final calories = map['calories'];
    if (calories is! Map) {
      throw const FormatException('Performance Fuel calories are missing.');
    }
    final generatedAt = map['generated_at']?.toString();
    return PerformanceFuel(
      goal: map['goal']?.toString() ?? 'maintenance',
      calories: PerformanceFuelCalories.fromMap(
        Map<String, dynamic>.from(calories),
      ),
      proteinG: (map['protein_g'] as num).round(),
      carbsG: (map['carbs_g'] as num).round(),
      fatG: (map['fat_g'] as num).round(),
      fiberG: (map['fiber_g'] as num).round(),
      hydrationL: (map['hydration_l'] as num).toDouble(),
      micronutrientFocus: ((map['micronutrient_focus'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      why: map['why']?.toString() ?? '',
      calculationVersion: map['calculation_version']?.toString() ?? '',
      generatedAt: generatedAt == null ? null : DateTime.tryParse(generatedAt),
      cached: map['cached'] == true,
    );
  }
}
