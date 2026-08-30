// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:future_project/models/adaptive_training.dart';

class MuscleRecoveryService {
  const MuscleRecoveryService();

  List<MuscleRecoveryState> estimate(
    List<ExercisePerformance> history, {
    DateTime? now,
    Map<String, double> userFeedback = const {},
  }) {
    final clock = now ?? DateTime.now();
    final byMuscle = <String, List<ExercisePerformance>>{};
    for (final item in history.where(
      (item) => item.status != ExerciseCompletionStatus.skipped,
    )) {
      for (final muscle in item.primaryMuscles) {
        byMuscle.putIfAbsent(muscle, () => []).add(item);
      }
    }
    return byMuscle.entries.map((entry) {
      final sessions = entry.value..sort((a, b) => b.date.compareTo(a.date));
      final latest = sessions.first;
      final hours = clock.difference(latest.date).inMinutes / 60;
      final recent = sessions
          .where((item) => clock.difference(item.date).inHours <= 72)
          .toList();
      final volume = recent.fold<int>(
        0,
        (sum, item) => sum + item.completedSets,
      );
      var score = (hours / 72).clamp(0.0, 1.0);
      if (volume >= 12)
        score -= 0.25;
      else if (volume >= 8)
        score -= 0.12;
      if (recent.length >= 2) score -= 0.15;
      final feedback = userFeedback[entry.key];
      if (feedback != null) score = score * 0.7 + feedback.clamp(0, 1) * 0.3;
      score = score.clamp(0, 1);
      final readiness = score < 0.35
          ? MuscleReadiness.fatigued
          : score < 0.7
          ? MuscleReadiness.moderate
          : MuscleReadiness.ready;
      final detail = volume >= 12
          ? 'heavy volume ($volume completed sets)'
          : '$volume completed sets';
      return MuscleRecoveryState(
        muscle: entry.key,
        readiness: readiness,
        score: score,
        reason:
            'Training readiness estimate: last trained ${hours.round()} hours ago with $detail in the last 72 hours. This is not a medical measurement.',
      );
    }).toList()..sort((a, b) => a.score.compareTo(b.score));
  }
}
