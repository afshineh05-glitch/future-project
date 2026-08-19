class NutritionProfile {
  final String userId;
  final String dietType;
  final List<String> foodAllergies;
  final List<String> foodsToAvoid;
  final List<String> dislikedFoods;
  final String mealsPerDay;
  final String maximumCookingTime;
  final String cookingSkill;
  final String foodBudget;

  const NutritionProfile({
    required this.userId,
    required this.dietType,
    required this.foodAllergies,
    required this.foodsToAvoid,
    required this.dislikedFoods,
    required this.mealsPerDay,
    required this.maximumCookingTime,
    required this.cookingSkill,
    required this.foodBudget,
  });

  factory NutritionProfile.fromMap(Map<String, dynamic> map) {
    List<String> strings(dynamic value) {
      return ((value as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList();
    }

    return NutritionProfile(
      userId: map['user_id']?.toString() ?? '',
      dietType: map['diet_type']?.toString() ?? '',
      foodAllergies: strings(map['food_allergies']),
      foodsToAvoid: strings(map['foods_to_avoid']),
      dislikedFoods: strings(map['disliked_foods']),
      mealsPerDay: map['meals_per_day']?.toString() ?? '',
      maximumCookingTime: map['maximum_cooking_time']?.toString() ?? '',
      cookingSkill: map['cooking_skill']?.toString() ?? '',
      foodBudget: map['food_budget']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'diet_type': dietType,
      'food_allergies': foodAllergies,
      'foods_to_avoid': foodsToAvoid,
      'disliked_foods': dislikedFoods,
      'meals_per_day': mealsPerDay,
      'maximum_cooking_time': maximumCookingTime,
      'cooking_skill': cookingSkill,
      'food_budget': foodBudget,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
