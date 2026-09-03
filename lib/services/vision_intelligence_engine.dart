import 'package:future_project/models/future_vision.dart';
import 'package:future_project/models/vision_intelligence.dart';
import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/models/vision_progress.dart';

class VisionIntelligenceInput {
  final FutureVision? vision;
  final VisionProgressInput canonicalInput;
  final VisionProgress progress;
  final VisionMilestonesState milestones;
  final VisionBehaviorSummary behavior;
  final List<VisionEvidence> evidence;
  final VisionTodayAction todayAction;
  final bool hasTrainingPlan;
  final VisionMyWhyMetadata myWhy;

  const VisionIntelligenceInput({
    required this.vision,
    required this.canonicalInput,
    required this.progress,
    required this.milestones,
    required this.behavior,
    required this.evidence,
    required this.todayAction,
    this.hasTrainingPlan = false,
    this.myWhy = const VisionMyWhyMetadata(),
  });
}

class VisionIntelligenceEngine {
  const VisionIntelligenceEngine();

  VisionIntelligence interpret(VisionIntelligenceInput input) {
    final facts = _facts(input);
    final phase = _phase(input);
    final rankedEvidence = _rankEvidence(input);
    final completed = input.behavior.completedWorkoutCount;
    final verifiedBodyChange = _verifiedBodyChange(input.progress);
    final identity = input.vision?.futureIdentity.trim() ?? '';
    final next = input.milestones.nextMilestone;

    return VisionIntelligence(
      phase: phase,
      heroInsight: _hero(phase, completed),
      beliefStatement: _belief(phase, completed),
      beliefSupport: _beliefSupport(input, phase),
      journeyInsight: _journey(input, phase),
      journeyEvents: List.unmodifiable(rankedEvidence),
      rankedEvidence: List.unmodifiable(rankedEvidence),
      futureSelfMessage: _futureSelfMessage(
        input,
        phase,
        identity,
        completed,
        verifiedBodyChange,
      ),
      todayExplanation: _todayExplanation(input, phase),
      reflectionInsight: _reflection(input.behavior, phase),
      milestoneExplanation: _milestoneExplanation(next),
      factsUsed: List.unmodifiable(facts),
    );
  }

  VisionPhase _phase(VisionIntelligenceInput input) {
    if (input.behavior.returnedAfterGap) return VisionPhase.returning;
    return switch (input.progress.status) {
      VisionProgressStatus.needsAttention => VisionPhase.needsAttention,
      VisionProgressStatus.gainingMomentum => VisionPhase.gainingMomentum,
      VisionProgressStatus.onTrack => VisionPhase.onTrack,
      VisionProgressStatus.building => VisionPhase.building,
      VisionProgressStatus.starting =>
        input.canonicalInput.foundation.exists &&
                input.behavior.completedWorkoutCount == 0
            ? VisionPhase.establishingBaseline
            : VisionPhase.starting,
    };
  }

  String _hero(VisionPhase phase, int completed) {
    if (phase == VisionPhase.returning) {
      return 'You\'re moving again. Returning after a break is part of your progress.';
    }
    if (phase == VisionPhase.needsAttention) {
      return 'Your direction is still here. One meaningful action can restart the pattern.';
    }
    if (phase == VisionPhase.gainingMomentum || phase == VisionPhase.onTrack) {
      return 'Your recent consistency is building real momentum toward your goal.';
    }
    if (completed == 1) {
      return 'You\'ve started turning your vision into recorded action.';
    }
    if (completed > 1) {
      return '$completed completed workouts now support the identity you\'re building.';
    }
    return 'You\'re building the baseline that will make your future progress measurable.';
  }

  String _belief(VisionPhase phase, int completed) {
    if (phase == VisionPhase.returning) {
      return 'You came back. That matters more than the gap.';
    }
    if (phase == VisionPhase.needsAttention) {
      return 'Your next action can restart the pattern.';
    }
    if (phase == VisionPhase.gainingMomentum || phase == VisionPhase.onTrack) {
      return 'This is becoming something you do, not something you plan to do.';
    }
    if (completed > 0) return 'Build the evidence one session at a time.';
    return 'Start with evidence. The change comes after.';
  }

