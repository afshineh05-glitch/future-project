import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/coach_recovery_recommendation.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/services/today_coach_recovery_advisor.dart';

void main() {
  const advisor = TodayCoachRecoveryAdvisor();

  RecoveryContext context(
    RecoveryContextState state, {
    List<RecoveryEvidenceCode> evidence = const [],
  }) => RecoveryContext(
    overallState: state,
    sleepContext: _metric,
    restingHeartRateContext: _metric,
    recentActivityContext: _metric,
    recentWorkoutContext: const RecoveryWorkoutContext(
      state: RecoveryContextState.insufficientData,
      completedSessionsLast7Days: 0,
      evidence: [RecoveryEvidenceCode.insufficientWorkoutHistory],
    ),
    dataCoverage: const RecoveryDataCoverage(
      wearableDays: 6,
      comparableComponents: 2,
      availableComponents: 2,
    ),
    evidence: evidence,
    generatedAt: DateTime(2026, 9, 10),
  );

  test('no wearable context preserves existing Coach behavior', () {
    final result = advisor.recommend(const CoachRecoveryInput());

    expect(
      result.type,
      CoachRecoveryRecommendationType.insufficientWearableContext,
    );
    expect(result.shouldSurface, isFalse);
  });

  test('insufficient wearable context stays hidden', () {
    final result = advisor.recommend(
      CoachRecoveryInput(
        recoveryContext: context(RecoveryContextState.insufficientData),
      ),
    );

    expect(result.shouldSurface, isFalse);
    expect(result.offersLighterTraining, isFalse);
  });

  test('normal recovery does not clutter Coach UI', () {
    final result = advisor.recommend(
      CoachRecoveryInput(recoveryContext: context(RecoveryContextState.normal)),
    );

    expect(result.type, CoachRecoveryRecommendationType.proceedNormally);
    expect(result.shouldSurface, isFalse);
  });

  test('favorable recovery adds context without encouraging extra work', () {
    final result = advisor.recommend(
      CoachRecoveryInput(
        recoveryContext: context(RecoveryContextState.favorable),
      ),
    );

    expect(result.type, CoachRecoveryRecommendationType.proceedNormally);
    expect(result.message, contains('without adding extra work'));
    expect(result.offersLighterTraining, isFalse);
  });

  test('caution on training day offers an explicit lighter option', () {
    final result = advisor.recommend(
      CoachRecoveryInput(
        recoveryContext: context(
          RecoveryContextState.caution,
          evidence: const [RecoveryEvidenceCode.sleepBelowPersonalBaseline],
        ),
        isPlannedTrainingDay: true,
      ),
    );

    expect(
      result.type,
      CoachRecoveryRecommendationType.considerLighterTraining,
    );
    expect(result.offersLighterTraining, isTrue);
    expect(result.requiresExplicitUserAction, isTrue);
  });

  test('caution on rest day recommends support without training option', () {
    final result = advisor.recommend(
      CoachRecoveryInput(
        recoveryContext: context(RecoveryContextState.caution),
      ),
    );

    expect(result.type, CoachRecoveryRecommendationType.recoverySupport);
    expect(result.offersLighterTraining, isFalse);
  });

  test('self-reported fatigue overrides favorable wearable wording', () {
    final result = advisor.recommend(
      CoachRecoveryInput(
        recoveryContext: context(RecoveryContextState.favorable),
        selfReportedFatigue: true,
      ),
    );

    expect(result.type, CoachRecoveryRecommendationType.recoverySupport);
    expect(result.message, contains('how you feel matters more'));
    expect(result.message, isNot(contains('favorable')));
  });

  test('self-reported pain overrides favorable wearable wording', () {
    final result = advisor.recommend(
      CoachRecoveryInput(
        recoveryContext: context(RecoveryContextState.favorable),
        selfReportedPain: true,
      ),
    );

    expect(result.type, CoachRecoveryRecommendationType.recoverySupport);
    expect(result.message, contains('discomfort'));
  });

  test(
    'missing metrics and conflicting evidence remain non-medical context',
    () {
      final result = advisor.recommend(
        CoachRecoveryInput(
          recoveryContext: context(
            RecoveryContextState.normal,
            evidence: const [RecoveryEvidenceCode.conflictingSignals],
          ),
        ),
      );

      expect(result.shouldSurface, isFalse);
      expect(
        result.evidence,
        contains(RecoveryEvidenceCode.conflictingSignals),
      );
    },
  );

  test('recommendation cannot mutate a Training Plan', () {
    final result = advisor.recommend(
      CoachRecoveryInput(
        recoveryContext: context(RecoveryContextState.caution),
        isPlannedTrainingDay: true,
      ),
    );

    expect(result.requiresExplicitUserAction, isTrue);
    final source = File(
      'lib/services/today_coach_recovery_advisor.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('.from(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.upsert(')));
  });
}

const _metric = RecoveryMetricContext(
  state: RecoveryContextState.normal,
  latestValue: 1,
  personalBaseline: 1,
  baselineDays: 5,
  evidence: [],
);
