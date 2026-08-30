// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:future_project/models/adaptive_training.dart';
import 'package:future_project/services/exercise_preference_service.dart';
import 'package:future_project/services/exercise_progression_service.dart';
import 'package:future_project/services/muscle_recovery_service.dart';
import 'package:future_project/services/training_behavior_service.dart';

class AdaptiveTrainingWeights {
  final double goalRelevance;
  final double recoverySuitability;
  final double preference;
  final double progressionOpportunity;
  final double equipmentCompatibility;
  final double programContinuity;
  final double requiredMovement;
  final double recentOverusePenalty;

  const AdaptiveTrainingWeights({
    this.goalRelevance = 3,
    this.recoverySuitability = 2.5,
    this.preference = 1.5,
    this.progressionOpportunity = 1.5,
    this.equipmentCompatibility = 4,
    this.programContinuity = 2,
    this.requiredMovement = 1,
    this.recentOverusePenalty = 2,
  });
}

class AdaptiveTrainingService {
  final AdaptiveTrainingWeights weights;
  final ExerciseProgressionService progression;
  final MuscleRecoveryService recovery;
  final ExercisePreferenceService preferences;
  final TrainingBehaviorService behavior;

  const AdaptiveTrainingService({
    this.weights = const AdaptiveTrainingWeights(),
    this.progression = const ExerciseProgressionService(),
    this.recovery = const MuscleRecoveryService(),
    this.preferences = const ExercisePreferenceService(),
    this.behavior = const TrainingBehaviorService(),
  });