  String _beliefSupport(VisionIntelligenceInput input, VisionPhase phase) {
    if (input.myWhy.exists) {
      return 'Your Why is saved privately. Keep building toward it.';
    }
    if (phase == VisionPhase.establishingBaseline) {
      return 'A clear direction makes each verified action more meaningful.';
    }
    return 'Every verified action supports the person you\'re becoming.';
  }

  String _journey(VisionIntelligenceInput input, VisionPhase phase) {
    if (phase == VisionPhase.returning) {
      return 'You came back after a quieter stretch.';
    }
    if (phase == VisionPhase.needsAttention) {
      return 'Your recent training signal has slowed, but your recorded journey remains.';
    }
    if (input.behavior.completedWorkoutCount > 0) {
      return '${input.behavior.completedWorkoutCount} completed ${input.behavior.completedWorkoutCount == 1 ? 'workout is' : 'workouts are'} part of your transformation story.';
    }
    if (input.canonicalInput.foundation.completed) {
      return 'Your Foundation created a measurable starting point.';
    }
    return 'You chose a direction. Your first verified action will build the story.';
  }

  String _futureSelfMessage(
    VisionIntelligenceInput input,
    VisionPhase phase,
    String identity,
    int completed,
    bool verifiedBodyChange,
  ) {
    if (phase == VisionPhase.returning) {
      return 'You returned after a gap. The journey continued when you came back.';
    }
    if (verifiedBodyChange) {
      return 'Your Body Progress measurements now show verified movement toward your goal.';
    }
    if (completed > 0) {
      final identityCopy = identity.isEmpty
          ? 'the person you chose to become'
          : identity.toLowerCase();
      return 'You said you wanted to become $identityCopy. $completed completed ${completed == 1 ? 'workout now supports' : 'workouts now support'} that identity.';
    }
    if (input.canonicalInput.bodyProgressChecks.length == 1) {
      return 'Your first Body Progress Check created a comparison point. The next check will make change easier to measure.';
    }
    return 'Your direction is clear. Now you\'re building the evidence behind it.';
  }

  String _todayExplanation(VisionIntelligenceInput input, VisionPhase phase) {
    final goal = _goalLabel(
      input.canonicalInput.foundation.primaryGoal.isNotEmpty
          ? input.canonicalInput.foundation.primaryGoal
          : input.vision?.primaryGoal ?? '',
    );
    switch (input.todayAction.destination) {
      case VisionActionDestination.bodyProgress:
        return 'This check gives your Vision another real comparison point and makes future progress more measurable.';
      case VisionActionDestination.trainingPlan:
        return 'Today\'s session adds another real training signal behind your $goal goal.';
      case VisionActionDestination.nutrition:
        return 'Logging today\'s meals gives your $goal plan real evidence instead of relying on assumptions.';
      case VisionActionDestination.none:
        return goal == 'muscle-building'
            ? 'Recovery protects the quality of your next session. For muscle growth, rest is part of the training pattern.'
            : 'Recovery protects the quality of your next meaningful action toward your $goal goal.';
    }
  }

  String _reflection(VisionBehaviorSummary behavior, VisionPhase phase) {
    if (phase == VisionPhase.returning) {
      return 'You came back after a quieter stretch.';
    }
    final recent = behavior.reflectionHistory.take(7).toList();
    if (recent.isEmpty) {
      return 'Your recent reflection pattern is still unknown.';
    }
    final yes = recent.where((item) => item.response == 'yes').length;
    final notToday = recent
        .where((item) => item.response == 'not_today')
        .length;
    if (yes >= 4 && yes > notToday) {
      return 'You\'ve been showing up consistently.';
    }
    if (notToday >= 3 && notToday > yes) {
      return 'Your recent pattern has slowed. One intentional action can restart it.';
    }
    return 'Your recent days are mixed. That gives the system useful information about what is realistic.';
  }

  String _milestoneExplanation(VisionMilestone? milestone) {
    if (milestone == null) {
      return 'Your completed milestones remain part of your verified journey.';
    }
    if (milestone.id == 'body-progress-checks-2') {
      return 'Your second check will create a stronger comparison point for measuring physical change.';
    }
    if (milestone.category == VisionMilestoneCategory.training) {
      return 'Repeated training is currently one of your strongest available progress signals.';
    }
    if (milestone.category == VisionMilestoneCategory.consistency) {
      return 'More active training days make your consistency pattern easier to verify.';
    }
    if (milestone.category == VisionMilestoneCategory.nutrition) {
      return 'More confirmed nutrition days will strengthen the evidence behind your plan.';
    }
    return 'This milestone adds another verified comparison point to your Vision.';
  }

