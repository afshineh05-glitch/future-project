class UserProfile {
  final String id;
  final String? email;

  final String name;
  final int age;
  final String gender;

  final double heightCm;
  final double weightKg;

  final String goal;
  final String activityLevel;

  final int trainingDaysPerWeek;
  final List<String> availableTrainingDays;

  final double workHoursPerDay;
  final String? workStartTime;
  final String? workEndTime;

  final List<String> preferredTrainingTimes;

  final String fitnessLevel;

  const UserProfile({
    required this.id,
    this.email,
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.activityLevel,
    required this.trainingDaysPerWeek,
    required this.availableTrainingDays,
    required this.workHoursPerDay,
    this.workStartTime,
    this.workEndTime,
    required this.preferredTrainingTimes,
    required this.fitnessLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal': goal,
      'activity_level': activityLevel,
      'training_days_per_week': trainingDaysPerWeek,
      'available_training_days': availableTrainingDays,
      'work_hours_per_day': workHoursPerDay,
      'work_start_time': workStartTime,
      'work_end_time': workEndTime,
      'preferred_training_times': preferredTrainingTimes,
      'fitness_level': fitnessLevel,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'],
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      heightCm: (map['height_cm'] ?? 0).toDouble(),
      weightKg: (map['weight_kg'] ?? 0).toDouble(),
      goal: map['goal'] ?? '',
      activityLevel: map['activity_level'] ?? '',
      trainingDaysPerWeek: map['training_days_per_week'] ?? 0,
      availableTrainingDays:
          List<String>.from(map['available_training_days'] ?? []),
      workHoursPerDay: (map['work_hours_per_day'] ?? 0).toDouble(),
      workStartTime: map['work_start_time'],
      workEndTime: map['work_end_time'],
      preferredTrainingTimes:
          List<String>.from(map['preferred_training_times'] ?? []),
      fitnessLevel: map['fitness_level'] ?? '',
    );
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? goal,
    String? activityLevel,
    int? trainingDaysPerWeek,
    List<String>? availableTrainingDays,
    double? workHoursPerDay,
    String? workStartTime,
    String? workEndTime,
    List<String>? preferredTrainingTimes,
    String? fitnessLevel,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      activityLevel: activityLevel ?? this.activityLevel,
      trainingDaysPerWeek:
          trainingDaysPerWeek ?? this.trainingDaysPerWeek,
      availableTrainingDays:
          availableTrainingDays ?? this.availableTrainingDays,
      workHoursPerDay: workHoursPerDay ?? this.workHoursPerDay,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      preferredTrainingTimes:
          preferredTrainingTimes ?? this.preferredTrainingTimes,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
    );
  }

  @override
  String toString() {
    return '''
UserProfile(
  id: $id,
  name: $name,
  goal: $goal,
  activityLevel: $activityLevel,
)
''';
  }
}