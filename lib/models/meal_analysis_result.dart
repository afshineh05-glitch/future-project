class MealAnalysisResult {
  final String mealName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> detectedFoods;
  final double confidence;

  const MealAnalysisResult({
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.detectedFoods,
    required this.confidence,
  });

  factory MealAnalysisResult.fromMap(Map<String, dynamic> map) {
    return MealAnalysisResult(
      mealName: map['meal_name'] as String? ?? 'Unknown meal',
      calories: (map['calories'] as num? ?? 0).round(),
      protein: (map['protein'] as num? ?? 0).toDouble(),
      carbs: (map['carbs'] as num? ?? 0).toDouble(),
      fat: (map['fat'] as num? ?? 0).toDouble(),
      detectedFoods: List<String>.from(
        map['detected_foods'] ?? const [],
      ),
      confidence: (map['confidence'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'meal_name': mealName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'detected_foods': detectedFoods,
      'confidence': confidence,
    };
  }
}