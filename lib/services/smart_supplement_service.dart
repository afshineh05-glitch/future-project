import 'package:future_project/models/nutrition_food_log.dart';
import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/models/performance_fuel.dart';
import 'package:future_project/models/recovery_nutrition.dart';
import 'package:future_project/models/smart_supplement.dart';
import 'package:future_project/models/supplement_catalog.dart';

class SmartSupplementService {
  const SmartSupplementService();

  List<SmartSupplementRecommendation> recommend({
    required NutritionProfile profile,
    required PerformanceFuel fuel,
    required NutritionFoodDay consumedToday,
    required RecoveryNutritionContext recoveryContext,
    required RecoveryWorkoutSource recoverySource,
    required RecoveryWorkout? selectedWorkout,
    int limit = 7,
  }) {
    final context = _SupplementContext.from(
      profile: profile,
      fuel: fuel,
      recoveryContext: recoveryContext,
      recoverySource: recoverySource,
      selectedWorkout: selectedWorkout,
    );

    // A single day is not a reliable recurring intake pattern. Keep the input
    // in the API so a multi-day aggregate can replace it without changing UI.
    final _ = consumedToday;
    final recommendations = <SmartSupplementRecommendation>[];

    for (final entry in _catalog) {
      if (!_isEligible(entry, context, profile)) continue;
      var score = 0.0;
      final reasons = <SupplementRelevanceReason>[];
      for (final rule in [...entry.stableRules, ...entry.acuteRules]) {
        if (!context.has(rule.signal)) continue;
        score += rule.points;
        reasons.add(rule.reason);
      }
      if (score < entry.visibilityThreshold) continue;

      recommendations.add(
        SmartSupplementRecommendation(
          id: entry.id,
          name: entry.name,
          category: entry.category,
          priority: score >= 4
              ? SupplementPriority.high
              : SupplementPriority.relevant,
          status: _statusFor(entry.id, context, score),
          guidance: entry.guidance,
          whyForYou: _whyForYou(entry.id, context),
          benefits: entry.benefits,
          coachTip: entry.coachTip,
          reasons: List.unmodifiable({...reasons}),
          relevanceScore: score,
        ),
      );
    }

    recommendations.sort((a, b) {
      final statusOrder = _statusRank(a).compareTo(_statusRank(b));
      if (statusOrder != 0) return statusOrder;
      return b.relevanceScore.compareTo(a.relevanceScore);
    });
    return recommendations.take(limit).toList(growable: false);
  }

  int _statusRank(SmartSupplementRecommendation item) => switch (item.status) {
    SupplementGuidanceStatus.recommended => 0,
    SupplementGuidanceStatus.usefulWhenNeeded => 1,
    SupplementGuidanceStatus.worthConsidering => 2,
    SupplementGuidanceStatus.generalConsideration => 3,
    SupplementGuidanceStatus.contextDependent => item.id == 'caffeine' ? 5 : 4,
  };

  SupplementGuidanceStatus _statusFor(
    String id,
    _SupplementContext context,
    double score,
  ) => switch (id) {
    'creatine_monohydrate' => SupplementGuidanceStatus.recommended,
    'whey_protein' ||
    'plant_protein' => SupplementGuidanceStatus.usefulWhenNeeded,
    'omega_3' => SupplementGuidanceStatus.worthConsidering,
    'vitamin_d' => SupplementGuidanceStatus.generalConsideration,
    'magnesium' => SupplementGuidanceStatus.worthConsidering,
    'electrolytes' =>
      context.acuteLongDemanding
          ? SupplementGuidanceStatus.usefulWhenNeeded
          : SupplementGuidanceStatus.contextDependent,
    'caffeine' => SupplementGuidanceStatus.contextDependent,
    _ =>
      score >= 3
          ? SupplementGuidanceStatus.recommended
          : SupplementGuidanceStatus.contextDependent,
  };

  bool _isEligible(
    SupplementCatalogEntry entry,
    _SupplementContext context,
    NutritionProfile profile,
  ) {
    if (entry.plantOnly && !context.plantBased) return false;
    if (entry.id == 'whey_protein' && context.plantBased) return false;
    if (_containsRestriction(profile, entry.restrictionTerms)) return false;
    return true;
  }

