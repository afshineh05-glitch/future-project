import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/adaptive_training.dart';
import 'package:future_project/services/adaptive_training_service.dart';
import 'package:future_project/services/exercise_preference_service.dart';
import 'package:future_project/services/exercise_progression_service.dart';
import 'package:future_project/services/muscle_recovery_service.dart';
import 'package:future_project/services/training_behavior_service.dart';

void main() {
  const progression = ExerciseProgressionService();
  const preferences = ExercisePreferenceService();
  const behavior = TrainingBehaviorService();
  const adaptive = AdaptiveTrainingService();
  final now = DateTime(2026, 8, 24, 12);

  ExercisePerformance performance({
    required DateTime date,
    int reps = 10,
    double load = 50,
    int completedSets = 3,
    int plannedSets = 3,
    double effort = 7,
    ExerciseCompletionStatus status = ExerciseCompletionStatus.completed,
    String? substitutedFrom,
    List<String> muscles = const ['chest'],
  }) => ExercisePerformance(
    exerciseId: 'bench',
    date: date,
    sets: List.generate(
      completedSets,
      (_) => PerformedSet(reps: reps, load: load),
    ),
    plannedSets: plannedSets,
    targetRepMin: 8,
    targetRepMax: 10,
    perceivedDifficulty: effort,
    status: status,
    substitutedFromExerciseId: substitutedFrom,
    primaryMuscles: muscles,
  );

  test('successful progression is conservative and deterministic', () {
    final result = progression.recommend('bench', [
      performance(date: now.subtract(const Duration(days: 7))),
      performance(date: now),
    ]);
    expect(result.action, ProgressionAction.increaseLoad);
    expect(result.suggestedLoad, 52.5);
  });

  test('maintains without repeated top-range work', () {
    final result = progression.recommend('bench', [
      performance(date: now, reps: 9),
      performance(date: now.subtract(const Duration(days: 7)), reps: 8),
    ]);
    expect(result.action, ProgressionAction.maintain);
  });

  test('regression suggests recovery inspection/deload', () {
    final result = progression.recommend('bench', [
      performance(
        date: now.subtract(const Duration(days: 14)),
        reps: 10,
        completedSets: 3,
      ),
      performance(
        date: now.subtract(const Duration(days: 7)),
        reps: 8,
        completedSets: 2,
        status: ExerciseCompletionStatus.partial,
      ),
      performance(
        date: now,
        reps: 6,
        completedSets: 1,
        status: ExerciseCompletionStatus.partial,
      ),
    ]);
    expect(result.action, ProgressionAction.deloadConsideration);
  });

  test('recent repeated muscle work is fatigued', () {
    final states = const MuscleRecoveryService().estimate([
      performance(
        date: now.subtract(const Duration(hours: 12)),
        completedSets: 7,
      ),
      performance(
        date: now.subtract(const Duration(hours: 36)),
        completedSets: 6,
      ),
    ], now: now);
    expect(states.single.readiness, MuscleReadiness.fatigued);
    expect(states.single.reason, contains('not a medical measurement'));
  });

  test('excluded exercise is never ranked', () {
    final ranked = adaptive.rank(
      candidates: [candidate('bench')],
      profile: profile(excluded: {'bench'}),
      recoveryStates: const [],
      preferenceEvents: const [],
    );
    expect(ranked, isEmpty);
  });

  test('repeated replacement becomes a recurring substitution', () {
    final events = [
      event(
        'barbell_bench',
        ExercisePreferenceSignal.replaced,
        replacement: 'db_bench',
      ),
      event(
        'barbell_bench',
        ExercisePreferenceSignal.replaced,
        replacement: 'db_bench',
      ),
    ];
    expect(
      preferences.recurringSubstitutions(events)['barbell_bench'],
      'db_bench',
    );
  });

  test('three repeated skipped weekdays form a pattern', () {
    final history = List.generate(
      3,
      (i) => WorkoutObservation(
        scheduledAt: DateTime(2026, 8, 1 + i * 7),
        completed: false,
        plannedDurationMinutes: 45,
      ),
    );
    expect(
      behavior.detect(history).single.type,
      AdherencePatternType.missedWeekday,
    );
  });

  test('insufficient history does not fabricate a pattern', () {
    expect(
      behavior.detect([
        WorkoutObservation(
          scheduledAt: now,
          completed: false,
          plannedDurationMinutes: 45,
        ),
      ]),
      isEmpty,
    );
    expect(
      progression.recommend('bench', [performance(date: now)]).reason,
      'Not enough training history yet.',
    );
  });

  test('shortened workout preserves highest-value work', () {
    final ranked = [
      RankedExercise(
        exercise: candidate('squat', sets: 4),
        score: 10,
        reason: '',
      ),
      RankedExercise(
        exercise: candidate('curl', sets: 3),
        score: 2,
        reason: '',
      ),
    ];
    final result = adaptive.fitToDuration(ranked, 12);
    expect(result.exercises.single.exercise.exerciseId, 'squat');
  });

  test('equipment substitution preserves movement and muscle', () {
    final original = candidate('barbell_bench', equipment: {'barbell'});
    final replacement = adaptive.equipmentSubstitution(original, [
      candidate('db_bench', equipment: {'dumbbells'}),
      candidate('pushup', equipment: {}, pattern: 'push'),
    ], profile(equipment: {'dumbbells'}));
    expect(replacement?.exerciseId, 'db_bench');
  });

  test('return after a training gap is detected', () {
    final history = [
      WorkoutObservation(
        scheduledAt: now.subtract(const Duration(days: 20)),
        completed: true,
        plannedDurationMinutes: 45,
      ),
      WorkoutObservation(
        scheduledAt: now.subtract(const Duration(days: 5)),
        completed: true,
        plannedDurationMinutes: 45,
      ),
      WorkoutObservation(
        scheduledAt: now.subtract(const Duration(days: 2)),
        completed: true,
        plannedDurationMinutes: 45,
      ),
    ];
    expect(
      behavior
          .detect(history, now: now)
          .any((item) => item.type == AdherencePatternType.returnedAfterGap),
      isTrue,
    );
  });

  test('explicit preference overrides inferred behavior', () {
    final events = [
      for (var i = 0; i < 8; i++)
        event('bench', ExercisePreferenceSignal.skipped),
      event('bench', ExercisePreferenceSignal.liked),
    ];
    expect(preferences.score('bench', events).score, 3);
  });
}

CandidateExercise candidate(
  String id, {
  Set<String> equipment = const {},
  String pattern = 'horizontal_push',
  int sets = 3,
}) => CandidateExercise(
  exerciseId: id,
  name: id,
  equipment: equipment,
  primaryMuscles: const ['chest'],
  movementPattern: pattern,
  goalRelevance: id == 'squat' ? 1 : .5,
  plannedSets: sets,
);
AdaptiveTrainingProfile profile({
  Set<String> excluded = const {},
  Set<String> equipment = const {'barbell', 'dumbbells'},
}) => AdaptiveTrainingProfile(
  primaryGoal: 'build_muscle',
  experienceLevel: 'intermediate',
  sessionsPerWeek: 3,
  preferredWorkoutDuration: 45,
  availableEquipment: equipment,
  trainingLocation: 'gym',
  excludedExercises: excluded,
);
ExercisePreferenceEvent event(
  String id,
  ExercisePreferenceSignal signal, {
  String? replacement,
}) => ExercisePreferenceEvent(
  exerciseId: id,
  signal: signal,
  occurredAt: DateTime(2026),
  replacementExerciseId: replacement,
);