  List<VisionEvidence> _rankEvidence(VisionIntelligenceInput input) {
    final goal = _normalize(
      input.canonicalInput.foundation.primaryGoal.isNotEmpty
          ? input.canonicalInput.foundation.primaryGoal
          : input.vision?.primaryGoal ?? '',
    );
    final items = <VisionEvidence>[
      ...input.evidence,
      ...input.milestones.milestones
          .where(
            (milestone) =>
                milestone.status == VisionMilestoneStatus.completed &&
                milestone.completedAt != null,
          )
          .map(
            (milestone) => VisionEvidence(
              type: VisionEvidenceType.milestoneCompleted,
              label: '${milestone.title} milestone completed',
              detail:
                  'Completed from verified ${_milestoneSourceLabel(milestone.source)}.',
              priority: milestone.priority + 10,
              occurredAt: milestone.completedAt,
            ),
          ),
      if (input.vision?.futureSelfGeneratedAt case final generatedAt?)
        VisionEvidence(
          type: VisionEvidenceType.futureSelfGenerated,
          label: 'You created your Future Self visual',
          detail: 'Your saved goal and horizon shaped this visualization.',
          priority: 45,
          occurredAt: generatedAt,
        ),
    ];
    items.sort((a, b) {
      final strength = _evidenceScore(
        b,
        goal,
      ).compareTo(_evidenceScore(a, goal));
      if (strength != 0) return strength;
      final date = (b.occurredAt?.millisecondsSinceEpoch ?? 0).compareTo(
        a.occurredAt?.millisecondsSinceEpoch ?? 0,
      );
      if (date != 0) return date;
      return a.type.index.compareTo(b.type.index);
    });
    return items;
  }

  int _evidenceScore(VisionEvidence evidence, String goal) {
    var score = evidence.priority;
    if (evidence.type == VisionEvidenceType.bodyProgress) score += 40;
    if ({'build_muscle', 'muscle_gain', 'become_stronger'}.contains(goal) &&
        {
          VisionEvidenceType.workoutCompleted,
          VisionEvidenceType.trainingConsistency,
        }.contains(evidence.type)) {
      score += 25;
    }
    if ({'fat_loss', 'lose_fat'}.contains(goal) &&
        {
          VisionEvidenceType.bodyProgress,
          VisionEvidenceType.nutritionConsistency,
        }.contains(evidence.type)) {
      score += 25;
    }
    if ({
          'fitness',
          'improve_fitness',
          'feel_healthier',
          'health',
        }.contains(goal) &&
        {
          VisionEvidenceType.workoutCompleted,
          VisionEvidenceType.trainingConsistency,
          VisionEvidenceType.returnedAfterGap,
        }.contains(evidence.type)) {
      score += 20;
    }
    return score;
  }

  String _milestoneSourceLabel(VisionMilestoneSource source) =>
      switch (source) {
        VisionMilestoneSource.workoutHistory => 'workout history',
        VisionMilestoneSource.activeTrainingDays => 'active training days',
        VisionMilestoneSource.bodyProgressChecks => 'Body Progress checks',
        VisionMilestoneSource.exercisePerformance => 'exercise performance',
        VisionMilestoneSource.nutritionHistory => 'nutrition history',
      };