  String _whyForYou(String id, _SupplementContext context) {
    final level = context.trainingLevel.isEmpty
        ? 'current'
        : context.trainingLevel;
    return switch (id) {
      'creatine_monohydrate' =>
        'Your $level training level, ${context.trainingDays}-day training week, ${context.regularStrength ? 'regular strength-focused training' : 'established training pattern'}, and ${context.goalLabel} goal make creatine especially relevant.',
      'whey_protein' =>
        'Your daily protein target is ${context.proteinTargetG} g. Whey can be convenient on days when your usual meals fall short; meeting today\'s target means it is not required today.',
      'plant_protein' =>
        'Your plant-based profile and ${context.proteinTargetG} g protein target make plant protein convenient on days when your usual meals fall short.',
      'omega_3' =>
        context.plantBased
            ? 'Your plant-based diet may provide less preformed EPA and DHA, making an algae-derived option worth considering.'
            : context.limitedFish
            ? 'Your saved restrictions limit common oily-fish sources of EPA and DHA.'
            : 'Your available profile does not establish omega-3 intake, so this is a general consideration rather than an identified need.',
      'electrolytes' =>
        context.acuteLongDemanding
            ? 'Today\'s ${context.workoutDurationMinutes}-minute, ${context.workoutIntensityLabel} session creates a meaningful electrolyte replacement context.'
            : context.workoutDurationMinutes == 0
            ? 'Today has no active workout recovery demand, so electrolytes are contextual guidance for future long, hard, hot, or high-sweat sessions.'
            : 'Your current ${context.workoutDurationMinutes}-minute, ${context.workoutIntensityLabel} workout does not create a strong acute electrolyte need, but your hydration and weekly training context make them useful for harder or high-sweat sessions.',
      'caffeine' =>
        context.acuteDemanding
            ? 'Your ${context.goalLabel} goal and $level experience make caffeine an optional aid for today\'s demanding session.'
            : 'Your ${context.goalLabel} goal and $level experience make caffeine an optional performance aid, not a daily requirement.',
      'vitamin_d' =>
        'Vitamin D is shown as a general consideration because training data alone cannot determine your individual Vitamin D status or need.',
      'magnesium' =>
        'Your training and recovery context can make magnesium worth evaluating, but the app does not have evidence that your intake or status is low.',
      _ =>
        'Your saved training and nutrition context makes this worth considering.',
    };
  }

  bool _containsRestriction(NutritionProfile profile, Set<String> terms) {
    if (terms.isEmpty) return false;
    final restrictions =
        [
              ...profile.foodAllergies,
              ...profile.foodsToAvoid,
              ...profile.dislikedFoods,
            ]
            .map(_normalize)
            .where(
              (value) =>
                  value.isNotEmpty && value != 'none' && value != 'other',
            );
    return restrictions.any(
      (value) =>
          terms.any((term) => value.contains(term) || term.contains(value)),
    );
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  static bool _isStrength(String value) {
    final normalized = _normalize(value);
    return normalized.contains('strength') ||
        normalized.contains('resistance') ||
        normalized.contains('weight') ||
        normalized.contains('muscle') ||
        normalized.contains('hypertrophy') ||
        normalized.contains('chest') ||
        normalized.contains('back') ||
        normalized.contains('legs') ||
        normalized.contains('upper_body') ||
        normalized.contains('lower_body') ||
        normalized.contains('push') ||
        normalized.contains('pull') ||
        normalized.contains('full_body');
  }
}

class _SupplementContext {
  final String goal;
  final String trainingLevel;
  final int trainingDays;
  final bool plantBased;
  final bool muscleGoal;
  final bool performanceGoal;
  final bool enduranceGoal;
  final bool regularStrength;
  final bool experienced;
  final bool usualDemanding;
  final bool highProteinTarget;
  final bool reliableRecurringProteinGap;
  final bool limitedFish;
  final bool acuteLongDemanding;
  final bool acuteDemanding;
  final bool acuteLong;
  final bool higherHydrationTarget;
  final int proteinTargetG;
  final int workoutDurationMinutes;
  final String workoutIntensityLabel;
  final bool reliableVitaminDSupport;
  final bool reliableMagnesiumSupport;

