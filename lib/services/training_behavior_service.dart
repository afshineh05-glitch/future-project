// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:future_project/models/adaptive_training.dart';

class TrainingBehaviorService {
  const TrainingBehaviorService();
  List<AdherencePattern> detect(
    List<WorkoutObservation> history, {
    DateTime? now,
  }) {
    if (history.length < 3) return const [];
    final patterns = <AdherencePattern>[];
    for (var weekday = 1; weekday <= 7; weekday++) {
      final days = history
          .where((item) => item.scheduledAt.weekday == weekday)
          .toList();
      if (days.length >= 3) {
        final completed = days.where((item) => item.completed).length;
        if (completed / days.length <= 0.34)
          patterns.add(
            AdherencePattern(
              type: AdherencePatternType.missedWeekday,
              explanation:
                  '${_weekday(weekday)} was missed in ${days.length - completed} of ${days.length} observed sessions.',
              observations: days.length,
            ),
          );
        if (completed / days.length >= 0.8 && days.length >= 5)
          patterns.add(
            AdherencePattern(
              type: AdherencePatternType.strongWeekday,
              explanation:
                  '${_weekday(weekday)} sessions were completed $completed of ${days.length} times.',
              observations: days.length,
            ),
          );
      }
    }
    final completed = history.where((item) => item.completed).toList();
    final shortened = completed
        .where(
          (item) =>
              item.actualDurationMinutes != null &&
              item.actualDurationMinutes! <= item.plannedDurationMinutes * 0.75,
        )
        .length;
    if (completed.length >= 4 &&
        shortened >= 3 &&
        shortened / completed.length >= 0.5)
      patterns.add(
        AdherencePattern(
          type: AdherencePatternType.shortenedWorkouts,
          explanation:
              '$shortened of ${completed.length} completed sessions ended at least 25% early.',
          observations: completed.length,
        ),
      );
    final substituted = history.where((item) => item.substitutions > 0).length;
    if (history.length >= 4 &&
        substituted >= 3 &&
        substituted / history.length >= 0.5)
      patterns.add(
        AdherencePattern(
          type: AdherencePatternType.frequentSubstitutions,
          explanation:
              'Exercises were substituted in $substituted of ${history.length} sessions.',
          observations: history.length,
        ),
      );
    final sorted = [...completed]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].scheduledAt.difference(sorted[i - 1].scheduledAt).inDays >=
              10 &&
          (now ?? DateTime.now()).difference(sorted[i].scheduledAt).inDays <=
              14) {
        patterns.add(
          AdherencePattern(
            type: AdherencePatternType.returnedAfterGap,
            explanation:
                'Training resumed after a gap of ${sorted[i].scheduledAt.difference(sorted[i - 1].scheduledAt).inDays} days.',
            observations: sorted.length,
          ),
        );
        break;
      }
    }
    if (history.length >= 6 && completed.length / history.length >= 0.8)
      patterns.add(
        AdherencePattern(
          type: AdherencePatternType.consistentSessions,
          explanation:
              '${completed.length} of ${history.length} planned sessions were completed.',
          observations: history.length,
        ),
      );
    return patterns;
  }

  String _weekday(int value) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][value - 1];
}
