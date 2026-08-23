import 'package:future_project/models/smart_supplement.dart';

enum SupplementRuleSignal {
  muscleGoal,
  performanceGoal,
  enduranceGoal,
  regularStrengthTraining,
  trainingAtLeastThreeDays,
  highTrainingVolume,
  experiencedTraining,
  usualDemandingTraining,
  highProteinTarget,
  reliableRecurringProteinGap,
  plantBasedDiet,
  limitedFishExposure,
  acuteLongDemandingWorkout,
  acuteDemandingWorkout,
  acuteLongWorkout,
  higherHydrationTarget,
  reliableVitaminDSupport,
  reliableMagnesiumSupport,
}

class SupplementScoringRule {
  final SupplementRuleSignal signal;
  final double points;
  final SupplementRelevanceReason reason;

  const SupplementScoringRule(this.signal, this.points, this.reason);
}

class SupplementCatalogEntry {
  final String id;
  final String name;
  final SupplementCategory category;
  final List<String> evidenceUseCases;
  final List<SupplementScoringRule> stableRules;
  final List<SupplementScoringRule> acuteRules;
  final double visibilityThreshold;
  final List<String> benefits;
  final SupplementGuidance guidance;
  final String? coachTip;
  final Set<String> restrictionTerms;
  final bool plantOnly;

  const SupplementCatalogEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.evidenceUseCases,
    required this.stableRules,
    required this.acuteRules,
    required this.visibilityThreshold,
    required this.benefits,
    required this.guidance,
    required this.coachTip,
    this.restrictionTerms = const {},
    this.plantOnly = false,
  });
}
