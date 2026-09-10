import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/weekly_coach_plan.dart';

class UnifiedCoachContextInput {
  final DateTime now;
  final RecoveryContext? recoveryContext;
  final WeeklyCoachPlan? weeklyPlan;
  final CoachDecision? dailyDecision;
  final bool userReportedPainOrFatigue;
  final bool? isPlannedTrainingDay;
  final String? wearableInsight;
  final String? wearableAction;
  final List<String> wearableEvidence;

  const UnifiedCoachContextInput({
    required this.now,
    this.recoveryContext,
    this.weeklyPlan,
    this.dailyDecision,
    this.userReportedPainOrFatigue = false,
    this.isPlannedTrainingDay,
    this.wearableInsight,
    this.wearableAction,
    this.wearableEvidence = const [],
  });
}

class UnifiedCoachContextEngine {
  const UnifiedCoachContextEngine();

  UnifiedCoachContext evaluate(UnifiedCoachContextInput input) {
    late UnifiedCoachPrimaryState state;
    late UnifiedCoachPriority priority;
    late String insight;
    late String action;
    late List<String> evidence;

    if (input.userReportedPainOrFatigue) {
      state = UnifiedCoachPrimaryState.userCondition;
      priority = UnifiedCoachPriority.protectRecovery;
      insight =
          'How you feel matters more than positive wearable or training signals today.';
      action = 'Keep today’s effort within your current comfort and energy.';
      evidence = const ['user_reported_condition'];
    } else if (input.recoveryContext?.overallState ==
        RecoveryContextState.caution) {
      state = UnifiedCoachPrimaryState.recovery;
      priority = UnifiedCoachPriority.protectRecovery;
      insight =
          'Your validated recovery context deserves more attention today.';
      action = 'Tonight: protect your normal sleep and recovery routine.';
      evidence = const ['recovery_caution'];
    } else if (input.dailyDecision == CoachDecision.lighterSession) {
      state = UnifiedCoachPrimaryState.dailyDecision;
      priority = UnifiedCoachPriority.respectLighterSession;
      insight =
          'Your recorded lighter-session choice is authoritative for today.';
      action =
          'Keep the lighter approach without returning to full planned intensity.';
      evidence = const ['lighter_session_decision'];
    } else if (input.dailyDecision == CoachDecision.plannedSession) {
      state = UnifiedCoachPrimaryState.dailyDecision;
      priority = UnifiedCoachPriority.followPlannedSession;
      insight = 'You chose to keep today’s existing planned session.';
      action =
          'Follow the existing session without adding intensity or extra work.';
      evidence = const ['planned_session_decision'];
    } else if (input.weeklyPlan != null) {
      state = UnifiedCoachPrimaryState.weeklyMission;
      priority = _weeklyPriority(input.weeklyPlan!.missionType);
      insight =
          'Today’s direction follows the current persisted Weekly Mission.';
      action = _weeklyAction(input.weeklyPlan!, input.isPlannedTrainingDay);
      evidence = const ['weekly_mission'];
    } else if (input.wearableInsight != null && input.wearableAction != null) {
      state = UnifiedCoachPrimaryState.wearableContext;
      priority = UnifiedCoachPriority.maintainHealthyPattern;
      insight = input.wearableInsight!;
      action = input.wearableAction!;
      evidence = List.unmodifiable(input.wearableEvidence);
    } else if (input.recoveryContext?.overallState ==
            RecoveryContextState.favorable ||
        input.recoveryContext?.overallState == RecoveryContextState.normal) {
      state = UnifiedCoachPrimaryState.general;
      priority = UnifiedCoachPriority.maintainHealthyPattern;
      insight =
          'Your available recovery context remains near your personal pattern.';
      action = 'Continue your existing plan without adding extra intensity.';
      evidence = const ['stable_recovery_context'];
    } else {
      state = UnifiedCoachPrimaryState.general;
      priority = UnifiedCoachPriority.insufficientContext;
      insight =
          'There is not enough reliable context for a stronger coaching interpretation today.';
      action =
          'Continue your existing routine without making an automatic change.';
      evidence = const ['insufficient_context'];
    }

    return UnifiedCoachContext(
      localDate: DateTime(input.now.year, input.now.month, input.now.day),
      primaryState: state,
      primaryPriority: priority,
      primaryInsight: insight,
      primaryAction: action,
      weeklyMissionContext: input.weeklyPlan,
      dailyDecisionContext: input.dailyDecision,
      recoveryContext: input.recoveryContext,
      userConditionContext: input.userReportedPainOrFatigue,
      evidence: evidence,
      dataCoverage: UnifiedCoachDataCoverage(
        userConditionAvailable: input.userReportedPainOrFatigue,
        recoveryAvailable: input.recoveryContext != null,
        dailyDecisionAvailable: input.dailyDecision != null,
        weeklyMissionAvailable: input.weeklyPlan != null,
        wearableContextAvailable: input.wearableInsight != null,
      ),
      generatedAt: input.now,
    );
  }

  UnifiedCoachPriority _weeklyPriority(WeeklyMissionType type) =>
      switch (type) {
        WeeklyMissionType.protectRecovery ||
        WeeklyMissionType.improveTrainingNightSleep =>
          UnifiedCoachPriority.protectRecovery,
        WeeklyMissionType.improveWorkoutConsistency =>
          UnifiedCoachPriority.improveConsistency,
        WeeklyMissionType.reduceActivityLoad ||
        WeeklyMissionType.maintainSuccessfulBehavior =>
          UnifiedCoachPriority.maintainHealthyPattern,
      };

  String _weeklyAction(WeeklyCoachPlan plan, bool? trainingDay) {
    if (plan.missionType == WeeklyMissionType.improveWorkoutConsistency &&
        trainingDay == true) {
      return 'Complete today’s existing planned session without adding intensity.';
    }
    if (plan.missionType == WeeklyMissionType.improveWorkoutConsistency &&
        trainingDay == false) {
      return 'Keep the Weekly Mission in view without inventing a workout today.';
    }
    return plan.actionItems.firstOrNull ??
        'Continue the current Weekly Mission without changing the plan.';
  }
}
