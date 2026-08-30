enum VisionMilestoneCategory {
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
}

class VisionMilestonesState {
  final List<VisionMilestone> milestones;
  final VisionMilestone? nextMilestone;

  const VisionMilestonesState({
    required this.milestones,
    required this.nextMilestone,
  });

  List<VisionMilestone> forCategory(VisionMilestoneCategory category) =>
      milestones.where((item) => item.category == category).toList();
}
