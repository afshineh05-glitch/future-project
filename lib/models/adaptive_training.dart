enum ExerciseCompletionStatus { completed, partial, skipped }

enum ProgressionAction {
  increaseLoad,
  increaseReps,
  maintain,
  reduceLoad,
  reduceVolume,
  changeExercise,
  deloadConsideration,
}

enum MuscleReadiness { ready, moderate, fatigued, unknown }

enum ExercisePreferenceSignal {
  completed,
  skipped,
  replaced,
  added,
  removed,
  liked,
  disliked,
  excluded,
}

class AdaptiveTrainingProfile {
  final String primaryGoal;
  final String experienceLevel;
  final List<int> preferredTrainingDays;
  final int sessionsPerWeek;
  final int preferredWorkoutDuration;
  final Set<String> availableEquipment;
  final String trainingLocation;
  final List<String> limitations;
  final Set<String> preferredExercises;
  final Set<String> dislikedExercises;
  final Set<String> excludedExercises;
  final String trainingHistorySummary;

  const AdaptiveTrainingProfile({
    required this.primaryGoal,
    required this.experienceLevel,
    this.preferredTrainingDays = const [],
    required this.sessionsPerWeek,
    required this.preferredWorkoutDuration,
    this.availableEquipment = const {},
    required this.trainingLocation,
    this.limitations = const [],
    this.preferredExercises = const {},
    this.dislikedExercises = const {},
    this.excludedExercises = const {},
    this.trainingHistorySummary = 'Not enough training history yet.',
  });
}

class PerformedSet {
  final int reps;
  final double? load;
  final bool completed;

  const PerformedSet({required this.reps, this.load, this.completed = true});
}

class ExercisePerformance {
  final String exerciseId;
  final DateTime date;
  final List<PerformedSet> sets;
  final int plannedSets;
  final int? targetRepMin;
  final int? targetRepMax;
  final double? perceivedDifficulty;
  final ExerciseCompletionStatus status;
  final String? substitutedFromExerciseId;
  final List<String> primaryMuscles;

  const ExercisePerformance({
    required this.exerciseId,
    required this.date,
    required this.sets,
    required this.plannedSets,
    this.targetRepMin,
    this.targetRepMax,
    this.perceivedDifficulty,
    required this.status,
    this.substitutedFromExerciseId,
    this.primaryMuscles = const [],
  });

  int get completedSets => sets.where((set) => set.completed).length;
  double? get averageLoad {
    final loads = sets
        .where((set) => set.completed && set.load != null)
        .map((set) => set.load!);
    return loads.isEmpty ? null : loads.reduce((a, b) => a + b) / loads.length;
  }
}

class ProgressionRecommendation {
  final String exerciseId;
  final ProgressionAction action;
  final String reason;
  final double? suggestedLoad;
  final int observations;

  const ProgressionRecommendation({
    required this.exerciseId,
    required this.action,
    required this.reason,
    this.suggestedLoad,
    required this.observations,
  });
}

class MuscleRecoveryState {
  final String muscle;
  final MuscleReadiness readiness;
  final double score;
  final String reason;

  const MuscleRecoveryState({
    required this.muscle,
    required this.readiness,
    required this.score,
    required this.reason,
  });
}

class ExercisePreferenceEvent {
  final String exerciseId;
  final ExercisePreferenceSignal signal;
  final DateTime occurredAt;
  final String? replacementExerciseId;
  final String? reason;

  const ExercisePreferenceEvent({
    required this.exerciseId,
    required this.signal,
    required this.occurredAt,
    this.replacementExerciseId,
    this.reason,
  });
}

class ExercisePreferenceScore {
  final String exerciseId;
  final double score;
  final bool excluded;
  final String reason;

  const ExercisePreferenceScore({
    required this.exerciseId,
    required this.score,
    required this.excluded,
    required this.reason,
  });
}

enum AdherencePatternType {
  missedWeekday,
  strongWeekday,
  shortenedWorkouts,
  frequentSubstitutions,
  returnedAfterGap,
  consistentSessions,
}

class WorkoutObservation {
  final DateTime scheduledAt;
  final bool completed;
  final int plannedDurationMinutes;
  final int? actualDurationMinutes;
  final int substitutions;

  const WorkoutObservation({
    required this.scheduledAt,
    required this.completed,
    required this.plannedDurationMinutes,
    this.actualDurationMinutes,
    this.substitutions = 0,
  });
}

class AdherencePattern {
  final AdherencePatternType type;
  final String explanation;
  final int observations;

  const AdherencePattern({
    required this.type,
    required this.explanation,
    required this.observations,
  });
}

