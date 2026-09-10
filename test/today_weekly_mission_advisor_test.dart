import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/today_weekly_mission_advisor.dart';

WeeklyCoachPlan plan(
  WeeklyMissionType type, {
  List<String> actions = const [
    'Start bedtime 30 minutes earlier tonight.',
    'Second weekly action.',
    'Third weekly action.',
  ],
}) => WeeklyCoachPlan(
  weekStart: DateTime(2026, 9, 14),
  weekEnd: DateTime(2026, 9, 20),
  shortRetrospective: 'Past context',
  biggestWin: 'Measured win',
  mainLimitingFactor: 'Measured constraint',
  missionType: type,
  missionTitle: 'Authoritative weekly mission',
  missionReason: 'Persisted reason',
  actionItems: actions,
  motivationContext: 'Measured motivation',
  previousMissionOutcome: WeeklyMissionOutcome.success,
  followUpMessage: 'Persisted follow-up',
  dataCoverage: const WeeklyCoachDataCoverage(
    wearableDays: 6,
    workoutSourceAvailable: true,
  ),
  evidence: const ['Evidence'],
  generatedAt: DateTime(2026, 9, 14),
);

UnifiedCoachContext context(String action) => UnifiedCoachContext(
  localDate: DateTime(2026, 9, 14),
  primaryState: UnifiedCoachPrimaryState.recovery,
  primaryPriority: UnifiedCoachPriority.protectRecovery,
  primaryInsight: 'Shared insight',
  primaryAction: action,
  userConditionContext: false,
  evidence: const ['shared'],
  dataCoverage: const UnifiedCoachDataCoverage(
    userConditionAvailable: false,
    recoveryAvailable: true,
    dailyDecisionAvailable: false,
    weeklyMissionAvailable: true,
    wearableContextAvailable: false,
  ),
  generatedAt: DateTime(2026, 9, 14),
);

void main() {
  const advisor = TodayWeeklyMissionAdvisor();

  test('current weekly mission is loaded', () async {
    final expected = plan(WeeklyMissionType.protectRecovery);
    final result = await TodayWeeklyMissionLoader(
      () async => expected,
    ).loadSafely();
    expect(result, same(expected));
  });

  test('no weekly plan remains absent', () async {
    final result = await TodayWeeklyMissionLoader(
      () async => null,
    ).loadSafely();
    expect(result, isNull);
    expect(advisor.advise(plan: result, isPlannedTrainingDay: false), isNull);
  });

  test('Weekly Coach load failure is isolated', () async {
    final result = await TodayWeeklyMissionLoader(
      () async => throw Exception('offline'),
    ).loadSafely();
    expect(result, isNull);
  });

  test('training-day consistency guidance reinforces only existing plan', () {
    final result = advisor.advise(
      plan: plan(WeeklyMissionType.improveWorkoutConsistency),
      isPlannedTrainingDay: true,
    )!;
    expect(result.todayFocus, contains('planned session'));
    expect(result.todayFocus, contains('without adding intensity'));
  });

  test('rest-day recovery mission selects one relevant action', () {
    final result = advisor.advise(
      plan: plan(
        WeeklyMissionType.protectRecovery,
        actions: const [
          'Protect sleep tonight.',
          'Training-only action.',
          'Another action.',
        ],
      ),
      isPlannedTrainingDay: false,
    )!;
    expect(result.todayFocus, 'Protect sleep tonight.');
  });

  test('no scheduled workout does not invent one', () {
    final result = advisor.advise(
      plan: plan(WeeklyMissionType.improveWorkoutConsistency),
      isPlannedTrainingDay: false,
    )!;
    expect(result.todayFocus, contains('without inventing a workout'));
    expect(result.missionTitle, 'Authoritative weekly mission');
  });

  test('recovery caution overrides aggressive consistency wording', () {
    final result = advisor.advise(
      plan: plan(WeeklyMissionType.improveWorkoutConsistency),
      isPlannedTrainingDay: true,
      unifiedContext: context('Recovery comes first today.'),
    )!;
    expect(result.todayFocus, contains('Recovery comes first'));
    expect(result.todayFocus, 'Recovery comes first today.');
    expect(result.todayFocus, isNot(contains('Completing')));
  });

  test('user pain and fatigue take precedence over recovery and mission', () {
    final result = advisor.advise(
      plan: plan(WeeklyMissionType.improveWorkoutConsistency),
      isPlannedTrainingDay: true,
      unifiedContext: context('How you feel comes first today.'),
      selfReportedPain: true,
      selfReportedFatigue: true,
    )!;
    expect(result.todayFocus, contains('How you feel comes first'));
    expect(result.todayFocus, isNot(contains('lighter option')));
  });

  test('lighterSession decision is respected', () {
    final result = advisor.advise(
      plan: plan(WeeklyMissionType.improveWorkoutConsistency),
      isPlannedTrainingDay: true,
      dailyDecision: CoachDecision.lighterSession,
    )!;
    expect(result.todayFocus, contains('lighter approach'));
    expect(result.todayFocus, contains('without returning to full'));
  });

  test('plannedSession never increases intensity', () {
    final result = advisor.advise(
      plan: plan(WeeklyMissionType.improveWorkoutConsistency),
      isPlannedTrainingDay: true,
      dailyDecision: CoachDecision.plannedSession,
    )!;
    expect(result.todayFocus, contains('without adding intensity'));
    expect(result.todayFocus, isNot(contains('harder')));
    expect(result.todayFocus, contains('extra work'));
  });

  test('does not repeat full weekly action list or mutate mission', () {
    final original = plan(WeeklyMissionType.improveTrainingNightSleep);
    final result = advisor.advise(plan: original, isPlannedTrainingDay: true)!;
    expect(result.missionTitle, original.missionTitle);
    expect(result.todayFocus, original.actionItems.first);
    expect(result.todayFocus, isNot(contains(original.actionItems[1])));
    expect(original.missionType, WeeklyMissionType.improveTrainingNightSleep);
    expect(original.actionItems, hasLength(3));
  });

  test('integration does not mutate Training, Nutrition, or Progress', () {
    final training = File(
      'lib/screens/training_plan_screen.dart',
    ).readAsStringSync();
    final nutrition = File(
      'lib/services/recovery_nutrition_service.dart',
    ).readAsStringSync();
    final progress = File(
      'lib/services/vision_progress_engine.dart',
    ).readAsStringSync();
    for (final source in [training, nutrition, progress]) {
      expect(source, isNot(contains('TodayWeeklyMission')));
      expect(source, isNot(contains('loadCurrentPlan')));
    }
  });
}
