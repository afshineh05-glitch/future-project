enum DailyActivityType {
  workout,
  nutrition,
  reflection,
  weeklyMission,
  dailyDecision,
}

enum DailyActivityStatus { planned, recorded, partial, completed, skipped }

class DailyActivityRecord {
  final DateTime localDate;
  final String activityIdentity;
  final DailyActivityType type;
  final DailyActivityStatus status;
  final String sourceTable;
  final String? sourceId;
  final int observationCount;
  final Map<String, dynamic> metadata;

  const DailyActivityRecord({
    required this.localDate,
    required this.activityIdentity,
    required this.type,
    required this.status,
    required this.sourceTable,
    this.sourceId,
    this.observationCount = 1,
    this.metadata = const {},
  });

  bool get isComplete => status == DailyActivityStatus.completed;

  factory DailyActivityRecord.fromMap(Map<String, dynamic> row) =>
      DailyActivityRecord(
        localDate: DateTime.parse(row['local_date'].toString()),
        activityIdentity: row['activity_identity'].toString(),
        type: DailyActivityType.values.byName(row['activity_type'].toString()),
        status: DailyActivityStatus.values.byName(row['status'].toString()),
        sourceTable: row['source_table'].toString(),
        sourceId: row['source_id']?.toString(),
        observationCount: (row['observation_count'] as num?)?.toInt() ?? 1,
        metadata: Map<String, dynamic>.from(
          row['metadata'] as Map? ?? const {},
        ),
      );
}

class DailyActivityCoverage {
  final bool workoutAvailable;
  final bool nutritionAvailable;
  final bool reflectionAvailable;
  final bool weeklyMissionAvailable;
  final bool dailyDecisionAvailable;
  final bool visionAvailable;

  const DailyActivityCoverage({
    required this.workoutAvailable,
    required this.nutritionAvailable,
    required this.reflectionAvailable,
    required this.weeklyMissionAvailable,
    required this.dailyDecisionAvailable,
    required this.visionAvailable,
  });
}

class DailyActivityState {
  final DateTime localDate;
  final List<DailyActivityRecord> activities;
  final DailyActivityCoverage coverage;
  final String? visionIdentity;
  final DateTime generatedAt;

  const DailyActivityState({
    required this.localDate,
    required this.activities,
    required this.coverage,
    this.visionIdentity,
    required this.generatedAt,
  });

  Iterable<DailyActivityRecord> ofType(DailyActivityType type) =>
      activities.where((activity) => activity.type == type);

  bool hasCompleted(DailyActivityType type) =>
      ofType(type).any((activity) => activity.isComplete);

  bool get hasPlannedWorkout => ofType(
    DailyActivityType.workout,
  ).any((activity) => activity.status == DailyActivityStatus.planned);
}
