import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/daily_activity_state.dart';
import 'package:future_project/models/today_mission.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/today_mission_engine.dart';

void main() {
  final now = DateTime(2026, 9, 15, 10);
  const engine = TodayMissionEngine();

  UnifiedCoachContext context(UnifiedCoachPrimaryState state) =>
      UnifiedCoachContext(
        localDate: now,
        primaryState: state,
        primaryPriority: state == UnifiedCoachPrimaryState.recovery
            ? UnifiedCoachPriority.protectRecovery
            : UnifiedCoachPriority.maintainHealthyPattern,
        primaryInsight: 'Validated context.',
        primaryAction: 'Protect recovery today.',
        userConditionContext: false,
        evidence: const ['validated_context'],
        dataCoverage: const UnifiedCoachDataCoverage(
          userConditionAvailable: false,
          recoveryAvailable: true,
          dailyDecisionAvailable: false,
          weeklyMissionAvailable: false,
          wearableContextAvailable: false,
        ),
        generatedAt: now,
      );

  DailyActivityState state(List<DailyActivityRecord> activities) =>
      DailyActivityState(
        localDate: now,
        activities: activities,
        coverage: const DailyActivityCoverage(
          workoutAvailable: true,
          nutritionAvailable: true,
          reflectionAvailable: true,
          weeklyMissionAvailable: true,
          dailyDecisionAvailable: true,
          visionAvailable: true,
        ),
        visionIdentity: 'becoming a consistent athlete',
        generatedAt: now,
      );

  test('recovery safety remains above available daily activities', () {
    final result = engine.evaluate(
      TodayMissionInput(
        coachContext: context(UnifiedCoachPrimaryState.recovery),
        activityState: state([
          DailyActivityRecord(
            localDate: now,
            activityIdentity: 'workout:1',
            type: DailyActivityType.workout,
            status: DailyActivityStatus.planned,
            sourceTable: 'workout_sessions',
          ),
        ]),
      ),
    );
    expect(result.action, 'Protect recovery today.');
    expect(result.sourcePriority, UnifiedCoachPrimaryState.recovery);
  });

  test('recorded workout is read as complete without another check', () {
    final plan = WeeklyCoachPlan(
      weekStart: DateTime(2026, 9, 14),
      weekEnd: DateTime(2026, 9, 20),
      shortRetrospective: '',
      biggestWin: '',
      mainLimitingFactor: '',
      missionType: WeeklyMissionType.improveWorkoutConsistency,
      missionTitle: 'Keep training consistent',
      missionReason: 'Consistency supports the goal.',
      actionItems: const ['Follow the existing plan.'],
      motivationContext: '',
      previousMissionOutcome: WeeklyMissionOutcome.insufficientData,
      followUpMessage: '',
      dataCoverage: const WeeklyCoachDataCoverage(
        wearableDays: 0,
        workoutSourceAvailable: true,
      ),
      evidence: const [],
      generatedAt: now,
    );
    final result = engine.evaluate(
      TodayMissionInput(
        coachContext: context(UnifiedCoachPrimaryState.weeklyMission),
        weeklyPlan: plan,
        activityState: state([
          DailyActivityRecord(
            localDate: now,
            activityIdentity: 'workout:abc',
            type: DailyActivityType.workout,
            status: DailyActivityStatus.completed,
            sourceTable: 'workout_sessions',
          ),
        ]),
      ),
    );
    expect(result.alreadyCompleted, isTrue);
    expect(result.activityIdentity, 'workout:abc');
    expect(result.action, contains('do not add extra work'));
  });

  test('general guidance chooses one existing flow without writing it', () {
    final TodayMission result = engine.evaluate(
      TodayMissionInput(
        coachContext: context(UnifiedCoachPrimaryState.general),
        activityState: state(const []),
      ),
    );
    expect(result.activityIdentity, 'nutrition:daily');
    expect(result.action, contains('existing Nutrition flow'));
  });

  test('completed nutrition and reflection are not recommended again', () {
    final result = engine.evaluate(
      TodayMissionInput(
        coachContext: context(UnifiedCoachPrimaryState.general),
        activityState: state([
          DailyActivityRecord(
            localDate: now,
            activityIdentity: 'nutrition:daily',
            type: DailyActivityType.nutrition,
            status: DailyActivityStatus.completed,
            sourceTable: 'nutrition_food_logs',
          ),
          DailyActivityRecord(
            localDate: now,
            activityIdentity: 'reflection:daily',
            type: DailyActivityType.reflection,
            status: DailyActivityStatus.completed,
            sourceTable: 'vision_daily_reflections',
          ),
        ]),
      ),
    );
    expect(result.activityIdentity, isNull);
    expect(result.action, isNot(contains('Nutrition')));
    expect(result.action, isNot(contains('Reflection')));
  });
}
