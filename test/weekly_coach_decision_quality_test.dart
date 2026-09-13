import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/weekly_coach_engine.dart';

final now = DateTime(2026, 9, 14, 9);
final currentWeek = DateTime(2026, 9, 7);
final priorWeek = DateTime(2026, 8, 31);
final baselineWeek = DateTime(2026, 8, 10);
const engine = WeeklyCoachEngine();

WeeklyCoachPlan previous(
  WeeklyMissionType type, {
  WeeklyMissionOutcome priorOutcome = WeeklyMissionOutcome.insufficientData,
}) {
  final title = switch (type) {
    WeeklyMissionType.protectRecovery => 'Protect recovery this week',
    WeeklyMissionType.improveTrainingNightSleep =>
      'Improve sleep around training',
    WeeklyMissionType.improveWorkoutConsistency => 'Build workout consistency',
    WeeklyMissionType.reduceActivityLoad => 'Keep activity load manageable',
    WeeklyMissionType.maintainSuccessfulBehavior =>
      'Repeat last week’s consistency',
  };
  return WeeklyCoachPlan(
    weekStart: priorWeek,
    weekEnd: priorWeek.add(const Duration(days: 6)),
    shortRetrospective: '',
    biggestWin: '',
    mainLimitingFactor: '',
    missionType: type,
    missionTitle: title,
    missionReason: '',
    actionItems: const ['One action.'],
    motivationContext: '',
    previousMissionTitle: priorOutcome == WeeklyMissionOutcome.insufficientData
        ? null
        : title,
    previousMissionOutcome: priorOutcome,
    followUpMessage: '',
    dataCoverage: const WeeklyCoachDataCoverage(
      wearableDays: 7,
      workoutSourceAvailable: true,
    ),
    evidence: const [],
    generatedAt: currentWeek,
  );
}

List<WearableDailyRecord> wearableWeek(
  DateTime start, {
  required int sleep,
  int steps = 7000,
  double hr = 60,
}) => List.generate(
  7,
  (index) => WearableDailyRecord(
    userId: 'user',
    localDate: start.add(Duration(days: index)),
    sourceUpdatedAt: start.add(Duration(days: index)),
    sleepMinutes: sleep,
    steps: steps,
    restingHeartRateBpm: hr,
  ),
);

List<WeeklyWorkoutObservation> workouts(
  DateTime start,
  List<String> statuses,
) => statuses.indexed
    .map(
      (entry) => WeeklyWorkoutObservation(
        start.add(Duration(days: entry.$1)),
        entry.$2,
      ),
    )
    .toList();

void expectOneSupportedPriority(WeeklyCoachPlan result) {
  expect(result.actionItems, isNotEmpty);
  expect(result.actionItems.length, lessThanOrEqualTo(3));
  expect(
    WeeklyMissionType.values.where((value) => value == result.missionType),
    hasLength(1),
  );
  expect(result.evidence, everyElement(isNot(contains('score'))));
}

