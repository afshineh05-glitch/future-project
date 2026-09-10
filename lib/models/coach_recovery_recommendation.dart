import 'package:future_project/models/recovery_context.dart';

enum CoachRecoveryRecommendationType {
  proceedNormally,
  recoverySupport,
  considerLighterTraining,
  insufficientWearableContext,
}

class CoachRecoveryRecommendation {
  final CoachRecoveryRecommendationType type;
  final String? message;
  final bool offersLighterTraining;
  final bool requiresExplicitUserAction;
  final List<RecoveryEvidenceCode> evidence;

  const CoachRecoveryRecommendation({
    required this.type,
    required this.offersLighterTraining,
    required this.requiresExplicitUserAction,
    required this.evidence,
    this.message,
  });

  bool get shouldSurface => message != null;
}

class CoachRecoveryInput {
  final RecoveryContext? recoveryContext;
  final bool isPlannedTrainingDay;
  final bool selfReportedFatigue;
  final bool selfReportedPain;

  const CoachRecoveryInput({
    this.recoveryContext,
    this.isPlannedTrainingDay = false,
    this.selfReportedFatigue = false,
    this.selfReportedPain = false,
  });
}