  AdaptiveTrainingProfile profileFromCanonical({
    required Map<String, dynamic> foundation,
    Map<String, dynamic>? trainingPlan,
    List<ExercisePreferenceEvent> preferenceEvents = const [],
    List<WorkoutObservation> workoutHistory = const [],
  }) {
    Set<String> strings(dynamic value) => ((value as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet();
    final explicitExcluded = strings(foundation['exercises_to_avoid']);
    final explicitLiked = preferenceEvents
        .where((event) => event.signal == ExercisePreferenceSignal.liked)
        .map((event) => event.exerciseId)
        .toSet();
    final explicitDisliked = preferenceEvents
        .where((event) => event.signal == ExercisePreferenceSignal.disliked)
        .map((event) => event.exerciseId)
        .toSet();
    final completed = workoutHistory.where((item) => item.completed).length;
    return AdaptiveTrainingProfile(
      primaryGoal:
          foundation['primary_goal']?.toString() ??
          trainingPlan?['goal']?.toString() ??
          '',
      experienceLevel: foundation['training_level']?.toString() ?? '',
      sessionsPerWeek:
          (foundation['training_days_per_week'] as num?)?.round() ?? 0,
      preferredWorkoutDuration:
          (foundation['session_duration_minutes'] as num?)?.round() ?? 45,
      availableEquipment: strings(foundation['equipment']),
      trainingLocation: foundation['training_location']?.toString() ?? '',
      limitations: [
        ...strings(foundation['injuries']),
        ...strings(foundation['pain_notes']),
      ],
      preferredExercises: explicitLiked,
      dislikedExercises: explicitDisliked,
      excludedExercises: {
        ...explicitExcluded,
        ...preferenceEvents
            .where((event) => event.signal == ExercisePreferenceSignal.excluded)
            .map((event) => event.exerciseId),
      },
      trainingHistorySummary: workoutHistory.length < 3
          ? 'Not enough training history yet.'
          : '$completed of ${workoutHistory.length} observed workouts completed.',
    );
  }

  List<RankedExercise> rank({
    required List<CandidateExercise> candidates,
    required AdaptiveTrainingProfile profile,
    required List<MuscleRecoveryState> recoveryStates,
    required List<ExercisePreferenceEvent> preferenceEvents,
    Set<String> recentlyTrainedExercises = const {},
  }) {
    final recoveryByMuscle = {
      for (final item in recoveryStates) item.muscle: item,
    };
    final result = <RankedExercise>[];
    for (final candidate in candidates) {
      final preference = preferences.score(
        candidate.exerciseId,
        preferenceEvents,
      );
      if (preference.excluded ||
          profile.excludedExercises.contains(candidate.exerciseId))
        continue;
      final equipmentOk =
          candidate.equipment.isEmpty ||
          candidate.equipment.every(profile.availableEquipment.contains);
      if (!equipmentOk) continue;
      final muscleScores = candidate.primaryMuscles
          .map((muscle) => recoveryByMuscle[muscle]?.score ?? 0.7)
          .toList();
      final recoveryScore = muscleScores.isEmpty
          ? 0.7
          : muscleScores.reduce((a, b) => a + b) / muscleScores.length;
      final score =
          candidate.goalRelevance * weights.goalRelevance +
          recoveryScore * weights.recoverySuitability +
          preference.score * weights.preference +
          candidate.progressionOpportunity * weights.progressionOpportunity +
          weights.equipmentCompatibility +
          candidate.programContinuity * weights.programContinuity +
          (candidate.requiredMovement ? weights.requiredMovement : 0) -
          (recentlyTrainedExercises.contains(candidate.exerciseId)
              ? weights.recentOverusePenalty
              : 0);
      result.add(
        RankedExercise(
          exercise: candidate,
          score: score,
          reason:
              'Goal ${candidate.goalRelevance.toStringAsFixed(1)}, recovery ${recoveryScore.toStringAsFixed(1)}, preference ${preference.score.toStringAsFixed(1)}, progression ${candidate.progressionOpportunity.toStringAsFixed(1)}, continuity ${candidate.programContinuity.toStringAsFixed(1)}; equipment compatible.',
        ),
      );
    }
    return result..sort((a, b) => b.score.compareTo(a.score));
  }

  WorkoutRecommendation fitToDuration(
    List<RankedExercise> ranked,
    int availableMinutes,
  ) {
    final selected = <RankedExercise>[];
    var minutes = 0;
    for (final item in ranked) {
      final cost = item.exercise.plannedSets * item.exercise.minutesPerSet;
      if (minutes + cost <= availableMinutes) {
        selected.add(item);
        minutes += cost;
      }
    }
    return WorkoutRecommendation(
      exercises: selected,
      estimatedDurationMinutes: minutes,
      reason: selected.length == ranked.length
          ? 'The planned work fits the available time.'
          : 'Kept the highest-scoring goal-relevant and required movements first, then removed lower-priority volume to fit $availableMinutes minutes.',
    );
  }

  CandidateExercise? equipmentSubstitution(
    CandidateExercise original,
    List<CandidateExercise> alternatives,
    AdaptiveTrainingProfile profile,
  ) {
    final valid = alternatives
        .where(
          (item) =>
              item.exerciseId != original.exerciseId &&
              item.movementPattern == original.movementPattern &&
              item.primaryMuscles
                  .toSet()
                  .intersection(original.primaryMuscles.toSet())
                  .isNotEmpty &&
              (item.equipment.isEmpty ||
                  item.equipment.every(profile.availableEquipment.contains)),
        )
        .toList();
    valid.sort(
      (a, b) => (b.goalRelevance + b.programContinuity).compareTo(
        a.goalRelevance + a.programContinuity,
      ),
    );
    return valid.firstOrNull;
  }

  TrainingCoachContext coachContext({
    required AdaptiveTrainingProfile profile,
    required List<CandidateExercise> planned,
    required List<ExercisePerformance> performance,
    required List<ExercisePreferenceEvent> preferenceEvents,
    required List<WorkoutObservation> workoutHistory,
    String? visionIdentity,
    DateTime? now,
  }) {
    final recoveryStates = recovery.estimate(performance, now: now);
    final progressionItems = planned
        .map((item) => progression.recommend(item.exerciseId, performance))
        .toList();
    final ranked = rank(
      candidates: planned,
      profile: profile,
      recoveryStates: recoveryStates,
      preferenceEvents: preferenceEvents,
    );
    final patterns = behavior.detect(workoutHistory, now: now);
    final changes = patterns
        .where(
          (item) =>
              item.type == AdherencePatternType.missedWeekday ||
              item.type == AdherencePatternType.shortenedWorkouts,
        )
        .map(
          (item) => SuggestedPlanChange(
            title: 'Suggested schedule adjustment',
            why: item.explanation,
            whatChanges:
                'Shorten or move the affected session while keeping its highest-value movements.',
          ),
        )
        .toList();
    return TrainingCoachContext(
      todaysPlannedWorkout: ranked,
      recentPerformance: ([
        ...performance,
      ]..sort((a, b) => b.date.compareTo(a.date))).take(10).toList(),
      progressionOpportunities: progressionItems,
      recoverySummary: recoveryStates,
      adherencePatterns: patterns,
      exercisePreferences: planned
          .map((item) => preferences.score(item.exerciseId, preferenceEvents))
          .toList(),
      recurringSubstitutions: preferences.recurringSubstitutions(
        preferenceEvents,
      ),
      currentTrainingStage: workoutHistory.length < 3
          ? 'learning'
          : workoutHistory.length < 12
          ? 'building consistency'
          : 'established',
      visionIdentity: visionIdentity,
      currentGoal: profile.primaryGoal,
      suggestedChanges: changes,
      dataConfidence: workoutHistory.length < 3
          ? 'Not enough training history yet.'
          : '${workoutHistory.length} workout observations available.',
    );
  }
}
