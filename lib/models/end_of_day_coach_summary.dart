import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';

class EndOfDayDataCoverage {
  final bool weeklyMissionAvailable;
  final bool dailyDecisionAvailable;
  final bool workoutDataAvailable;
  final bool wearableDataAvailable;
  final bool recoveryContextAvailable;

  const EndOfDayDataCoverage({
    required this.weeklyMissionAvailable,
    required this.dailyDecisionAvailable,
    required this.workoutDataAvailable,
    required this.wearableDataAvailable,
    required this.recoveryContextAvailable,
  });

  int get availableSources => [
    weeklyMissionAvailable,
    dailyDecisionAvailable,
    workoutDataAvailable,
    wearableDataAvailable,
    recoveryContextAvailable,
  ].where((value) => value).length;
}

class EndOfDayCoachSummary {
  final DateTime localDate;
  final String headline;
  final String progressRecognition;
  final String? missionContext;
  final String todayObservation;
  final String nextAction;
  final List<String> evidence;
  final EndOfDayDataCoverage dataCoverage;
  final DateTime generatedAt;
  final CoachDecision? dailyDecisionContext;
  final RecoveryContextState? recoveryContext;

  const EndOfDayCoachSummary({
    required this.localDate,
    required this.headline,
    required this.progressRecognition,
    this.missionContext,
    required this.todayObservation,
    required this.nextAction,
    required this.evidence,
    required this.dataCoverage,
    required this.generatedAt,
    this.dailyDecisionContext,
    this.recoveryContext,
  });
}