  const _SupplementContext({
    required this.goal,
    required this.trainingLevel,
    required this.trainingDays,
    required this.plantBased,
    required this.muscleGoal,
    required this.performanceGoal,
    required this.enduranceGoal,
    required this.regularStrength,
    required this.experienced,
    required this.usualDemanding,
    required this.highProteinTarget,
    required this.reliableRecurringProteinGap,
    required this.limitedFish,
    required this.acuteLongDemanding,
    required this.acuteDemanding,
    required this.acuteLong,
    required this.higherHydrationTarget,
    required this.proteinTargetG,
    required this.workoutDurationMinutes,
    required this.workoutIntensityLabel,
    required this.reliableVitaminDSupport,
    required this.reliableMagnesiumSupport,
  });

  factory _SupplementContext.from({
    required NutritionProfile profile,
    required PerformanceFuel fuel,
    required RecoveryNutritionContext recoveryContext,
    required RecoveryWorkoutSource recoverySource,
    required RecoveryWorkout? selectedWorkout,
  }) {
    final goal = SmartSupplementService._normalize(
      recoveryContext.primaryGoal.isNotEmpty
          ? recoveryContext.primaryGoal
          : fuel.goal,
    );
    final diet = SmartSupplementService._normalize(profile.dietType);
    final plantBased = diet == 'vegan' || diet == 'vegetarian';
    final workout = recoverySource == RecoveryWorkoutSource.restDay
        ? null
        : selectedWorkout;
    final usualWorkout = recoveryContext.trainingPlanWorkout;
    final regularStrength =
        recoveryContext.regularStrengthTraining ||
        (usualWorkout != null &&
            (SmartSupplementService._isStrength(usualWorkout.type) ||
                SmartSupplementService._isStrength(usualWorkout.name)));
    final usualDemanding =
        usualWorkout != null && _isDemanding(usualWorkout.intensity);
    final acuteDemanding = workout != null && _isDemanding(workout.intensity);
    final restrictions = [
      ...profile.foodAllergies,
      ...profile.foodsToAvoid,
      ...profile.dislikedFoods,
    ].map(SmartSupplementService._normalize);

    return _SupplementContext(
      goal: goal,
      trainingLevel: SmartSupplementService._normalize(
        recoveryContext.trainingLevel,
      ),
      trainingDays: recoveryContext.trainingDaysPerWeek,
      plantBased: plantBased,
      muscleGoal: goal.contains('muscle') || goal.contains('strength'),
      performanceGoal:
          goal.contains('performance') || fuel.goal == 'athletic_performance',
      enduranceGoal: goal.contains('endurance'),
      regularStrength: regularStrength,
      experienced: {'intermediate', 'advanced'}.contains(
        SmartSupplementService._normalize(recoveryContext.trainingLevel),
      ),
      usualDemanding: usualDemanding,
      highProteinTarget:
          recoveryContext.weightKg > 0 &&
          fuel.proteinG / recoveryContext.weightKg >= 1.5,
      // Nutrition Home currently has today's total, not a reliable multi-day
      // adherence pattern. Keep false until such an aggregate is available.
      reliableRecurringProteinGap: false,
      limitedFish:
          plantBased ||
          restrictions.any(
            (value) => const [
              'fish',
              'seafood',
              'salmon',
            ].any((term) => value.contains(term)),
          ),
      acuteLongDemanding:
          workout != null && workout.durationMinutes >= 60 && acuteDemanding,
      acuteDemanding: acuteDemanding,
      acuteLong: workout != null && workout.durationMinutes >= 60,
      higherHydrationTarget: fuel.hydrationL >= 3,
      proteinTargetG: fuel.proteinG,
      workoutDurationMinutes: workout?.durationMinutes ?? 0,
      workoutIntensityLabel: workout == null
          ? 'rest-day'
          : workout.intensity.name.replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)!.toLowerCase()}',
            ),
      // Neither clinical results nor reliable long-term intake/exposure data
      // are available in the current context, so deficiency is never inferred.
      reliableVitaminDSupport: false,
      reliableMagnesiumSupport: false,
    );
  }

  String get goalLabel => goal.replaceAll('_', ' ');

  bool has(SupplementRuleSignal signal) => switch (signal) {
    SupplementRuleSignal.muscleGoal => muscleGoal,
    SupplementRuleSignal.performanceGoal => performanceGoal,
    SupplementRuleSignal.enduranceGoal => enduranceGoal,
    SupplementRuleSignal.regularStrengthTraining => regularStrength,
    SupplementRuleSignal.trainingAtLeastThreeDays => trainingDays >= 3,
    SupplementRuleSignal.highTrainingVolume => trainingDays >= 4,
    SupplementRuleSignal.experiencedTraining => experienced,
    SupplementRuleSignal.usualDemandingTraining => usualDemanding,
    SupplementRuleSignal.highProteinTarget => highProteinTarget,
    SupplementRuleSignal.reliableRecurringProteinGap =>
      reliableRecurringProteinGap,
    SupplementRuleSignal.plantBasedDiet => plantBased,
    SupplementRuleSignal.limitedFishExposure => limitedFish,
    SupplementRuleSignal.acuteLongDemandingWorkout => acuteLongDemanding,
    SupplementRuleSignal.acuteDemandingWorkout => acuteDemanding,
    SupplementRuleSignal.acuteLongWorkout => acuteLong,
    SupplementRuleSignal.higherHydrationTarget => higherHydrationTarget,
    SupplementRuleSignal.reliableVitaminDSupport => reliableVitaminDSupport,
    SupplementRuleSignal.reliableMagnesiumSupport => reliableMagnesiumSupport,
  };

  static bool _isDemanding(RecoveryWorkoutIntensity intensity) =>
      intensity == RecoveryWorkoutIntensity.hard ||
      intensity == RecoveryWorkoutIntensity.veryHard;
}

