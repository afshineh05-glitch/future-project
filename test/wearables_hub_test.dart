import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/wearables_hub.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/health/wearable_validation_service.dart';
import 'package:future_project/services/wearables_hub_service.dart';

final now = DateTime(2026, 9, 10, 12);
const engine = WearablesHubEngine();

ConnectedHealthSource source(WearablePermissionStatus status) =>
    ConnectedHealthSource(
      provider: WearableProvider.appleHealth,
      displayName: 'Apple Health',
      permissionStatus: status,
      dataAvailable: false,
    );

WearableDailyRecord record(int daysAgo, {int? sleep = 420, int? steps = 7000}) {
  final date = DateTime(2026, 9, 10).subtract(Duration(days: daysAgo));
  return WearableDailyRecord(
    userId: 'u',
    localDate: date,
    sourceUpdatedAt: date,
    sleepMinutes: sleep,
    steps: steps,
    restingHeartRateBpm: 60,
  );
}

WearableData raw({int? steps, DateTime? sourceDate}) => WearableData(
  rangeStart: DateTime(2026, 9, 10),
  rangeEnd: now,
  permissionStatus: WearablePermissionStatus.authorized,
  workouts: const [],
  unavailableMetrics: const {},
  steps: steps,
  sourceDates: sourceDate == null
      ? const {}
      : {WearableMetric.steps: sourceDate},
);