void main() {
  test('first-ever plan establishes a neutral observable priority', () {
    final result = engine.evaluate(WeeklyCoachInput(now: now));
    expect(result.followUpDirection, WeeklyFollowUpDirection.establishPriority);
    expect(result.missionType, WeeklyMissionType.maintainSuccessfulBehavior);
    expect(result.missionTitle, 'Establish a steady weekly rhythm');
    expect(
      result.evidence.any((item) => item.contains('0 completed')),
      isFalse,
    );
    expectOneSupportedPriority(result);
  });

  test('good adherence and clear improvement reinforces progress', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        previousPlan: previous(WeeklyMissionType.improveWorkoutConsistency),
        workouts: [
          ...workouts(priorWeek, ['completed', 'skipped']),
          ...workouts(currentWeek, ['completed', 'completed']),
        ],
      ),
    );
    expect(result.previousMissionOutcome, WeeklyMissionOutcome.success);
    expect(result.followUpDirection, WeeklyFollowUpDirection.reinforceProgress);
    expectOneSupportedPriority(result);
  });

  test('partial adherence continues the same priority', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        previousPlan: previous(WeeklyMissionType.improveWorkoutConsistency),
        workouts: [
          ...workouts(priorWeek, ['skipped', 'skipped']),
          ...workouts(currentWeek, ['completed', 'skipped']),
        ],
      ),
    );
    expect(
      result.previousMissionOutcome,
      WeeklyMissionOutcome.partialImprovement,
    );
    expect(result.missionType, WeeklyMissionType.improveWorkoutConsistency);
    expect(result.followUpDirection, WeeklyFollowUpDirection.continuePriority);
    expectOneSupportedPriority(result);
  });

  test(
    'repeated poor adherence adjusts the approach without switching issue',
    () {
      final result = engine.evaluate(
        WeeklyCoachInput(
          now: now,
          previousPlan: previous(
            WeeklyMissionType.improveWorkoutConsistency,
            priorOutcome: WeeklyMissionOutcome.unchanged,
          ),
          workouts: [
            ...workouts(priorWeek, ['skipped', 'skipped']),
            ...workouts(currentWeek, ['skipped', 'skipped']),
          ],
        ),
      );
      expect(result.previousMissionOutcome, WeeklyMissionOutcome.unchanged);
      expect(result.missionType, WeeklyMissionType.improveWorkoutConsistency);
      expect(result.followUpDirection, WeeklyFollowUpDirection.adjustPriority);
      expect(result.followUpMessage, contains('adjust the actions'));
      expect(
        result.actionItems.first,
        contains('one realistic training window'),
      );
      expectOneSupportedPriority(result);
    },
  );

  test('completed sleep priority reinforces measured progress', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        previousPlan: previous(WeeklyMissionType.improveTrainingNightSleep),
        wearableHistory: [
          ...wearableWeek(priorWeek, sleep: 390),
          ...wearableWeek(currentWeek, sleep: 430),
        ],
      ),
    );
    expect(result.previousMissionOutcome, WeeklyMissionOutcome.success);
    expect(result.followUpDirection, WeeklyFollowUpDirection.reinforceProgress);
    expectOneSupportedPriority(result);
  });

  test(
    'changed dominant recovery problem replaces prior consistency focus',
    () {
      final result = engine.evaluate(
        WeeklyCoachInput(
          now: now,
          previousPlan: previous(WeeklyMissionType.improveWorkoutConsistency),
          wearableHistory: [
            ...wearableWeek(baselineWeek, sleep: 450),
            ...wearableWeek(currentWeek, sleep: 350, steps: 12000, hr: 68),
          ],
          workouts: [
            ...workouts(priorWeek, ['skipped', 'skipped']),
            ...workouts(currentWeek, ['skipped', 'skipped']),
          ],
        ),
      );
      expect(result.missionType, WeeklyMissionType.protectRecovery);
      expect(result.followUpDirection, WeeklyFollowUpDirection.replacePriority);
      expect(
        result.evidence.any((item) => item.contains('personal baseline')),
        isTrue,
      );
      expectOneSupportedPriority(result);
    },
  );

  test('insufficient validated history does not make a confident change', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        previousPlan: previous(WeeklyMissionType.improveTrainingNightSleep),
        workoutSourceAvailable: false,
      ),
    );
    expect(
      result.previousMissionOutcome,
      WeeklyMissionOutcome.insufficientData,
    );
    expect(
      result.followUpDirection,
      WeeklyFollowUpDirection.insufficientEvidence,
    );
    expect(result.evidence, isEmpty);
    expectOneSupportedPriority(result);
  });

  test('conflicting signals still produce one recovery-first priority', () {
    final result = engine.evaluate(
      WeeklyCoachInput(
        now: now,
        wearableHistory: [
          ...wearableWeek(baselineWeek, sleep: 450, steps: 7000, hr: 60),
          ...wearableWeek(currentWeek, sleep: 350, steps: 12000, hr: 68),
        ],
        workouts: workouts(currentWeek, ['completed', 'skipped']),
      ),
    );
    expect(result.missionType, WeeklyMissionType.protectRecovery);
    expect(result.followUpDirection, WeeklyFollowUpDirection.establishPriority);
    expectOneSupportedPriority(result);
  });

  test(
    'no wearable data uses observed training rather than fabricated metrics',
    () {
      final result = engine.evaluate(
        WeeklyCoachInput(
          now: now,
          workouts: workouts(currentWeek, ['completed', 'skipped']),
        ),
      );
      expect(result.dataCoverage.wearableDays, 0);
      expect(result.missionType, WeeklyMissionType.improveWorkoutConsistency);
      expect(
        result.followUpDirection,
        WeeklyFollowUpDirection.establishPriority,
      );
      expect(result.evidence.single, contains('1 of 2 observed'));
      expectOneSupportedPriority(result);
    },
  );
}
