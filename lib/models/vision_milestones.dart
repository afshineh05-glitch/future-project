enum VisionMilestoneCategory {
  bodyTransformation,
  training,
  consistency,
  bodyProgress,
  strength,
  nutrition,
}

enum VisionMilestoneStatus { completed, inProgress, locked }

enum VisionMilestoneSource {
  workoutHistory,
  activeTrainingDays,
  bodyProgressChecks,
  exercisePerformance,
  nutritionHistory,
}

class VisionMilestone {
  final String id;
  final VisionMilestoneCategory category;
  final String title;
  final String description;
  final double currentValue;
  final double targetValue;
  final double normalizedProgress;
  final VisionMilestoneStatus status;
  final DateTime? completedAt;
  final int priority;
  final VisionMilestoneSource source;

  const VisionMilestone({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.currentValue,
    required this.targetValue,
    required this.normalizedProgress,
    required this.status,
    this.completedAt,
    required this.priority,
    required this.source,
  });

  VisionMilestone copyWith({
    String? title,
    String? description,
    int? priority,
  }) => VisionMilestone(
    id: id,
    category: category,
    title: title ?? this.title,
    description: description ?? this.description,
    currentValue: currentValue,
    targetValue: targetValue,
    normalizedProgress: normalizedProgress,
    status: status,
    completedAt: completedAt,
    priority: priority ?? this.priority,
    source: source,
  );
}

class VisionMilestonesState {
  /// Complete canonical tracking history, including future thresholds.
  final List<VisionMilestone> milestones;

  /// Curated, personalized milestones intended for the categorized UI.
  final List<VisionMilestone> visibleMilestones;
  final VisionMilestone? nextMilestone;

  const VisionMilestonesState({
    required this.milestones,
    List<VisionMilestone>? visibleMilestones,
    required this.nextMilestone,
  }) : visibleMilestones = visibleMilestones ?? milestones;

  List<VisionMilestone> forCategory(VisionMilestoneCategory category) =>
      visibleMilestones.where((item) => item.category == category).toList();
}

class VisionMilestonePersonalizationContext {
  final String primaryGoal;
  final bool returnedAfterGap;
  final bool hasRecentTraining;
  final bool hasRecentNutrition;

  const VisionMilestonePersonalizationContext({
    required this.primaryGoal,
    this.returnedAfterGap = false,
    this.hasRecentTraining = false,
    this.hasRecentNutrition = false,
  });
}
