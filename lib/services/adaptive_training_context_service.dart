import 'package:future_project/models/adaptive_training.dart';
import 'package:future_project/services/adaptive_training_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdaptiveTrainingContextService {
  final SupabaseClient _supabase;
  final AdaptiveTrainingService _engine;

  AdaptiveTrainingContextService({
    SupabaseClient? supabase,
    AdaptiveTrainingService engine = const AdaptiveTrainingService(),
  }) : _supabase = supabase ?? Supabase.instance.client,
       _engine = engine;

  Future<TrainingCoachContext?> load({DateTime? now}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final foundation = await _supabase
        .from('user_foundations')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (foundation == null) return null;
    final plan = await _supabase
        .from('training_plans')
        .select()
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final days = plan == null
        ? <Map<String, dynamic>>[]
        : (await _supabase
                  .from('training_days')
                  .select('id, day_number, title, focus, training_exercises(*)')
                  .eq('plan_id', plan['id'])
                  .order('day_number'))
              .cast<Map<String, dynamic>>();
    final sessionRows =
        (await _supabase
                .from('workout_sessions')
                .select()
                .eq('user_id', user.id)
                .order('scheduled_at', ascending: false)
                .limit(60))
            .cast<Map<String, dynamic>>();
    final eventRows =
        (await _supabase
                .from('exercise_preference_events')
                .select()
                .eq('user_id', user.id)
                .order('created_at', ascending: false)
                .limit(200))
            .cast<Map<String, dynamic>>();
    final vision = await _supabase
        .from('vision_profiles')
        .select('future_identity')
        .eq('user_id', user.id)
        .maybeSingle();
    final sessionIds = sessionRows
        .map((row) => row['id'])
        .whereType<String>()
        .toList();
    final performanceRows = sessionIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _supabase
                  .from('workout_exercise_performances')
                  .select()
                  .inFilter('session_id', sessionIds)
                  .order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();
    final sessionDate = {
      for (final row in sessionRows)
        row['id']?.toString(): DateTime.tryParse(
          row['scheduled_at']?.toString() ?? '',
        ),
    };
    final performances = performanceRows.map((row) {
      final rawSets = (row['performed_sets'] as List?) ?? const [];
      return ExercisePerformance(
        exerciseId: row['exercise_id']?.toString() ?? '',
        date:
            sessionDate[row['session_id']?.toString()] ??
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        sets: rawSets
            .whereType<Map>()
            .map(
              (set) => PerformedSet(
                reps: (set['reps'] as num?)?.round() ?? 0,
                load: (set['load'] as num?)?.toDouble(),
                completed: set['completed'] != false,
              ),
            )
            .toList(),
        plannedSets: (row['planned_sets'] as num?)?.round() ?? 0,
        targetRepMin: (row['target_rep_min'] as num?)?.round(),
        targetRepMax: (row['target_rep_max'] as num?)?.round(),
        perceivedDifficulty: (row['perceived_difficulty'] as num?)?.toDouble(),
        status: _status(row['status']),
        substitutedFromExerciseId: row['substituted_from_exercise_id']
            ?.toString(),
      );
    }).toList();
    final events = eventRows
        .map(
          (row) => ExercisePreferenceEvent(
            exerciseId: row['exercise_id']?.toString() ?? '',
            signal: ExercisePreferenceSignal.values.firstWhere(
              (value) => value.name == row['signal'],
              orElse: () => ExercisePreferenceSignal.completed,
            ),
            occurredAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
            replacementExerciseId: row['replacement_exercise_id']?.toString(),
            reason: row['reason']?.toString(),
          ),
        )
        .toList();
    final observations = sessionRows
        .map(
          (row) => WorkoutObservation(
            scheduledAt:
                DateTime.tryParse(row['scheduled_at']?.toString() ?? '') ??
                DateTime.now(),
            completed: row['status'] == 'completed',
            plannedDurationMinutes:
                (row['planned_duration_minutes'] as num?)?.round() ?? 0,
            actualDurationMinutes: (row['actual_duration_minutes'] as num?)
                ?.round(),
            substitutions: performanceRows
                .where(
                  (item) =>
                      item['session_id'] == row['id'] &&
                      item['substituted_from_exercise_id'] != null,
                )
                .length,
          ),
        )
        .toList();
    final planned = days
        .expand(
          (day) => ((day['training_exercises'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (row) => CandidateExercise(
                  exerciseId: row['exercise_id']?.toString() ?? '',
                  name: row['exercise_name']?.toString() ?? '',
                  equipment: _strings(row['equipment']),
                  primaryMuscles: _strings(row['primary_muscles']).toList(),
                  movementPattern: row['movement_pattern']?.toString() ?? '',
                  goalRelevance: 0.7,
                  programContinuity: 1,
                  plannedSets: (row['sets'] as num?)?.round() ?? 3,
                ),
              ),
        )
        .toList();
    final profile = _engine.profileFromCanonical(
      foundation: foundation,
      trainingPlan: plan,
      preferenceEvents: events,
      workoutHistory: observations,
    );
    return _engine.coachContext(
      profile: profile,
      planned: planned,
      performance: performances,
      preferenceEvents: events,
      workoutHistory: observations,
      visionIdentity: vision?['future_identity']?.toString(),
      now: now,
    );
  }

  static Set<String> _strings(dynamic value) =>
      ((value as List?) ?? const []).map((item) => item.toString()).toSet();
  static ExerciseCompletionStatus _status(dynamic value) =>
      switch (value?.toString()) {
        'completed' => ExerciseCompletionStatus.completed,
        'skipped' => ExerciseCompletionStatus.skipped,
        _ => ExerciseCompletionStatus.partial,
      };
}