  List<VisionFact> _facts(VisionIntelligenceInput input) {
    final bodySignal = input.progress.signals
        .where((item) => item.type == VisionProgressSignalType.bodyProgress)
        .firstOrNull;
    final facts = <VisionFact>[
      VisionFact(
        type: VisionFactType.visionExists,
        value: input.vision != null,
        source: 'vision_profiles',
      ),
      VisionFact(
        type: VisionFactType.foundationCompleted,
        value: input.canonicalInput.foundation.completed,
        source: 'user_foundations',
      ),
      VisionFact(
        type: VisionFactType.primaryGoal,
        value: input.canonicalInput.foundation.primaryGoal.isNotEmpty
            ? input.canonicalInput.foundation.primaryGoal
            : input.vision?.primaryGoal ?? '',
        source: 'user_foundations/vision_profiles',
      ),
      VisionFact(
        type: VisionFactType.trainingPlanExists,
        value: input.hasTrainingPlan,
        source: 'training_plans',
      ),
      VisionFact(
        type: VisionFactType.completedWorkouts,
        value: input.behavior.completedWorkoutCount,
        source: 'workout_sessions',
      ),
      VisionFact(
        type: VisionFactType.trainingActiveDays,
        value: input.behavior.trainingActiveDates.length,
        source: 'workout_sessions',
      ),
      VisionFact(
        type: VisionFactType.bodyProgressChecks,
        value: input.canonicalInput.bodyProgressChecks.length,
        source: 'body_progress_checks',
      ),
      VisionFact(
        type: VisionFactType.comparableBodyProgress,
        value: input.canonicalInput.bodyProgressChecks.length >= 2,
        source: 'body_progress_checks',
      ),
      VisionFact(
        type: VisionFactType.verifiedBodyProgress,
        value: bodySignal?.available == true && bodySignal!.normalizedValue > 0,
        source: 'VisionProgressEngine',
      ),
      VisionFact(
        type: VisionFactType.nutritionLoggedDays,
        value: input.behavior.nutritionActiveDates.length,
        source: 'nutrition_food_logs',
      ),
      VisionFact(
        type: VisionFactType.reflectionYes,
        value: input.behavior.yesReflectionCount,
        source: 'vision_daily_reflections',
      ),
      VisionFact(
        type: VisionFactType.reflectionALittle,
        value: input.behavior.aLittleReflectionCount,
        source: 'vision_daily_reflections',
      ),
      VisionFact(
        type: VisionFactType.reflectionNotToday,
        value: input.behavior.notTodayReflectionCount,
        source: 'vision_daily_reflections',
      ),
      VisionFact(
        type: VisionFactType.returnedAfterGap,
        value: input.behavior.returnedAfterGap,
        source: 'FutureVisionService behavior summary',
      ),
      VisionFact(
        type: VisionFactType.progressStatus,
        value: input.progress.status.factValue,
        source: 'VisionProgressEngine',
      ),
      VisionFact(
        type: VisionFactType.progressConfidence,
        value: input.progress.confidence,
        source: 'VisionProgressEngine',
      ),
      VisionFact(
        type: VisionFactType.futureSelfGenerated,
        value: input.vision?.futureSelfGeneratedAt != null,
        source: 'vision_profiles metadata',
      ),
      VisionFact(
        type: VisionFactType.hasMyWhy,
        value: input.myWhy.exists,
        source: 'my_why_entries metadata',
      ),
      VisionFact(
        type: VisionFactType.hasMyWhyText,
        value: input.myWhy.hasText,
        source: 'my_why_entries metadata',
      ),
      VisionFact(
        type: VisionFactType.hasMyWhyVoice,
        value: input.myWhy.hasVoice,
        source: 'my_why_entries metadata',
      ),
      VisionFact(
        type: VisionFactType.hasMyWhyVideo,
        value: input.myWhy.hasVideo,
        source: 'my_why_entries metadata',
      ),
    ];
    if (input.behavior.trainingActiveDates.isNotEmpty) {
      facts.add(
        VisionFact(
          type: VisionFactType.lastCompletedWorkout,
          value: input.behavior.trainingActiveDates.last,
          source: 'workout_sessions',
        ),
      );
    }
    if (input.milestones.nextMilestone case final milestone?) {
      facts.add(
        VisionFact(
          type: VisionFactType.nextMilestone,
          value: milestone.id,
          source: 'VisionMilestonesEngine',
        ),
      );
    }
    return facts;
  }

  bool _verifiedBodyChange(VisionProgress progress) => progress.signals.any(
    (item) =>
        item.type == VisionProgressSignalType.bodyProgress &&
        item.available &&
        item.normalizedValue > 0,
  );

  String _goalLabel(String goal) => switch (_normalize(goal)) {
    'build_muscle' || 'muscle_gain' || 'become_stronger' => 'muscle-building',
    'fat_loss' || 'lose_fat' => 'fat-loss',
    'improve_fitness' || 'fitness' || 'athletic_performance' => 'fitness',
    'feel_healthier' || 'health' => 'health',
    _ => 'future-self',
  };

  String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');
}
