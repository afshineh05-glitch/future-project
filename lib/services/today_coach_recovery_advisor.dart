import 'package:future_project/models/coach_recovery_recommendation.dart';
import 'package:future_project/models/recovery_context.dart';

class TodayCoachRecoveryAdvisor {
  const TodayCoachRecoveryAdvisor();

  CoachRecoveryRecommendation recommend(CoachRecoveryInput input) {
    final context = input.recoveryContext;
    if (context == null ||
        context.overallState == RecoveryContextState.insufficientData) {
      return const CoachRecoveryRecommendation(
        type: CoachRecoveryRecommendationType.insufficientWearableContext,
        offersLighterTraining: false,
        requiresExplicitUserAction: false,
        evidence: [],
      );
    }

    if (context.overallState == RecoveryContextState.caution) {
      final trainingDay = input.isPlannedTrainingDay;
      return CoachRecoveryRecommendation(
        type: trainingDay
            ? CoachRecoveryRecommendationType.considerLighterTraining
            : CoachRecoveryRecommendationType.recoverySupport,
        message: trainingDay
            ? 'Your recent recovery signals are lower than usual. You can keep your planned session or choose to train lighter today.'
            : 'Your recent recovery signals are lower than usual. Consider giving recovery more attention today.',
        offersLighterTraining: trainingDay,
        requiresExplicitUserAction: trainingDay,
        evidence: context.evidence,
      );
    }

    if (context.overallState == RecoveryContextState.favorable) {
      if (input.selfReportedFatigue || input.selfReportedPain) {
        return CoachRecoveryRecommendation(
          type: CoachRecoveryRecommendationType.recoverySupport,
          message:
              'Your wearable context looks steady, but how you feel matters more today. Keep your effort aligned with your own fatigue or discomfort.',
          offersLighterTraining: false,
          requiresExplicitUserAction: false,
          evidence: context.evidence,
        );
      }
      return CoachRecoveryRecommendation(
        type: CoachRecoveryRecommendationType.proceedNormally,
        message:
            'Your recent recovery context looks favorable. Continue with your existing plan without adding extra work.',
        offersLighterTraining: false,
        requiresExplicitUserAction: false,
        evidence: context.evidence,
      );
    }

    return CoachRecoveryRecommendation(
      type: CoachRecoveryRecommendationType.proceedNormally,
      offersLighterTraining: false,
      requiresExplicitUserAction: false,
      evidence: context.evidence,
    );
  }
}
