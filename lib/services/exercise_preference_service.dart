// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:future_project/models/adaptive_training.dart';

class ExercisePreferenceService {
  const ExercisePreferenceService();
  static const weights = <ExercisePreferenceSignal, double>{
    ExercisePreferenceSignal.completed: 0.25,
    ExercisePreferenceSignal.skipped: -0.6,
    ExercisePreferenceSignal.replaced: -0.8,
    ExercisePreferenceSignal.added: 0.4,
    ExercisePreferenceSignal.removed: -0.5,
  };

  ExercisePreferenceScore score(
    String exerciseId,
    List<ExercisePreferenceEvent> events,
  ) {
    final relevant = events
        .where((event) => event.exerciseId == exerciseId)
        .toList();
    if (relevant.any(
      (event) => event.signal == ExercisePreferenceSignal.excluded,
    ))
      return ExercisePreferenceScore(
        exerciseId: exerciseId,
        score: -100,
        excluded: true,
        reason: 'Explicitly excluded by the user.',
      );
    if (relevant.any(
      (event) => event.signal == ExercisePreferenceSignal.disliked,
    ))
      return ExercisePreferenceScore(
        exerciseId: exerciseId,
        score: -3,
        excluded: false,
        reason: 'Explicit dislike overrides inferred behavior.',
      );
    if (relevant.any((event) => event.signal == ExercisePreferenceSignal.liked))
      return ExercisePreferenceScore(
        exerciseId: exerciseId,
        score: 3,
        excluded: false,
        reason: 'Explicit like overrides inferred behavior.',
      );
    final value = relevant.fold<double>(
      0,
      (sum, event) => sum + (weights[event.signal] ?? 0),
    );
    return ExercisePreferenceScore(
      exerciseId: exerciseId,
      score: value.clamp(-2, 2),
      excluded: false,
      reason: relevant.isEmpty
          ? 'No preference history yet.'
          : 'Inferred from ${relevant.length} behavior signals.',
    );
  }

  Map<String, String> recurringSubstitutions(
    List<ExercisePreferenceEvent> events,
  ) {
    final counts = <String, Map<String, int>>{};
    for (final event in events.where(
      (event) =>
          event.signal == ExercisePreferenceSignal.replaced &&
          event.replacementExerciseId != null,
    )) {
      final targets = counts.putIfAbsent(event.exerciseId, () => {});
      targets[event.replacementExerciseId!] =
          (targets[event.replacementExerciseId!] ?? 0) + 1;
    }
    final result = <String, String>{};
    for (final entry in counts.entries) {
      final ranked = entry.value.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (ranked.first.value >= 2) result[entry.key] = ranked.first.key;
    }
    return result;
  }
}
