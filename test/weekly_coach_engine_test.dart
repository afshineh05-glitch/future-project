import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/weekly_coach_engine.dart';

WearableDailyRecord day(
  DateTime date, {
  int? sleep = 450,
  int? steps = 7000,
  double? hr = 60,
}) => WearableDailyRecord(
  userId: 'u',
  localDate: date,
  sourceUpdatedAt: date,
  sleepMinutes: sleep,
  steps: steps,
  restingHeartRateBpm: hr,
);

List<WearableDailyRecord> week(
  DateTime monday, {
  required int sleep,
  int steps = 7000,
  double hr = 60,
}) => List.generate(
  7,
  (i) => day(
    monday.add(Duration(days: i)),
    sleep: sleep,
    steps: steps,
    hr: hr,
  ),
);

WeeklyCoachPlan previous(WeeklyMissionType type) => WeeklyCoachPlan(
  weekStart: DateTime(2026, 8, 31),
  weekEnd: DateTime(2026, 9, 6),
  shortRetrospective: '',
  biggestWin: '',
  mainLimitingFactor: '',
  missionType: type,
  missionTitle: 'Previous mission',
  missionReason: '',
  actionItems: const ['One'],
  motivationContext: '',
  previousMissionOutcome: WeeklyMissionOutcome.insufficientData,
  followUpMessage: '',
  dataCoverage: const WeeklyCoachDataCoverage(
    wearableDays: 7,
    workoutSourceAvailable: true,
  ),
  evidence: const [],
  generatedAt: DateTime(2026, 9, 7),
);

void main() {
  const engine = WeeklyCoachEngine();
  final now = DateTime(2026, 9, 14, 9);
  final completed = DateTime(2026, 9, 7);
  final prior = DateTime(2026, 8, 31);
  final baseline = DateTime(2026, 8, 10);

  test('insufficient and missing wearable data falls back without failure', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        wearableHistory: const [],
        workouts: [WeeklyWorkoutObservation(completed, 'completed')],
      ),
    );
    expect(result.dataCoverage.wearableDays, 0);
    expect(result.dataCoverage.summary, contains('unavailable'));
    expect(result.missionType, WeeklyMissionType.improveWorkoutConsistency);
  });

  test('compares completed week with previous week and personal baseline', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        wearableHistory: [
          ...week(baseline, sleep: 450),
          ...week(prior, sleep: 410),
          ...week(completed, sleep: 390),
        ],
      ),
    );
    expect(result.evidence.any((e) => e.contains('previous week')), isTrue);
    expect(result.evidence.any((e) => e.contains('personal baseline')), isTrue);
    expect(result.missionType, WeeklyMissionType.improveTrainingNightSleep);
  });

  test('clear positive training trend drives real motivation', () {
    final workouts = [
      WeeklyWorkoutObservation(prior, 'completed'),
      ...List.generate(
        3,
        (i) => WeeklyWorkoutObservation(
          completed.add(Duration(days: i)),
          'completed',
        ),
      ),
    ];
    final result = engine.evaluate(
      WeeklyCoachInput(now: now, workouts: workouts),
    );
    expect(result.biggestWin, contains('up from 1'));
    expect(result.motivationContext, contains('from 1 to 3'));
  });

  test(
    'clear negative recovery trend selects one priority without alert flood',
    () {
      final result = engine.evaluate(
        WeeklyCoachInput(
          now: now,
          wearableHistory: [
            ...week(baseline, sleep: 450),
            ...week(completed, sleep: 350, steps: 12000, hr: 68),
          ],
        ),
      );
      expect(result.missionType, WeeklyMissionType.protectRecovery);
      expect(result.actionItems.length, lessThanOrEqualTo(3));
      expect(
        WeeklyMissionType.values.where((e) => e == result.missionType),
        hasLength(1),
      );
    },
  );

  test(
    'mission is current-week, concrete, goal-aware, and max three actions',
    () {
      final result = engine.evaluate(
        WeeklyCoachInput(now: now, primaryGoal: 'build_muscle'),
      );
      expect(result.weekStart, DateTime(2026, 9, 14));
      expect(result.missionReason, contains('build muscle'));
      expect(result.actionItems, isNotEmpty);
      expect(result.actionItems.length, lessThanOrEqualTo(3));
    },
  );

  test('previous sleep mission success is deterministic', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        previousPlan: previous(WeeklyMissionType.improveTrainingNightSleep),
        wearableHistory: [
          ...week(prior, sleep: 390),
          ...week(completed, sleep: 430),
        ],
      ),
    );
    expect(result.previousMissionOutcome, WeeklyMissionOutcome.success);
    expect(result.followUpMessage, contains('improved'));
  });

  test('previous sleep mission partial improvement is deterministic', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        previousPlan: previous(WeeklyMissionType.improveTrainingNightSleep),
        wearableHistory: [
          ...week(prior, sleep: 390),
          ...week(completed, sleep: 405),
        ],
      ),
    );
    expect(
      result.previousMissionOutcome,
      WeeklyMissionOutcome.partialImprovement,
    );
  });

  test('previous mission unchanged stays focused', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        previousPlan: previous(WeeklyMissionType.improveTrainingNightSleep),
        wearableHistory: [
          ...week(prior, sleep: 410),
          ...week(completed, sleep: 400),
        ],
      ),
    );
    expect(result.previousMissionOutcome, WeeklyMissionOutcome.unchanged);
    expect(result.followUpMessage, contains('another week'));
  });

  test('previous mission is insufficient when its source is missing', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        previousPlan: previous(WeeklyMissionType.improveWorkoutConsistency),
        workoutSourceAvailable: false,
      ),
    );
    expect(
      result.previousMissionOutcome,
      WeeklyMissionOutcome.insufficientData,
    );
    expect(result.followUpMessage, contains('cannot be evaluated reliably'));
  });

  test('nutrition absence is explicit and never treated as failure', () {
    final result = engine.evaluate(WeeklyCoachInput(now: now));
    expect(result.dataCoverage.nutritionSourceAvailable, isFalse);
    expect(result.mainLimitingFactor, isNot(contains('nutrition')));
  });

  test('public model has no numeric readiness score or authoritative AI', () {
    final model = File('lib/models/weekly_coach_plan.dart').readAsStringSync();
    final engineSource = File(
      'lib/services/weekly_coach_engine.dart',
    ).readAsStringSync();
    expect(model, isNot(contains('readinessScore')));
    expect(engineSource, isNot(contains('OpenAI')));
    expect(engineSource, isNot(contains('supabase.functions')));
  });

  test(
    'Training Plan, Nutrition targets, and Progress Engine remain unchanged',
    () {
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
        expect(source, isNot(contains('WeeklyCoach')));
        expect(source, isNot(contains('coach_weekly_plans')));
      }
    },
  );
}