const _catalog = <SupplementCatalogEntry>[
  SupplementCatalogEntry(
    id: 'creatine_monohydrate',
    name: 'Creatine Monohydrate',
    category: SupplementCategory.performance,
    evidenceUseCases: ['Strength', 'Power', 'Repeated high-intensity exercise'],
    stableRules: [
      SupplementScoringRule(
        SupplementRuleSignal.muscleGoal,
        2,
        SupplementRelevanceReason.muscleGoal,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.regularStrengthTraining,
        2,
        SupplementRelevanceReason.strengthTraining,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.trainingAtLeastThreeDays,
        0.75,
        SupplementRelevanceReason.highTrainingVolume,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.performanceGoal,
        0.5,
        SupplementRelevanceReason.performanceGoal,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.experiencedTraining,
        0.25,
        SupplementRelevanceReason.experiencedTraining,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.usualDemandingTraining,
        0.25,
        SupplementRelevanceReason.demandingWorkout,
      ),
    ],
    acuteRules: [],
    visibilityThreshold: 3,
    benefits: ['Strength', 'Power', 'High-intensity performance'],
    guidance: SupplementGuidance(
      what: 'A compound involved in rapid energy production in muscle.',
      why: 'Can support strength, power, and repeated high-intensity exercise.',
      foodFirst: 'Creatine also occurs naturally in meat and fish.',
      generalUse: '3–5 g daily.',
      caution:
          'Discuss use with a clinician if you have kidney disease, are pregnant, or have relevant medical concerns.',
    ),
    coachTip:
        'Use it consistently to support your strength and performance training; timing matters less than daily use.',
  ),
  SupplementCatalogEntry(
    id: 'whey_protein',
    name: 'Whey Protein Powder',
    category: SupplementCategory.proteinSupport,
    evidenceUseCases: ['Convenient protein support'],
    stableRules: [
      SupplementScoringRule(
        SupplementRuleSignal.reliableRecurringProteinGap,
        2,
        SupplementRelevanceReason.recurringProteinGap,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.highProteinTarget,
        1,
        SupplementRelevanceReason.higherProteinTarget,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.muscleGoal,
        0.5,
        SupplementRelevanceReason.muscleGoal,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.performanceGoal,
        0.5,
        SupplementRelevanceReason.performanceGoal,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.trainingAtLeastThreeDays,
        0.5,
        SupplementRelevanceReason.highTrainingVolume,
      ),
    ],
    acuteRules: [],
    visibilityThreshold: 2,
    benefits: ['Convenience', 'Complete protein', 'Training support'],
    guidance: SupplementGuidance(
      what: 'A convenient dairy-derived source of complete protein.',
      why: 'Can help meet protein targets when meals are impractical.',
      foodFirst: 'Whole-food protein can remain the foundation.',
      generalUse: '20–40 g protein when needed to close a reliable gap.',
      caution: 'Avoid whey with a dairy allergy.',
    ),
    coachTip:
        'Keep it available for days when reaching your protein target through meals is inconvenient.',
    restrictionTerms: {'dairy', 'whey', 'milk'},
  ),
  SupplementCatalogEntry(
    id: 'plant_protein',
    name: 'Plant Protein Powder',
    category: SupplementCategory.proteinSupport,
    evidenceUseCases: ['Plant-based convenient protein support'],
    stableRules: [
      SupplementScoringRule(
        SupplementRuleSignal.plantBasedDiet,
        1.5,
        SupplementRelevanceReason.plantBasedDiet,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.highProteinTarget,
        1,
        SupplementRelevanceReason.higherProteinTarget,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.trainingAtLeastThreeDays,
        0.5,
        SupplementRelevanceReason.highTrainingVolume,
      ),
    ],
    acuteRules: [],
    visibilityThreshold: 3,
    benefits: ['Convenience', 'Plant-based protein', 'Training support'],
    guidance: SupplementGuidance(
      what: 'Concentrated protein made from pea, soy, rice, or blends.',
      why: 'Can provide convenient protein for plant-based eating patterns.',
      foodFirst: 'Legumes, tofu, tempeh, and varied grains provide protein.',
      generalUse: '20–40 g protein when convenient support is needed.',
      caution: 'Check the protein source against allergies and restrictions.',
    ),
    coachTip:
        'Keep it available for days when reaching your protein target is inconvenient; a blended protein can provide a broader amino-acid profile.',
    restrictionTerms: {'pea', 'soy', 'plant_protein'},
    plantOnly: true,
  ),
  SupplementCatalogEntry(
    id: 'omega_3',
    name: 'Omega-3',
    category: SupplementCategory.essentialNutrient,
    evidenceUseCases: ['EPA and DHA support'],
    stableRules: [
      SupplementScoringRule(
        SupplementRuleSignal.limitedFishExposure,
        2.5,
        SupplementRelevanceReason.limitedFishExposure,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.plantBasedDiet,
        0.75,
        SupplementRelevanceReason.plantBasedDiet,
      ),
    ],
    acuteRules: [],
    visibilityThreshold: 0,
    benefits: ['EPA and DHA', 'Cardiovascular support'],
    guidance: SupplementGuidance(
      what: 'EPA and DHA fats supplied by fish oil or algae products.',
      why: 'Support general cardiovascular and normal inflammatory function.',
      foodFirst: 'Oily fish and algae are direct EPA and DHA sources.',
      generalUse: null,
      caution:
          'Ask a clinician before use with blood thinners, bleeding disorders, or planned surgery.',
    ),
    coachTip:
        'Consider it when your usual diet provides limited EPA and DHA; choose a source that matches your diet and restrictions.',
  ),
  SupplementCatalogEntry(
    id: 'electrolytes',
    name: 'Electrolytes',
    category: SupplementCategory.performance,
    evidenceUseCases: ['Long training', 'Meaningful sweat losses'],
    stableRules: [
      SupplementScoringRule(
        SupplementRuleSignal.enduranceGoal,
        0.5,
        SupplementRelevanceReason.performanceGoal,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.higherHydrationTarget,
        0.5,
        SupplementRelevanceReason.hydrationDemand,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.highTrainingVolume,
        0.5,
        SupplementRelevanceReason.highTrainingVolume,
      ),
    ],
    acuteRules: [
      SupplementScoringRule(
        SupplementRuleSignal.acuteLongDemandingWorkout,
        2.5,
        SupplementRelevanceReason.demandingWorkout,
      ),
    ],
    visibilityThreshold: 1,
    benefits: [
      'Fluid balance',
      'Sweat-loss replacement',
      'Long-session support',
    ],
    guidance: SupplementGuidance(
      what: 'Minerals such as sodium and potassium used in fluid balance.',
      why: 'Can replace meaningful sweat losses during long, hard training.',
      foodFirst: 'Routine sessions may be covered by normal meals and fluids.',
      generalUse: null,
      caution:
          'Needs vary; seek guidance with kidney, heart, or blood-pressure conditions.',
    ),
    coachTip:
        'Use mainly for long, demanding, hot, or high-sweat sessions rather than routine short workouts.',
  ),
  SupplementCatalogEntry(
    id: 'caffeine',
    name: 'Caffeine',
    category: SupplementCategory.performance,
    evidenceUseCases: ['Alertness', 'Exercise performance'],
    stableRules: [
      SupplementScoringRule(
        SupplementRuleSignal.performanceGoal,
        1.5,
        SupplementRelevanceReason.performanceGoal,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.enduranceGoal,
        0.5,
        SupplementRelevanceReason.performanceGoal,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.experiencedTraining,
        0.5,
        SupplementRelevanceReason.experiencedTraining,
      ),
    ],
    acuteRules: [
      SupplementScoringRule(
        SupplementRuleSignal.acuteDemandingWorkout,
        1,
        SupplementRelevanceReason.demandingWorkout,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.acuteLongWorkout,
        0.25,
        SupplementRelevanceReason.prolongedWorkout,
      ),
    ],
    visibilityThreshold: 2,
    benefits: ['Alertness', 'Exercise performance', 'Perceived effort'],
    guidance: SupplementGuidance(
      what: 'A stimulant found in coffee, tea, and performance products.',
      why: 'Can improve alertness and some aspects of exercise performance.',
      foodFirst: 'Coffee or tea can also provide caffeine.',
      generalUse: '1–3 mg/kg before exercise; lower amounts may be sufficient.',
      caution:
          'Avoid or seek guidance with pregnancy, heart conditions, anxiety sensitivity, medications, or sleep problems.',
    ),
    coachTip:
        'Treat it as an optional performance tool; protect sleep and use the lowest effective amount.',
  ),
  SupplementCatalogEntry(
    id: 'vitamin_d',
    name: 'Vitamin D',
    category: SupplementCategory.essentialNutrient,
    evidenceUseCases: ['Clinically supported Vitamin D consideration'],
    stableRules: [
      SupplementScoringRule(
        SupplementRuleSignal.reliableVitaminDSupport,
        3,
        SupplementRelevanceReason.reliableClinicalContext,
      ),
    ],
    acuteRules: [],
    visibilityThreshold: 0,
    benefits: ['Normal bone health', 'Normal immune function'],
    guidance: SupplementGuidance(
      what: 'A fat-soluble vitamin involved in bone and immune function.',
      why:
          'Supplementation can be appropriate when reliable evidence supports it.',
      foodFirst:
          'Dietary sources and fortified foods can contribute Vitamin D.',
      generalUse: null,
      caution:
          'Testing, medical history, and clinician guidance may be needed; excess intake can be harmful.',
    ),
    coachTip:
        'Consider checking Vitamin D status when appropriate; supplementation should depend on individual context or testing.',
  ),
  SupplementCatalogEntry(
    id: 'magnesium',
    name: 'Magnesium',
    category: SupplementCategory.essentialNutrient,
    evidenceUseCases: ['Clinically supported magnesium consideration'],
    stableRules: [
      SupplementScoringRule(
        SupplementRuleSignal.highTrainingVolume,
        1.25,
        SupplementRelevanceReason.highTrainingVolume,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.experiencedTraining,
        0.75,
        SupplementRelevanceReason.experiencedTraining,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.performanceGoal,
        0.5,
        SupplementRelevanceReason.performanceGoal,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.usualDemandingTraining,
        0.75,
        SupplementRelevanceReason.demandingWorkout,
      ),
      SupplementScoringRule(
        SupplementRuleSignal.reliableMagnesiumSupport,
        3,
        SupplementRelevanceReason.reliableClinicalContext,
      ),
    ],
    acuteRules: [],
    visibilityThreshold: 2.5,
    benefits: ['Normal muscle function', 'Normal energy metabolism'],
    guidance: SupplementGuidance(
      what: 'An essential mineral involved in muscle and nerve function.',
      why:
          'Supplementation may be appropriate when reliable evidence supports it.',
      foodFirst: 'Nuts, seeds, legumes, and whole grains contain magnesium.',
      generalUse: null,
      caution:
          'Clinical context matters; supplements can interact with medications and cause gastrointestinal effects.',
    ),
    coachTip:
        'Consider it only when dietary intake or reliable recovery context supports it; do not make it an automatic nightly requirement.',
  ),
];
