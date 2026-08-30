// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:future_project/models/adaptive_training.dart';

class ExerciseProgressionService {
  const ExerciseProgressionService();

  ProgressionRecommendation recommend(
    String exerciseId,
    List<ExercisePerformance> history,
  ) {
    final recent =
        history.where((item) => item.exerciseId == exerciseId).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final sample = recent.take(3).toList();
    if (sample.length < 2)
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        action: ProgressionAction.maintain,
        reason: 'Not enough training history yet.',
        observations: sample.length,
      );

    final replacements = sample
        .where(
          (item) =>
              item.substitutedFromExerciseId == exerciseId ||
              item.status == ExerciseCompletionStatus.skipped,
        )
        .length;
    if (replacements >= 2)
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        action: ProgressionAction.changeExercise,
        reason:
            'This exercise was skipped or replaced in at least two of the last three opportunities.',
        observations: sample.length,
      );

    final failures = sample
        .where(
          (item) =>
              item.status != ExerciseCompletionStatus.completed ||
              item.completedSets < item.plannedSets,
        )
        .length;
    final falling =
        sample.length == 3 &&
        _performance(sample[0]) < _performance(sample[1]) &&
        _performance(sample[1]) < _performance(sample[2]);
    if (failures >= 2 && falling)
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        action: ProgressionAction.deloadConsideration,
        reason:
            'Performance declined across three sessions with repeated incomplete work; inspect recovery before progressing.',
        observations: sample.length,
      );
    if (failures >= 2)
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        action: ProgressionAction.reduceVolume,
        reason: 'At least two recent sessions had incomplete planned volume.',
        observations: sample.length,
      );

    final topRange = sample.every(
      (item) =>
          item.targetRepMax != null &&
          item.completedSets >= item.plannedSets &&
          item.sets
              .where((set) => set.completed)
              .every((set) => set.reps >= item.targetRepMax!) &&
          (item.perceivedDifficulty == null || item.perceivedDifficulty! <= 8),
    );
    if (topRange) {
      final load = sample.first.averageLoad;
      if (load != null && load > 0) {
        final increment = load < 20
            ? 1
            : load < 60
            ? 2.5
            : 5;
        final cap = load * 1.05;
        return ProgressionRecommendation(
          exerciseId: exerciseId,
          action: ProgressionAction.increaseLoad,
          reason:
              'The top of the rep range was completed twice with acceptable effort; use the smaller of the standard increment or 5%.',
          suggestedLoad: _roundToHalf((load + increment).clamp(load, cap)),
          observations: sample.length,
        );
      }
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        action: ProgressionAction.increaseReps,
        reason:
            'The prescribed work was completed twice at the top of the rep range; add one rep per set before adding load.',
        observations: sample.length,
      );
    }
    return ProgressionRecommendation(
      exerciseId: exerciseId,
      action: ProgressionAction.maintain,
      reason:
          'Recent work was completed, but there is not yet repeated top-of-range performance.',
      observations: sample.length,
    );
  }

  double _performance(ExercisePerformance item) =>
      item.completedSets * 100 +
      item.sets
          .where((set) => set.completed)
          .fold(0, (sum, set) => sum + set.reps) +
      (item.averageLoad ?? 0);
  double _roundToHalf(num value) => (value * 2).floor() / 2;
}
