import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/services/health/recovery_context_engine.dart';

void main() {
  const engine = RecoveryContextEngine();
  final now = DateTime(2026, 9, 10, 12);

  WearableDailyRecord record(
    int daysAgo, {
    int? sleepMinutes = 480,
    double? restingHeartRate = 60,
    int? steps = 8000,
    double? activeEnergy = 500,
    double? distance = 6000,
  }) => WearableDailyRecord(
    userId: 'user-1',
    localDate: DateTime(2026, 9, 10).subtract(Duration(days: daysAgo)),
    sleepMinutes: sleepMinutes,
    restingHeartRateBpm: restingHeartRate,
    steps: steps,
    activeEnergyKilocalories: activeEnergy,
    distanceMeters: distance,
    sourceUpdatedAt: now.subtract(Duration(days: daysAgo)),
  );

  List<WearableDailyRecord> history({
    int? latestSleep = 480,
    double? latestHeartRate = 60,
    double? latestEnergy = 500,
  }) => [
    record(
      0,
      sleepMinutes: latestSleep,
      restingHeartRate: latestHeartRate,
      activeEnergy: latestEnergy,
    ),
    for (var day = 1; day <= 5; day++) record(day),
  ];

  RecoveryContext evaluate(List<WearableDailyRecord> records) =>
      engine.evaluate(RecoveryContextInput(wearableHistory: records, now: now));

  test('insufficient history does not claim recovery state', () {
    final result = evaluate([record(0), record(1), record(2)]);

    expect(result.overallState, RecoveryContextState.insufficientData);
    expect(result.sleepContext.baselineDays, 2);
  });

  test('normal values are compared with personal baseline', () {
    final result = evaluate(history());

    expect(result.overallState, RecoveryContextState.normal);
    expect(result.sleepContext.state, RecoveryContextState.normal);
    expect(result.sleepContext.personalBaseline, 480);
    expect(result.restingHeartRateContext.personalBaseline, 60);
  });

  test('materially lower sleep produces sleep caution', () {
    final result = evaluate(history(latestSleep: 360));

    expect(result.sleepContext.state, RecoveryContextState.caution);
    expect(result.sleepContext.latestValue, 360);
    expect(result.sleepContext.personalBaseline, 480);
    expect(
      result.sleepContext.evidence,
      contains(RecoveryEvidenceCode.sleepBelowPersonalBaseline),
    );
  });

  test('elevated resting HR is relative to personal baseline', () {
    final result = evaluate(history(latestHeartRate: 68));

    expect(result.restingHeartRateContext.state, RecoveryContextState.caution);
    expect(result.restingHeartRateContext.personalBaseline, 60);
  });

  test('missing sleep is not converted to zero or caution', () {
    final result = evaluate(history(latestSleep: null));

    expect(result.sleepContext.latestValue, isNull);
    expect(result.sleepContext.state, RecoveryContextState.insufficientData);
    expect(result.overallState, RecoveryContextState.normal);
  });

  test('missing resting HR does not imply caution', () {
    final result = evaluate(history(latestHeartRate: null));

    expect(result.restingHeartRateContext.latestValue, isNull);
    expect(
      result.restingHeartRateContext.state,
      RecoveryContextState.insufficientData,
    );
    expect(result.overallState, RecoveryContextState.normal);
  });

  test('one caution conflicting with normal signals stays descriptive', () {
    final result = evaluate(history(latestSleep: 360));

    expect(result.overallState, RecoveryContextState.normal);
    expect(result.evidence, contains(RecoveryEvidenceCode.conflictingSignals));
  });

  test('multiple caution signals produce overall caution', () {
    final result = evaluate(history(latestSleep: 360, latestHeartRate: 68));

    expect(result.overallState, RecoveryContextState.caution);
  });

  test('one bad metric does not invalidate other valid trends', () {
    final result = evaluate(history(latestEnergy: -10));

    expect(result.recentActivityContext.state, RecoveryContextState.normal);
    expect(result.recentActivityContext.unit, 'meters');
    expect(result.sleepContext.state, RecoveryContextState.normal);
    expect(result.restingHeartRateContext.state, RecoveryContextState.normal);
  });

  test('implausible stored physiological values are not interpreted', () {
    final result = evaluate(history(latestHeartRate: 500));

    expect(result.restingHeartRateContext.latestValue, isNull);
    expect(
      result.restingHeartRateContext.state,
      RecoveryContextState.insufficientData,
    );
  });

  test('recent app workouts are exposed as context only', () {
    final result = engine.evaluate(
      RecoveryContextInput(
        wearableHistory: history(),
        completedWorkoutDates: [now.subtract(const Duration(days: 2))],
        now: now,
      ),
    );

    expect(result.recentWorkoutContext.state, RecoveryContextState.normal);
    expect(result.recentWorkoutContext.completedSessionsLast7Days, 1);
    expect(result.overallState, RecoveryContextState.normal);
  });

  test('public recovery model has no numeric readiness score', () {
    final source = File('lib/models/recovery_context.dart').readAsStringSync();

    expect(source, isNot(contains('readinessScore')));
    expect(source, isNot(contains('recoveryScore')));
  });
}
