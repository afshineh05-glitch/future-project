import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearables_hub.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/end_of_day_coach_service.dart';
import 'package:future_project/services/today_weekly_mission_advisor.dart';
import 'package:future_project/services/unified_coach_context_engine.dart';
import 'package:future_project/services/wearables_hub_service.dart';

final now = DateTime(2026, 9, 10, 9);
const unifiedEngine = UnifiedCoachContextEngine();

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
    completedSessionsLast7Days: 2,
    evidence: [],
  ),
  dataCoverage: const RecoveryDataCoverage(
    wearableDays: 7,
    comparableComponents: 3,
    availableComponents: 3,
  ),
  evidence: const [],
  generatedAt: now,
);

WeeklyCoachPlan weekly() => WeeklyCoachPlan(
  weekStart: DateTime(2026, 9, 7),
  weekEnd: DateTime(2026, 9, 13),
  shortRetrospective: '',
  biggestWin: '',
  mainLimitingFactor: '',
  missionType: WeeklyMissionType.improveWorkoutConsistency,
  missionTitle: 'Persisted consistency mission',
  missionReason: '',
  actionItems: const ['Use the existing training window.'],
  motivationContext: '',
  previousMissionOutcome: WeeklyMissionOutcome.insufficientData,
  followUpMessage: '',
  dataCoverage: const WeeklyCoachDataCoverage(
    wearableDays: 6,
    workoutSourceAvailable: true,
  ),
  evidence: const [],
  generatedAt: now,
);

ConnectedHealthSource healthSource() => const ConnectedHealthSource(
  provider: WearableProvider.appleHealth,
  displayName: 'Apple Health',
  permissionStatus: WearablePermissionStatus.authorized,
  dataAvailable: true,
);

void main() {
  test('user pain overrides favorable recovery', () {
    final result = unifiedEngine.evaluate(
      UnifiedCoachContextInput(
        now: now,
        recoveryContext: recovery(RecoveryContextState.favorable),
        userReportedPainOrFatigue: true,
      ),
    );
    expect(result.primaryState, UnifiedCoachPrimaryState.userCondition);
    expect(result.primaryPriority, UnifiedCoachPriority.protectRecovery);
  });

  test('fatigue overrides Weekly Mission consistency', () {
    final result = unifiedEngine.evaluate(
      UnifiedCoachContextInput(
        now: now,
        weeklyPlan: weekly(),
        userReportedPainOrFatigue: true,
      ),
    );
    expect(result.evidence, ['user_reported_condition']);
  });

  test('recovery caution overrides Weekly Mission', () {
    final result = unifiedEngine.evaluate(
      UnifiedCoachContextInput(
        now: now,
        recoveryContext: recovery(RecoveryContextState.caution),
        weeklyPlan: weekly(),
      ),
    );
    expect(result.primaryState, UnifiedCoachPrimaryState.recovery);
  });

  test('lighterSession has decision precedence', () {
    final result = unifiedEngine.evaluate(
      UnifiedCoachContextInput(
        now: now,
        dailyDecision: CoachDecision.lighterSession,
        weeklyPlan: weekly(),
      ),
    );
    expect(result.primaryPriority, UnifiedCoachPriority.respectLighterSession);
    expect(result.primaryAction, contains('lighter approach'));
  });

  test('plannedSession reinforces but does not increase intensity', () {
    final result = unifiedEngine.evaluate(
      UnifiedCoachContextInput(
        now: now,
        dailyDecision: CoachDecision.plannedSession,
      ),
    );
    expect(result.primaryPriority, UnifiedCoachPriority.followPlannedSession);
    expect(result.primaryAction, contains('without adding intensity'));
  });

  test('Weekly Mission is used when no higher priority exists', () {
    final mission = weekly();
    final result = unifiedEngine.evaluate(
      UnifiedCoachContextInput(now: now, weeklyPlan: mission),
    );
    expect(result.primaryPriority, UnifiedCoachPriority.improveConsistency);
    expect(result.weeklyMissionContext, same(mission));
  });

  test('wearable trend remains lower priority than Weekly Mission', () {
    final result = unifiedEngine.evaluate(
      UnifiedCoachContextInput(
        now: now,
        weeklyPlan: weekly(),
        wearableInsight: 'Steps increased.',
        wearableAction: 'Keep observing.',
      ),
    );
    expect(result.primaryState, UnifiedCoachPrimaryState.weeklyMission);
    expect(result.primaryInsight, isNot('Steps increased.'));
  });

  test('returns exactly one primary priority and one action', () {
    final result = unifiedEngine.evaluate(UnifiedCoachContextInput(now: now));
    expect(result.primaryPriority, UnifiedCoachPriority.insufficientContext);
    expect(result.primaryAction, isNotEmpty);
    expect(result.primaryAction.split('\n'), hasLength(1));
  });

  test('missing data remains unavailable rather than zero', () {
    final result = unifiedEngine.evaluate(UnifiedCoachContextInput(now: now));
    expect(result.recoveryContext, isNull);
    expect(result.dailyDecisionContext, isNull);
    expect(result.dataCoverage.recoveryAvailable, isFalse);
  });

  test(
    'Today’s Coach and Wearables Hub resolve the same priority and action',
    () {
      final context = unifiedEngine.evaluate(
        UnifiedCoachContextInput(
          now: now,
          recoveryContext: recovery(RecoveryContextState.caution),
          weeklyPlan: weekly(),
        ),
      );
      final today = const TodayWeeklyMissionAdvisor().advise(
        plan: weekly(),
        isPlannedTrainingDay: true,
        unifiedContext: context,
      )!;
      final hub = const WearablesHubEngine().build(
        source: healthSource(),
        now: now,
        recoveryContext: recovery(RecoveryContextState.caution),
        weeklyPlan: weekly(),
      );
      expect(hub.unifiedCoachContext.primaryPriority, context.primaryPriority);
      expect(hub.coachInsight!.nextAction, today.todayFocus);
    },
  );

  test('End-of-Day stays compatible while recognizing actual completion', () {
    final context = unifiedEngine.evaluate(
      UnifiedCoachContextInput(now: now, weeklyPlan: weekly()),
    );
    final summary = const EndOfDayCoachEngine().evaluate(
      EndOfDayCoachInput(
        now: now,
        weeklyPlan: weekly(),
        unifiedContext: context,
        observation: const EndOfDayObservation(workoutCompleted: true),
      ),
    )!;
    expect(summary.progressRecognition, contains('completed'));
    expect(summary.nextAction, context.primaryAction);
  });

  test('Weekly Mission is not mutated', () {
    final mission = weekly();
    unifiedEngine.evaluate(
      UnifiedCoachContextInput(now: now, weeklyPlan: mission),
    );
    expect(mission.missionTitle, 'Persisted consistency mission');
    expect(mission.actionItems, ['Use the existing training window.']);
  });

  test('protected systems remain unmodified and no persistence is added', () {
    final engine = File(
      'lib/services/unified_coach_context_engine.dart',
    ).readAsStringSync();
    expect(engine, isNot(contains('Supabase')));
    expect(engine, isNot(contains('OpenAI')));
    expect(engine, isNot(contains('readinessScore')));
    for (final path in [
      'lib/screens/training_plan_screen.dart',
      'lib/services/recovery_nutrition_service.dart',
      'lib/services/vision_progress_engine.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('UnifiedCoachContext')),
      );
    }
  });
}