RecoveryContext recovery(RecoveryContextState state) => RecoveryContext(
  overallState: state,
  sleepContext: const RecoveryMetricContext(
    state: RecoveryContextState.normal,
    latestValue: 378,
    personalBaseline: 420,
    baselineDays: 7,
    unit: 'minutes',
    evidence: [],
  ),
  restingHeartRateContext: const RecoveryMetricContext(
    state: RecoveryContextState.normal,
    latestValue: 61,
    personalBaseline: 60,
    baselineDays: 7,
    unit: 'bpm',
    evidence: [],
  ),
  recentActivityContext: const RecoveryMetricContext(
    state: RecoveryContextState.normal,
    latestValue: 7000,
    personalBaseline: 6500,
    baselineDays: 7,
    unit: 'steps',
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
  missionTitle: 'Keep workout consistency',
  missionReason: '',
  actionItems: const ['Record today’s completed session.'],
  motivationContext: '',
  previousMissionOutcome: WeeklyMissionOutcome.insufficientData,
  followUpMessage: '',
  dataCoverage: const WeeklyCoachDataCoverage(
    wearableDays: 7,
    workoutSourceAvailable: true,
  ),
  evidence: const [],
  generatedAt: now,
);

void main() {
  test('supported Apple Health state is represented accurately', () {
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
    );
    expect(data.source.provider, WearableProvider.appleHealth);
    expect(data.source.displayName, 'Apple Health');
  });

  test(
    'unsupported, denied, and partial permission states remain distinct',
    () {
      for (final status in [
        WearablePermissionStatus.unsupportedPlatform,
        WearablePermissionStatus.denied,
        WearablePermissionStatus.partiallyAuthorized,
      ]) {
        expect(
          engine
              .build(source: source(status), now: now)
              .source
              .permissionStatus,
          status,
        );
      }
    },
  );

  test('missing today data is absent and never zero', () {
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
    );
    expect(data.today, isNull);
  });

  test('stale wearable data is identified by canonical validation', () {
    final validated = const WearableValidationService().validate(
      raw(steps: 8000, sourceDate: now.subtract(const Duration(days: 3))),
      now: now,
    );
    expect(validated.steps.status, WearableValidationStatus.stale);
    expect(validated.steps.value, isNull);
  });

  test('invalid wearable data is excluded by medical validation', () {
    final validated = const WearableValidationService().validate(
      raw(steps: -100, sourceDate: now),
      now: now,
    );
    expect(validated.steps.status, WearableValidationStatus.implausible);
    expect(validated.steps.value, isNull);
  });

  test('personal baseline objects are reused without recalculation', () {
    final context = recovery(RecoveryContextState.normal);
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
      recoveryContext: context,
    );
    expect(data.recoveryContext, same(context));
    expect(data.recoveryContext!.sleepContext.personalBaseline, 420);
  });

  test('insufficient baseline history remains insufficient', () {
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
      history: [record(0), record(1)],
    );
    expect(
      data.trends.every(
        (trend) => trend.direction == WearableTrendDirection.insufficientData,
      ),
      isTrue,
    );
  });

  test('7-day trend supports partial coverage', () {
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
      history: [
        record(6, steps: 4000),
        record(4, steps: 5000),
        record(2, steps: 7000),
        record(0, steps: 8000),
      ],
    );
    final steps = data.trends.firstWhere((trend) => trend.metric == 'Steps');
    expect(steps.coverageDays, 4);
    expect(steps.direction, WearableTrendDirection.increasing);
  });

  test('recovery caution takes precedence', () {
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
      recoveryContext: recovery(RecoveryContextState.caution),
      dailyDecision: CoachDecision.plannedSession,
      weeklyPlan: weekly(),
    );
    expect(data.coachInsight!.evidence, ['recovery_caution']);
  });

  test('favorable recovery never increases intensity', () {
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
      recoveryContext: recovery(RecoveryContextState.favorable),
    );
    expect(
      data.coachInsight!.nextAction,
      contains('without adding extra intensity'),
    );
  });

  test('lighterSession is respected before weekly mission', () {
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
      dailyDecision: CoachDecision.lighterSession,
      weeklyPlan: weekly(),
    );
    expect(data.coachInsight!.evidence, ['lighter_session_decision']);
    expect(data.coachInsight!.nextAction, contains('without returning'));
    expect(data.coachInsight!.nextAction, isNot(contains('Increase')));
  });

  test('user fatigue or pain has highest precedence', () {
    final data = engine.build(
      source: source(WearablePermissionStatus.authorized),
      now: now,
      recoveryContext: recovery(RecoveryContextState.caution),
      dailyDecision: CoachDecision.lighterSession,
      selfReportedPainOrFatigue: true,
    );
    expect(data.coachInsight!.evidence, ['user_reported_condition']);
  });

  test(
    'weekly mission stays authoritative with exactly one insight and action',
    () {
      final mission = weekly();
      final data = engine.build(
        source: source(WearablePermissionStatus.authorized),
        now: now,
        weeklyPlan: mission,
      );
      expect(data.weeklyPlan, same(mission));
      expect(data.coachInsight!.insight, isNotEmpty);
      expect(data.coachInsight!.nextAction, mission.actionItems.single);
      expect(data.coachInsight!.evidence, hasLength(1));
    },
  );

  test('body weight is contextual and protected features are not mutated', () {
    final screen = File(
      'lib/screens/wearables_hub_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/wearables_hub_service.dart',
    ).readAsStringSync();
    expect(screen, contains('Context only'));
    expect(service, isNot(contains("from('body_progress_checks')")));
    expect(service, isNot(contains("from('training_plans')")));
    expect(service, isNot(contains('calorie_target')));
    expect(service, isNot(contains('OpenAI')));
    expect(service, isNot(contains('.insert(')));
    expect(service, isNot(contains('.upsert(')));
    for (final path in [
      'lib/screens/training_plan_screen.dart',
      'lib/services/recovery_nutrition_service.dart',
      'lib/services/vision_progress_engine.dart',
    ]) {
      expect(File(path).readAsStringSync(), isNot(contains('WearablesHub')));
    }
  });

  test('model is provider-agnostic and has no readiness score', () {
    final model = File('lib/models/wearables_hub.dart').readAsStringSync();
    expect(model, contains('WearableProvider'));
    expect(model, contains('ConnectedHealthSource'));
    expect(model, isNot(contains('AppleWatch')));
    expect(model, isNot(contains('readinessScore')));
  });
}
