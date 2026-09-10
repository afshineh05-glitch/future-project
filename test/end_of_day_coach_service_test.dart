import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/end_of_day_coach_service.dart';

WeeklyCoachPlan weekly(WeeklyMissionType type) => WeeklyCoachPlan(
  weekStart: DateTime(2026, 9, 14),
  weekEnd: DateTime(2026, 9, 20),
  shortRetrospective: '',
  biggestWin: '',
  mainLimitingFactor: '',
  missionType: type,
  missionTitle: 'Persisted mission',
  missionReason: 'Persisted reason',
  actionItems: const [
    'Start bedtime 30 minutes earlier tonight.',
    'Second action.',
  ],
  motivationContext: '',
  previousMissionOutcome: WeeklyMissionOutcome.insufficientData,
  followUpMessage: '',
  dataCoverage: const WeeklyCoachDataCoverage(
    wearableDays: 6,
    workoutSourceAvailable: true,
  ),
  evidence: const [],
  generatedAt: DateTime(2026, 9, 14),
);

RecoveryContext recovery(RecoveryContextState state) => RecoveryContext(
  overallState: state,
  sleepContext: const RecoveryMetricContext(
    state: RecoveryContextState.normal,
    baselineDays: 7,
    evidence: [],
  ),
  restingHeartRateContext: const RecoveryMetricContext(
    state: RecoveryContextState.normal,
    baselineDays: 7,
    evidence: [],
  ),
  recentActivityContext: const RecoveryMetricContext(
    state: RecoveryContextState.normal,
    baselineDays: 7,
    evidence: [],
  ),
  recentWorkoutContext: const RecoveryWorkoutContext(
    state: RecoveryContextState.normal,
    completedSessionsLast7Days: 1,
    evidence: [],
  ),
  dataCoverage: const RecoveryDataCoverage(
    wearableDays: 7,
    comparableComponents: 3,
    availableComponents: 3,
  ),
  evidence: const [],
  generatedAt: DateTime(2026, 9, 14),
);

void main() {
  const engine = EndOfDayCoachEngine();
  final now = DateTime(2026, 9, 14, 20);

  test('no weekly mission still uses reliable completed workout evidence', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        observation: const EndOfDayObservation(workoutCompleted: true),
      ),
    )!;
    expect(result.missionContext, isNull);
    expect(result.progressRecognition, contains('completed'));
  });

  test('workout completed advances weekly consistency using real evidence', () {
    final plan = weekly(WeeklyMissionType.improveWorkoutConsistency);
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        weeklyPlan: plan,
        observation: const EndOfDayObservation(workoutCompleted: true),
      ),
    )!;
    expect(result.evidence, contains('completed_workout'));
    expect(result.missionContext, contains('weekly consistency'));
    expect(plan.missionTitle, 'Persisted mission');
  });

  test('workout not completed does not fabricate praise', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        weeklyPlan: weekly(WeeklyMissionType.improveWorkoutConsistency),
        observation: const EndOfDayObservation(workoutCompleted: false),
      ),
    )!;
    expect(result.todayObservation, contains('No completed'));
    expect(
      result.progressRecognition,
      contains('not enough positive evidence'),
    );
    expect(result.evidence, isNot(contains('completed_workout')));
  });

  test('lighterSession is respected and never encourages full intensity', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        weeklyPlan: weekly(WeeklyMissionType.protectRecovery),
        dailyDecision: CoachDecision.lighterSession,
        observation: const EndOfDayObservation(workoutCompleted: true),
      ),
    )!;
    expect(result.progressRecognition, contains('lighter-session choice'));
    expect(result.progressRecognition, isNot(contains('full')));
    expect(result.nextAction, isNot(contains('intensity')));
  });

  test('plannedSession does not increase intensity', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        dailyDecision: CoachDecision.plannedSession,
        observation: const EndOfDayObservation(workoutCompleted: true),
      ),
    )!;
    expect(
      result.progressRecognition,
      'You completed a recorded workout today.',
    );
    expect(result.nextAction, contains('without adding extra work'));
  });

  test('recovery caution takes precedence over consistency', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        weeklyPlan: weekly(WeeklyMissionType.improveWorkoutConsistency),
        recoveryContext: recovery(RecoveryContextState.caution),
        observation: const EndOfDayObservation(workoutCompleted: false),
      ),
    )!;
    expect(result.headline, 'Protect recovery tonight');
    expect(result.nextAction, startsWith('Tonight:'));
  });

  test('pain and fatigue take precedence over all other context', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        weeklyPlan: weekly(WeeklyMissionType.improveWorkoutConsistency),
        dailyDecision: CoachDecision.plannedSession,
        recoveryContext: recovery(RecoveryContextState.caution),
        observation: const EndOfDayObservation(workoutCompleted: true),
        selfReportedPain: true,
      ),
    )!;
    expect(result.headline, contains('how you feel'));
    expect(result.todayObservation, contains('take priority'));
  });

  test('missing wearable data does not block summary', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(now: now, dailyDecision: CoachDecision.lighterSession),
    )!;
    expect(result.dataCoverage.wearableDataAvailable, isFalse);
    expect(result.headline, isNotEmpty);
  });

  test('missing workout data is not converted to zero', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        weeklyPlan: weekly(WeeklyMissionType.protectRecovery),
      ),
    )!;
    expect(result.dataCoverage.workoutDataAvailable, isFalse);
    expect(result.todayObservation, contains('unavailable'));
  });

  test('too little data produces no summary', () {
    expect(engine.evaluate(EndOfDayCoachInput(now: now)), isNull);
  });

  test('summary always exposes exactly one next action field', () {
    final result = engine.evaluate(
      EndOfDayCoachInput(
        now: now,
        observation: const EndOfDayObservation(workoutCompleted: true),
      ),
    )!;
    expect(result.nextAction, isNotEmpty);
    expect(result.nextAction.split('\n'), hasLength(1));
  });

  test('observation failure degrades to missing data', () async {
    final service = EndOfDayCoachService(
      source: _FailingSource(),
      clock: () => now,
    );
    final result = await service.loadTodaySafely();
    expect(result.workoutCompleted, isNull);
    expect(result.wearableRecord, isNull);
  });

  test(
    'no mutations and no duplicate follow-up persistence are introduced',
    () {
      final source = File(
        'lib/services/end_of_day_coach_service.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('insert(')));
      expect(source, isNot(contains('upsert(')));
      expect(source, isNot(contains('save_coach_weekly_plan')));
      for (final path in [
        'lib/screens/training_plan_screen.dart',
        'lib/services/recovery_nutrition_service.dart',
        'lib/services/vision_progress_engine.dart',
      ]) {
        final protectedSource = File(path).readAsStringSync();
        expect(protectedSource, isNot(contains('EndOfDayCoach')));
      }
    },
  );

  test('public summary model has no numeric readiness score', () {
    final source = File(
      'lib/models/end_of_day_coach_summary.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('readinessScore')));
  });
}

class _FailingSource implements EndOfDayObservationSource {
  @override
  Future<EndOfDayObservation> load(DateTime localDate) =>
      Future.error(Exception('offline'));
}
