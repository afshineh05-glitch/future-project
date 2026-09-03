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

  /// Personalizes presentation around canonical milestone results without
  /// changing completion, progress, or locking rules.
  VisionMilestonesState personalize(
    VisionMilestonesState canonical,
    VisionMilestonePersonalizationContext context,
  ) {
    final personalized = canonical.milestones
        .map((item) => _personalizedCopy(item, context))
        .toList(growable: false);
    final candidates =
        personalized
            .where((item) => item.status == VisionMilestoneStatus.inProgress)
            .toList()
          ..sort((a, b) {
            final score = _personalizedScore(
              b,
              context,
            ).compareTo(_personalizedScore(a, context));
            if (score != 0) return score;
            return a.id.compareTo(b.id);
          });
    final next = candidates.firstOrNull;
    final visible = _visibleJourney(personalized, candidates, next);
    return VisionMilestonesState(
      milestones: canonical.milestones,
      visibleMilestones: List.unmodifiable(visible),
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
    if (bodySignal != null && bodySignal.normalizedValue > 0) {
      final score = bodySignal.normalizedValue;
      items.add(
        VisionMilestone(
          id: 'meaningful-body-improvement',
          category: VisionMilestoneCategory.bodyTransformation,
          title: 'Meaningful Measurement Improvement',
          description:
              'A verified change toward your goal from your Foundation baseline.',
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

  VisionMilestone _personalizedCopy(
    VisionMilestone milestone,
    VisionMilestonePersonalizationContext context,
  ) {
    if (milestone.status == VisionMilestoneStatus.completed) {
      return milestone.copyWith(
        description: 'Completed from your verified activity history.',
      );
    }
    if (milestone.id == 'body-progress-checks-2' &&
        milestone.currentValue == 1) {
      return milestone.copyWith(
        title: 'Complete your next Body Progress Check',
        description:
            'Your second check will create your first comparison between recorded check periods.',
      );
    }
    if (milestone.id.startsWith('workouts-')) {
      final remaining = (milestone.targetValue - milestone.currentValue).ceil();
      return milestone.copyWith(
        title: remaining == 1
            ? 'Complete your next workout'
            : 'Build toward ${milestone.targetValue.round()} completed workouts',
        description: context.returnedAfterGap
            ? 'You have already returned. Another completed session will rebuild your recorded training pattern.'
            : '$remaining verified ${remaining == 1 ? 'session remains' : 'sessions remain'} to reach this training milestone.',
      );
    }
    if (milestone.id.startsWith('active-training-days-')) {
      final remaining = (milestone.targetValue - milestone.currentValue).ceil();
      return milestone.copyWith(
        title: 'Train on ${milestone.targetValue.round()} different days',
        description:
            '$remaining more verified training ${remaining == 1 ? 'day will' : 'days will'} strengthen your consistency signal.',
      );
    }
    if (milestone.id.startsWith('nutrition-days-')) {
      final remaining = (milestone.targetValue - milestone.currentValue).ceil();
      return milestone.copyWith(
        title: 'Record ${milestone.targetValue.round()} nutrition days',
        description:
            '$remaining more recorded ${remaining == 1 ? 'day will' : 'days will'} strengthen the nutrition evidence behind your goal.',
      );
    }
    if (milestone.id == 'meaningful-body-improvement') {
      return milestone.copyWith(
        title: 'Continue verified body change',
        description:
            'Your recorded measurements already show movement toward your goal.',
      );
    }
    return milestone;
  }

  List<VisionMilestone> _visibleJourney(
    List<VisionMilestone> all,
    List<VisionMilestone> rankedCandidates,
    VisionMilestone? next,
  ) {
    final visibleIds = <String>{};
    final visible = <VisionMilestone>[];
    void add(VisionMilestone item) {
      if (visibleIds.add(item.id)) visible.add(item);
    }

    // Preserve every completed achievement in the user-facing history.
    for (final item in all.where(
      (item) => item.status == VisionMilestoneStatus.completed,
    )) {
      add(item);
    }
    if (next != null) add(next);

    // Show the strongest current item from other supported categories.
    final represented = <VisionMilestoneCategory>{};
    if (next != null) represented.add(next.category);
    for (final item in rankedCandidates) {
      if (represented.add(item.category)) add(item);
    }

    // Retain only the immediate locked step after a visible current item.
    for (final category in VisionMilestoneCategory.values) {
      final categoryItems = all
          .where((item) => item.category == category)
          .toList();
      final currentIndex = categoryItems.indexWhere(
        (item) => item.status == VisionMilestoneStatus.inProgress,
      );
      if (currentIndex >= 0 && currentIndex + 1 < categoryItems.length) {
        add(categoryItems[currentIndex + 1]);
      }
    }
    return visible;
  }

  double _personalizedScore(
    VisionMilestone milestone,
    VisionMilestonePersonalizationContext context,
  ) {
    final goal = context.primaryGoal.toLowerCase().trim().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final relevance = switch (goal) {
      'fat_loss' || 'lose_fat' => switch (milestone.category) {
        VisionMilestoneCategory.bodyTransformation => 42,
        VisionMilestoneCategory.bodyProgress => 30,
        VisionMilestoneCategory.nutrition => 24,
        VisionMilestoneCategory.consistency => 12,
        VisionMilestoneCategory.training => 8,
        VisionMilestoneCategory.strength => 0,
      },
      'build_muscle' ||
      'muscle_gain' ||
      'become_stronger' => switch (milestone.category) {
        VisionMilestoneCategory.strength => 45,
        VisionMilestoneCategory.training => 34,
        VisionMilestoneCategory.bodyTransformation => 28,
        VisionMilestoneCategory.consistency => 22,
        VisionMilestoneCategory.bodyProgress => 18,
        VisionMilestoneCategory.nutrition => 8,
      },
      _ => switch (milestone.category) {
        VisionMilestoneCategory.consistency => 34,
        VisionMilestoneCategory.training => 30,
        VisionMilestoneCategory.bodyProgress => 18,
        VisionMilestoneCategory.nutrition => 14,
        VisionMilestoneCategory.bodyTransformation => 12,
        VisionMilestoneCategory.strength => 10,
      },
    };
    final proximity = milestone.normalizedProgress * 45;
    final recent = switch (milestone.category) {
      VisionMilestoneCategory.training ||
      VisionMilestoneCategory.consistency => context.hasRecentTraining ? 12 : 0,
      VisionMilestoneCategory.nutrition => context.hasRecentNutrition ? 10 : 0,
      _ => 0,
    };
    final returning =
        context.returnedAfterGap &&
            milestone.category == VisionMilestoneCategory.training
        ? 38
        : 0;
    return relevance + proximity + recent + returning + milestone.priority / 20;
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
