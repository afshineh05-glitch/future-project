enum SupplementRelevanceReason {
  muscleGoal,
  strengthTraining,
  highTrainingVolume,
  demandingWorkout,
  prolongedWorkout,
  higherProteinTarget,
  plantBasedDiet,
  limitedFishExposure,
  hydrationDemand,
  performanceGoal,
  experiencedTraining,
  todayProteinSupportingContext,
  recurringProteinGap,
  reliableClinicalContext,
}

enum SupplementCategory { performance, proteinSupport, essentialNutrient }

enum SupplementPriority { relevant, high }

enum SupplementGuidanceStatus {
  recommended,
  usefulWhenNeeded,
  worthConsidering,
  generalConsideration,
  contextDependent,
}

class SupplementGuidance {
  final String what;
  final String why;
  final String foodFirst;
  final String? generalUse;
  final String? caution;

  const SupplementGuidance({
    required this.what,
    required this.why,
    required this.foodFirst,
    required this.generalUse,
    required this.caution,
  });
}

class SmartSupplementRecommendation {
  final String id;
  final String name;
  final SupplementGuidance guidance;
  final String whyForYou;
  final List<SupplementRelevanceReason> reasons;
  final double relevanceScore;
  final SupplementCategory category;
  final SupplementPriority priority;
  final SupplementGuidanceStatus status;
  final List<String> benefits;
  final String? coachTip;

  const SmartSupplementRecommendation({
    required this.id,
    required this.name,
    required this.guidance,
    required this.whyForYou,
    required this.reasons,
    required this.relevanceScore,
    required this.category,
    required this.priority,
    required this.status,
    required this.benefits,
    required this.coachTip,
  });
}
