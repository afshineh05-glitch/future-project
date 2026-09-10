enum RecoveryContextState { favorable, normal, caution, insufficientData }

enum RecoveryEvidenceCode {
  insufficientHistory,
  latestValueMissing,
  sleepBelowPersonalBaseline,
  sleepNearPersonalBaseline,
  sleepAbovePersonalBaseline,
  restingHeartRateElevatedFromBaseline,
  restingHeartRateNearBaseline,
  recentActivityAboveBaseline,
  recentActivityNearBaseline,
  recentWorkoutHistoryAvailable,
  insufficientWorkoutHistory,
  conflictingSignals,
}

class RecoveryMetricContext {
  final RecoveryContextState state;
  final double? latestValue;
  final double? personalBaseline;
  final int baselineDays;
  final String? unit;
  final List<RecoveryEvidenceCode> evidence;

  const RecoveryMetricContext({
    required this.state,
    required this.baselineDays,
    required this.evidence,
    this.latestValue,
    this.personalBaseline,
    this.unit,
  });
}

class RecoveryWorkoutContext {
  final RecoveryContextState state;
  final int completedSessionsLast7Days;
  final List<RecoveryEvidenceCode> evidence;

  const RecoveryWorkoutContext({
    required this.state,
    required this.completedSessionsLast7Days,
    required this.evidence,
  });
}

class RecoveryDataCoverage {
  final int wearableDays;
  final int comparableComponents;
  final int availableComponents;

  const RecoveryDataCoverage({
    required this.wearableDays,
    required this.comparableComponents,
    required this.availableComponents,
  });
}

class RecoveryContext {
  final RecoveryContextState overallState;
  final RecoveryMetricContext sleepContext;
  final RecoveryMetricContext restingHeartRateContext;
  final RecoveryMetricContext recentActivityContext;
  final RecoveryWorkoutContext recentWorkoutContext;
  final RecoveryDataCoverage dataCoverage;
  final List<RecoveryEvidenceCode> evidence;
  final DateTime generatedAt;

  const RecoveryContext({
    required this.overallState,
    required this.sleepContext,
    required this.restingHeartRateContext,
    required this.recentActivityContext,
    required this.recentWorkoutContext,
    required this.dataCoverage,
    required this.evidence,
    required this.generatedAt,
  });
}
