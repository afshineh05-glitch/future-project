import 'package:future_project/models/adaptive_training.dart';
import 'package:future_project/models/behavior_pattern.dart';
import 'package:future_project/services/behavior_pattern_learning_engine.dart';

class TrainingBehaviorService {
  final BehaviorPatternLearningEngine _engine;

  const TrainingBehaviorService({
    BehaviorPatternLearningEngine engine =
        const BehaviorPatternLearningEngine(),
  }) : _engine = engine;

  /// Compatibility adapter for Adaptive Training. Shared adherence rules are
  /// owned by BehaviorPatternLearningEngine; only the pre-existing
  /// substitutions signal and recent-return event remain local to this view.
  List<AdherencePattern> detect(
    List<WorkoutObservation> history, {
    DateTime? now,
  }) {
    if (history.length < 3) return const [];
    final effectiveNow =
        now ??
        history
            .map((item) => item.scheduledAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    final evaluated = _engine.evaluate(
      BehaviorPatternLearningInput(
        now: effectiveNow,
        training: history
            .map(
              (item) => BehaviorTrainingSignal(
                scheduledAt: item.scheduledAt,
                completed: item.completed,
                plannedDurationMinutes: item.plannedDurationMinutes,
                actualDurationMinutes: item.actualDurationMinutes,
              ),
            )
            .toList(growable: false),
      ),
    );
    final patterns = evaluated
        // Adaptive Training historically required five observations for a
        // strong weekday; retain that UI contract while sharing detection.
        .where(
          (item) =>
              item.type != BehaviorPatternType.strongTrainingWeekday ||
              item.observations >= 5,
        )
        .map(_adaptivePattern)
        .nonNulls
        .toList();

    final completed = history.where((item) => item.completed).toList();
    final substituted = history.where((item) => item.substitutions > 0).length;
    if (history.length >= 4 &&
        substituted >= 3 &&
        substituted / history.length >= 0.5) {
      patterns.add(
        AdherencePattern(
          type: AdherencePatternType.frequentSubstitutions,
          explanation:
              'Exercises were substituted in $substituted of ${history.length} sessions.',
          observations: history.length,
        ),
      );
    }
    final sorted = [...completed]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (!patterns.any(
      (item) => item.type == AdherencePatternType.returnedAfterGap,
    )) {
      for (var i = 1; i < sorted.length; i++) {
        final gap = sorted[i].scheduledAt
            .difference(sorted[i - 1].scheduledAt)
            .inDays;
        if (gap >= 10 &&
            effectiveNow.difference(sorted[i].scheduledAt).inDays <= 14) {
          patterns.add(
            AdherencePattern(
              type: AdherencePatternType.returnedAfterGap,
              explanation: 'Training resumed after a gap of $gap days.',
              observations: sorted.length,
            ),
          );
          break;
        }
      }
    }
    return patterns;
  }

  AdherencePattern? _adaptivePattern(BehaviorPattern pattern) {
    final type = switch (pattern.type) {
      BehaviorPatternType.missedTrainingWeekday =>
        AdherencePatternType.missedWeekday,
      BehaviorPatternType.strongTrainingWeekday =>
        AdherencePatternType.strongWeekday,
      BehaviorPatternType.shortenedWorkouts =>
        AdherencePatternType.shortenedWorkouts,
      BehaviorPatternType.returnAfterGap =>
        AdherencePatternType.returnedAfterGap,
      BehaviorPatternType.consistentRoutine =>
        AdherencePatternType.consistentSessions,
      _ => null,
    };
    return type == null
        ? null
        : AdherencePattern(
            type: type,
            explanation: pattern.coachHint,
            observations: pattern.observations,
          );
  }
}
