import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/weekly_coach_plan.dart';

enum UnifiedCoachPrimaryState {
  userCondition,
  recovery,
  dailyDecision,
  weeklyMission,
  wearableContext,
  general,
}

enum UnifiedCoachPriority {
  protectRecovery,
  followPlannedSession,
  respectLighterSession,
  improveConsistency,
  maintainHealthyPattern,
  insufficientContext,
}

class UnifiedCoachDataCoverage {
  final bool userConditionAvailable;
  final bool recoveryAvailable;
  final bool dailyDecisionAvailable;
  final bool weeklyMissionAvailable;
  final bool wearableContextAvailable;

  const UnifiedCoachDataCoverage({
    required this.userConditionAvailable,
    required this.recoveryAvailable,
    required this.dailyDecisionAvailable,
    required this.weeklyMissionAvailable,
    required this.wearableContextAvailable,
  });
}

class UnifiedCoachContext {
  final DateTime localDate;
  final UnifiedCoachPrimaryState primaryState;
  final UnifiedCoachPriority primaryPriority;
  final String primaryInsight;
  final String primaryAction;
  final WeeklyCoachPlan? weeklyMissionContext;
  final CoachDecision? dailyDecisionContext;
  final RecoveryContext? recoveryContext;
  final bool userConditionContext;
  final List<String> evidence;
  final UnifiedCoachDataCoverage dataCoverage;
  final DateTime generatedAt;

  const UnifiedCoachContext({
    required this.localDate,
    required this.primaryState,
    required this.primaryPriority,
    required this.primaryInsight,
    required this.primaryAction,
    this.weeklyMissionContext,
    this.dailyDecisionContext,
    this.recoveryContext,
    required this.userConditionContext,
    required this.evidence,
    required this.dataCoverage,
    required this.generatedAt,
  });
}