class CandidateExercise {
  final String exerciseId;
  final String name;
  final Set<String> equipment;
  final List<String> primaryMuscles;
  final String movementPattern;
  final double goalRelevance;
  final double programContinuity;
  final double progressionOpportunity;
  final int plannedSets;
  final int minutesPerSet;
  final bool requiredMovement;

  const CandidateExercise({
    required this.exerciseId,
    required this.name,
    this.equipment = const {},
    this.primaryMuscles = const [],
    required this.movementPattern,
    this.goalRelevance = 0.5,
    this.programContinuity = 0.5,
    this.progressionOpportunity = 0,
    this.plannedSets = 3,
    this.minutesPerSet = 3,
    this.requiredMovement = false,
  });
}

class RankedExercise {
  final CandidateExercise exercise;
  final double score;
  final String reason;

  const RankedExercise({
    required this.exercise,
    required this.score,
    required this.reason,
  });
}

class WorkoutRecommendation {
  final List<RankedExercise> exercises;
  final int estimatedDurationMinutes;
  final String reason;

  const WorkoutRecommendation({
    required this.exercises,
    required this.estimatedDurationMinutes,
    required this.reason,
  });
}

class SuggestedPlanChange {
  final String title;
  final String why;
  final String whatChanges;
  final bool requiresAcceptance;

  const SuggestedPlanChange({
    required this.title,
    required this.why,
    required this.whatChanges,
    this.requiresAcceptance = true,
  });
}

class TrainingCoachContext {
  final List<RankedExercise> todaysPlannedWorkout;
  final List<ExercisePerformance> recentPerformance;
  final List<ProgressionRecommendation> progressionOpportunities;
  final List<MuscleRecoveryState> recoverySummary;
  final List<AdherencePattern> adherencePatterns;
  final List<ExercisePreferenceScore> exercisePreferences;
  final Map<String, String> recurringSubstitutions;
  final String currentTrainingStage;
  final String? visionIdentity;
  final String currentGoal;
  final List<SuggestedPlanChange> suggestedChanges;
  final String dataConfidence;

  const TrainingCoachContext({
    this.todaysPlannedWorkout = const [],
    this.recentPerformance = const [],
    this.progressionOpportunities = const [],
    this.recoverySummary = const [],
    this.adherencePatterns = const [],
    this.exercisePreferences = const [],
    this.recurringSubstitutions = const {},
    required this.currentTrainingStage,
    this.visionIdentity,
    required this.currentGoal,
    this.suggestedChanges = const [],
    required this.dataConfidence,
  });

  Map<String, dynamic> toMap() => {
    'todaysPlannedWorkout': todaysPlannedWorkout
        .map(
          (item) => {
            'exerciseId': item.exercise.exerciseId,
            'name': item.exercise.name,
            'score': item.score,
            'reason': item.reason,
          },
        )
        .toList(),
    'recentPerformance': recentPerformance
        .map(
          (item) => {
            'exerciseId': item.exerciseId,
            'date': item.date.toIso8601String(),
            'completedSets': item.completedSets,
            'plannedSets': item.plannedSets,
            'status': item.status.name,
          },
        )
        .toList(),
    'progressionOpportunities': progressionOpportunities
        .map(
          (item) => {
            'exerciseId': item.exerciseId,
            'action': item.action.name,
            'reason': item.reason,
            'suggestedLoad': item.suggestedLoad,
          },
        )
        .toList(),
    'recoverySummary': recoverySummary
        .map(
          (item) => {
            'muscle': item.muscle,
            'readiness': item.readiness.name,
            'score': item.score,
            'reason': item.reason,
          },
        )
        .toList(),
    'adherencePatterns': adherencePatterns
        .map(
          (item) => {
            'type': item.type.name,
            'explanation': item.explanation,
            'observations': item.observations,
          },
        )
        .toList(),
    'exercisePreferences': exercisePreferences
        .map(
          (item) => {
            'exerciseId': item.exerciseId,
            'score': item.score,
            'excluded': item.excluded,
            'reason': item.reason,
          },
        )
        .toList(),
    'recurringSubstitutions': recurringSubstitutions,
    'currentTrainingStage': currentTrainingStage,
    'visionIdentity': visionIdentity,
    'currentGoal': currentGoal,
    'suggestedChanges': suggestedChanges
        .map(
          (item) => {
            'title': item.title,
            'why': item.why,
            'whatChanges': item.whatChanges,
            'requiresAcceptance': item.requiresAcceptance,
          },
        )
        .toList(),
    'dataConfidence': dataConfidence,
  };
}
