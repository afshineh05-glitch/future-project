import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/weekly_coach_engine.dart';
import 'package:future_project/services/weekly_coach_service.dart';

WeeklyCoachPlan plan({
  required String title,
  String? previousTitle,
  WeeklyMissionType type = WeeklyMissionType.improveWorkoutConsistency,
  WeeklyMissionOutcome outcome = WeeklyMissionOutcome.insufficientData,
}) => WeeklyCoachPlan(
  weekStart: DateTime(2026, 9, 14),
  weekEnd: DateTime(2026, 9, 20),
  shortRetrospective: 'Brief retrospective.',
  biggestWin: 'One supported win.',
  mainLimitingFactor: '',
  missionType: type,
  missionTitle: title,
  missionReason: 'Reason tied to the current goal.',
  actionItems: const ['One achievable action.'],
  motivationContext: 'Supported motivation.',
  previousMissionTitle: previousTitle,
  previousMissionOutcome: outcome,
  followUpMessage: 'Deterministic follow-up.',
  dataCoverage: const WeeklyCoachDataCoverage(
    wearableDays: 0,
    workoutSourceAvailable: true,
  ),
  evidence: const [],
  generatedAt: DateTime(2026, 9, 14),
);

class FakeWeeklyCoachStore implements WeeklyCoachStore {
  final Map<String, WeeklyCoachPlan> plans = {};
  int wearableLoads = 0;
  int workoutLoads = 0;
  int upserts = 0;

  @override
  String? currentUserId = 'user';

  @override
  Future<WeeklyCoachPlan?> loadForWeek(DateTime weekStart) async =>
      plans[WeeklyCoachPlan.dateKey(weekStart)];

  @override
  Future<String> loadPrimaryGoal() async => 'build_muscle';

  @override
  Future<List<WearableDailyRecord>> loadWearableHistory(DateTime since) async {
    wearableLoads++;
    return const [];
  }

  @override
  Future<List<WeeklyWorkoutObservation>> loadWorkoutHistory(
    DateTime since,
  ) async {
    workoutLoads++;
    return const [];
  }

  @override
  Future<WeeklyCoachPlan> upsert(WeeklyCoachPlan value) async {
    upserts++;
    plans[WeeklyCoachPlan.dateKey(value.weekStart)] = value;
    return value;
  }
}

void main() {
  test('follow-up direction adjusts an unchanged canonical priority', () {
    final value = plan(
      title: 'Build workout consistency',
      previousTitle: 'Build workout consistency',
      outcome: WeeklyMissionOutcome.unchanged,
    );
    expect(value.followUpDirection, WeeklyFollowUpDirection.adjustPriority);
  });

  test(
    'follow-up direction distinguishes adjust, progress, and replacement',
    () {
      expect(
        plan(
          title: 'Build workout consistency',
          previousTitle: 'Build workout consistency',
          outcome: WeeklyMissionOutcome.partialImprovement,
        ).followUpDirection,
        WeeklyFollowUpDirection.continuePriority,
      );
      expect(
        plan(
          title: 'Build workout consistency',
          previousTitle: 'Build workout consistency',
          outcome: WeeklyMissionOutcome.success,
        ).followUpDirection,
        WeeklyFollowUpDirection.reinforceProgress,
      );
      expect(
        plan(
          title: 'Protect recovery this week',
          previousTitle: 'Build workout consistency',
          outcome: WeeklyMissionOutcome.unchanged,
        ).followUpDirection,
        WeeklyFollowUpDirection.replacePriority,
      );
    },
  );

  test(
    'existing current plan is reused without duplicate observation or save',
    () async {
      final store = FakeWeeklyCoachStore();
      final existing = plan(title: 'Build workout consistency');
      store.plans['2026-09-14'] = existing;
      final service = WeeklyCoachService(
        store: store,
        clock: () => DateTime(2026, 9, 16),
      );

      expect(await service.loadOrGenerateCurrentPlan(), same(existing));
      expect(store.wearableLoads, 0);
      expect(store.workoutLoads, 0);
      expect(store.upserts, 0);
    },
  );

  test(
    'missing current plan is deterministically observed and persisted once',
    () async {
      final store = FakeWeeklyCoachStore();
      final service = WeeklyCoachService(
        store: store,
        clock: () => DateTime(2026, 9, 16),
      );

      final generated = await service.loadOrGenerateCurrentPlan();
      expect(generated.weekStart, DateTime(2026, 9, 14));
      expect(generated.actionItems, isNotEmpty);
      expect(generated.actionItems.length, lessThanOrEqualTo(3));
      expect(store.wearableLoads, 1);
      expect(store.workoutLoads, 1);
      expect(store.upserts, 1);
    },
  );

  test(
    'same-week refresh updates one canonical plan key without a duplicate',
    () async {
      final store = FakeWeeklyCoachStore();
      final service = WeeklyCoachService(
        store: store,
        clock: () => DateTime(2026, 9, 16),
      );

      await service.generateAndSave();
      await service.generateAndSave();

      expect(store.plans.keys, ['2026-09-14']);
      expect(store.upserts, 2);
    },
  );

  test('Weekly Coach UI emphasizes this week without parallel decisions', () {
    final screen = File(
      'lib/screens/weekly_coach_screen.dart',
    ).readAsStringSync();
    expect(
      screen.indexOf("title: 'Last Week'"),
      lessThan(screen.indexOf("title: 'This Week'")),
    );
    expect(screen, contains('YOUR ONE PRIORITY'));
    expect(screen, contains('plan.missionTitle'));
    expect(screen, contains('plan.actionItems'));
    expect(
      screen,
      contains('_FollowUpStatus(direction: plan.followUpDirection)'),
    );
    expect(
      screen,
      contains("WeeklyFollowUpDirection.continuePriority => 'Continue'"),
    );
    expect(screen, contains('loadOrGenerateCurrentPlan'));
    expect(screen, isNot(contains('WeeklyCoachEngine')));
    expect(screen, isNot(contains('readinessScore')));
  });
}
