enum WeeklyMissionType {
  protectRecovery,
  improveTrainingNightSleep,
  improveWorkoutConsistency,
  reduceActivityLoad,
  maintainSuccessfulBehavior,
}

enum WeeklyMissionOutcome {
  success,
  partialImprovement,
  unchanged,
  insufficientData,
}

class WeeklyCoachDataCoverage {
  final int wearableDays;
  final int expectedWearableDays;
  final bool workoutSourceAvailable;
  final bool nutritionSourceAvailable;

  const WeeklyCoachDataCoverage({
    required this.wearableDays,
    this.expectedWearableDays = 7,
    required this.workoutSourceAvailable,
    this.nutritionSourceAvailable = false,
  });

  String get summary => wearableDays == 0
      ? 'Wearable data was unavailable; guidance uses reliable training history.'
      : 'Based on $wearableDays of $expectedWearableDays days of wearable data.';
}

class WeeklyCoachPlan {
  final String? userId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final String shortRetrospective;
  final String biggestWin;
  final String mainLimitingFactor;
  final WeeklyMissionType missionType;
  final String missionTitle;
  final String missionReason;
  final List<String> actionItems;
  final String motivationContext;
  final String? previousMissionTitle;
  final WeeklyMissionOutcome previousMissionOutcome;
  final String followUpMessage;
  final WeeklyCoachDataCoverage dataCoverage;
  final List<String> evidence;
  final DateTime generatedAt;

  const WeeklyCoachPlan({
    this.userId,
    required this.weekStart,
    required this.weekEnd,
    required this.shortRetrospective,
    required this.biggestWin,
    required this.mainLimitingFactor,
    required this.missionType,
    required this.missionTitle,
    required this.missionReason,
    required this.actionItems,
    required this.motivationContext,
    this.previousMissionTitle,
    required this.previousMissionOutcome,
    required this.followUpMessage,
    required this.dataCoverage,
    required this.evidence,
    required this.generatedAt,
  }) : assert(actionItems.length <= 3);

  static String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String missionKey(WeeklyMissionType value) => switch (value) {
    WeeklyMissionType.protectRecovery => 'protect_recovery',
    WeeklyMissionType.improveTrainingNightSleep =>
      'improve_training_night_sleep',
    WeeklyMissionType.improveWorkoutConsistency =>
      'improve_workout_consistency',
    WeeklyMissionType.reduceActivityLoad => 'reduce_activity_load',
    WeeklyMissionType.maintainSuccessfulBehavior =>
      'maintain_successful_behavior',
  };

  static String outcomeKey(WeeklyMissionOutcome value) => switch (value) {
    WeeklyMissionOutcome.success => 'success',
    WeeklyMissionOutcome.partialImprovement => 'partial_improvement',
    WeeklyMissionOutcome.unchanged => 'unchanged',
    WeeklyMissionOutcome.insufficientData => 'insufficient_data',
  };

  factory WeeklyCoachPlan.fromMap(Map<String, dynamic> row) => WeeklyCoachPlan(
    userId: row['user_id']?.toString(),
    weekStart: DateTime.parse(row['week_start'].toString()),
    weekEnd: DateTime.parse(row['week_end'].toString()),
    shortRetrospective: row['short_retrospective']?.toString() ?? '',
    biggestWin: row['biggest_win']?.toString() ?? '',
    mainLimitingFactor: row['main_limiting_factor']?.toString() ?? '',
    missionType: WeeklyMissionType.values.firstWhere(
      (value) => missionKey(value) == row['mission_type'],
      orElse: () => WeeklyMissionType.maintainSuccessfulBehavior,
    ),
    missionTitle: row['mission_title']?.toString() ?? '',
    missionReason: row['mission_reason']?.toString() ?? '',
    actionItems: ((row['action_items'] as List?) ?? const [])
        .map((e) => e.toString())
        .take(3)
        .toList(),
    motivationContext: row['motivation_context']?.toString() ?? '',
    previousMissionTitle: row['previous_mission_title']?.toString(),
    previousMissionOutcome: WeeklyMissionOutcome.values.firstWhere(
      (value) => outcomeKey(value) == row['previous_mission_outcome'],
      orElse: () => WeeklyMissionOutcome.insufficientData,
    ),
    followUpMessage: row['follow_up_message']?.toString() ?? '',
    dataCoverage: WeeklyCoachDataCoverage(
      wearableDays: (row['wearable_days'] as num?)?.round() ?? 0,
      workoutSourceAvailable: row['workout_source_available'] == true,
      nutritionSourceAvailable: false,
    ),
    evidence: ((row['evidence'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    generatedAt: DateTime.parse(row['generated_at'].toString()),
  );
}
