import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:future_project/services/vision_progress_engine.dart';

class VisionMilestonesEngine {
  final VisionProgressEngine progressEngine;

  const VisionMilestonesEngine({
    this.progressEngine = const VisionProgressEngine(),
  });

  VisionMilestonesState evaluate(VisionProgressInput input) {
    final completedSessions =
        input.trainingSessions
            .where(
              (item) => item.status == VisionTrainingSessionStatus.completed,
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final activeDates = _distinctDates(
      completedSessions.map((item) => item.scheduledAt),
    );
    final nutritionDates = _distinctDates(input.nutritionActiveDates);
    final progress = progressEngine.evaluate(input);
    final milestones = <VisionMilestone>[
      ..._thresholdMilestones(
        category: VisionMilestoneCategory.training,
        source: VisionMilestoneSource.workoutHistory,
        prefix: 'workouts',
        noun: 'Workout',
        thresholds: const [1, 5, 10, 25, 50],
        currentValue: completedSessions.length,
        completedDates: completedSessions
            .map((item) => item.completedAt ?? item.scheduledAt)
            .toList(),
        priority: 100,
      ),
      ..._thresholdMilestones(
        category: VisionMilestoneCategory.consistency,
        source: VisionMilestoneSource.activeTrainingDays,
        prefix: 'active-training-days',
        noun: 'Active Training Day',
        thresholds: const [7, 14, 30],
        currentValue: activeDates.length,
        completedDates: activeDates,
        priority: 80,
      ),
      if (input.bodyProgressChecks.isNotEmpty)
        ..._bodyMilestones(input, progress),
      if (input.nutritionLogCount > 0)
        ..._thresholdMilestones(
          category: VisionMilestoneCategory.nutrition,
          source: VisionMilestoneSource.nutritionHistory,
          prefix: 'nutrition-days',
          noun: 'Nutrition Day',
          thresholds: const [1, 7, 30],
          currentValue: nutritionDates.length,
          completedDates: nutritionDates,
          priority: 30,
        ),
    ];
    final next = _selectNext(milestones);
    return VisionMilestonesState(
      milestones: List.unmodifiable(milestones),
      nextMilestone: next,
    );
  }

  List<VisionMilestone> _thresholdMilestones({
    required VisionMilestoneCategory category,
    required VisionMilestoneSource source,
    required String prefix,
    required String noun,
    required List<int> thresholds,
    required int currentValue,
    required List<DateTime> completedDates,
    required int priority,
  }) {
    final firstIncomplete = thresholds.indexWhere(
      (threshold) => currentValue < threshold,
    );
    return List.generate(thresholds.length, (index) {
      final target = thresholds[index];
      final completed = currentValue >= target;
      final status = completed
          ? VisionMilestoneStatus.completed
          : index == firstIncomplete
          ? VisionMilestoneStatus.inProgress
          : VisionMilestoneStatus.locked;
      final pluralNoun = target == 1 ? noun : '${noun}s';
      return VisionMilestone(
        id: '$prefix-$target',
        category: category,
        title: '$target $pluralNoun',
        description: completed
            ? 'Completed from your verified activity history.'
            : 'Keep showing up to reach $target ${pluralNoun.toLowerCase()}.',
        currentValue: currentValue.toDouble(),
        targetValue: target.toDouble(),
        normalizedProgress: (currentValue / target).clamp(0.0, 1.0),
        status: status,
        completedAt: completed && completedDates.length >= target
            ? completedDates[target - 1]
            : null,
        priority: priority,
        source: source,
      );
    });
  }

  List<VisionMilestone> _bodyMilestones(
    VisionProgressInput input,
    VisionProgress progress,
  ) {
    final checks = [...input.bodyProgressChecks]
      ..sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
    final bodySignals = progress.signals.where(
      (item) => item.type == VisionProgressSignalType.bodyProgress,
    );
    final bodySignal = bodySignals.isEmpty ? null : bodySignals.first;
    final items = _thresholdMilestones(
      category: VisionMilestoneCategory.bodyProgress,
      source: VisionMilestoneSource.bodyProgressChecks,
      prefix: 'body-progress-checks',
      noun: 'Body Progress Check',
      thresholds: const [1, 2],
      currentValue: checks.length,
      completedDates: checks.map((item) => item.checkedAt).toList(),
      priority: 110,
    );
    if (bodySignal != null) {
      final score = bodySignal.normalizedValue;
      items.add(
        VisionMilestone(
          id: 'meaningful-body-improvement',
          category: VisionMilestoneCategory.bodyProgress,
          title: 'Meaningful Measurement Improvement',
          description:
              'A verified change toward your goal from repeated Body Progress checks.',
          currentValue: score,
          targetValue: 0.25,
          normalizedProgress: (score / 0.25).clamp(0.0, 1.0),
          status: score >= 0.25
              ? VisionMilestoneStatus.completed
              : VisionMilestoneStatus.inProgress,
          completedAt: score >= 0.25 ? checks.last.checkedAt : null,
          priority: 115,
          source: VisionMilestoneSource.bodyProgressChecks,
        ),
      );
    }
    return items;
  }

  VisionMilestone? _selectNext(List<VisionMilestone> milestones) {
    final candidates = milestones
        .where((item) => item.status == VisionMilestoneStatus.inProgress)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final scoreComparison = _selectionScore(b).compareTo(_selectionScore(a));
      if (scoreComparison != 0) return scoreComparison;
      final targetComparison = a.targetValue.compareTo(b.targetValue);
      if (targetComparison != 0) return targetComparison;
      return a.id.compareTo(b.id);
    });
    return candidates.first;
  }

  double _selectionScore(VisionMilestone milestone) {
    final dataStrength = switch (milestone.source) {
      VisionMilestoneSource.bodyProgressChecks => 10,
      VisionMilestoneSource.workoutHistory => 10,
      VisionMilestoneSource.activeTrainingDays => 8,
      VisionMilestoneSource.exercisePerformance => 9,
      VisionMilestoneSource.nutritionHistory => 5,
    };
    final remainingRatio = 1 - milestone.normalizedProgress;
    return milestone.priority +
        milestone.normalizedProgress * 25 +
        dataStrength -
        remainingRatio * 5;
  }

  List<DateTime> _distinctDates(Iterable<DateTime> dates) {
    final result = <String, DateTime>{};
    for (final date in dates) {
      final local = date.toLocal();
      result['${local.year}-${local.month}-${local.day}'] = DateTime(
        local.year,
        local.month,
        local.day,
      );
    }
    final values = result.values.toList()..sort();
    return values;
  }
}
