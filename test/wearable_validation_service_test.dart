import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:future_project/services/health/wearable_validation_service.dart';
import 'package:future_project/services/vision_progress_engine.dart';

void main() {
  const validator = WearableValidationService();
  final now = DateTime(2026, 9, 9, 12);

  WearableData data({
    int? steps = 12450,
    double? restingHeartRate = 60,
    double? weight = 80,
    Duration? sleep = const Duration(hours: 8),
    Set<String> unavailable = const {},
    Map<WearableMetric, DateTime>? dates,
  }) => WearableData(
    rangeStart: DateTime(2026, 9, 9),
    rangeEnd: now,
    permissionStatus: WearablePermissionStatus.authorized,
    steps: steps,
    restingHeartRateBpm: restingHeartRate,
    bodyWeightKilograms: weight,
    sleepDuration: sleep,
    workouts: const [],
    unavailableMetrics: unavailable,
    sourceDates:
        dates ??
        {
          WearableMetric.steps: now,
          WearableMetric.restingHeartRate: now,
          WearableMetric.bodyWeight: now,
          WearableMetric.sleepDuration: now,
        },
  );

  test('classifies each metric independently', () {
    final result = validator.validate(
      data(restingHeartRate: 500, weight: null),
      now: now,
    );

    expect(result.steps.status, WearableValidationStatus.valid);
    expect(result.steps.value, 12450);
    expect(
      result.restingHeartRateBpm.status,
      WearableValidationStatus.implausible,
    );
    expect(result.restingHeartRateBpm.value, isNull);
    expect(result.bodyWeightKilograms.status, WearableValidationStatus.missing);
  });

  test('distinguishes stale, unavailable, and absent values from zero', () {
    final result = validator.validate(
      data(
        steps: 0,
        restingHeartRate: null,
        unavailable: const {'WEIGHT'},
        dates: {
          WearableMetric.steps: now.subtract(const Duration(days: 2)),
          WearableMetric.sleepDuration: now,
        },
      ),
      now: now,
    );

    expect(result.steps.status, WearableValidationStatus.stale);
    expect(result.steps.rawValue, 0);
    expect(result.steps.value, isNull);
    expect(result.restingHeartRateBpm.status, WearableValidationStatus.missing);
    expect(
      result.bodyWeightKilograms.status,
      WearableValidationStatus.unavailable,
    );
  });

  test('rejects an implausible workout without rejecting valid steps', () {
    final result = validator.validate(
      WearableData(
        rangeStart: DateTime(2026, 9, 9),
        rangeEnd: now,
        permissionStatus: WearablePermissionStatus.authorized,
        steps: 1000,
        workouts: [
          WearableWorkout(
            activityType: 'RUNNING',
            start: now.subtract(const Duration(hours: 30)),
            end: now,
            duration: const Duration(hours: 30),
            sourceName: 'Test',
          ),
        ],
        unavailableMetrics: const {},
        sourceDates: {
          WearableMetric.steps: now,
          WearableMetric.workouts: now,
          WearableMetric.workoutDuration: now,
        },
      ),
      now: now,
    );

    expect(result.steps.status, WearableValidationStatus.valid);
    expect(result.workouts.status, WearableValidationStatus.implausible);
    expect(result.workoutDuration.value, isNull);
  });

  test('validated context does not change Phase 2 progress scoring', () {
    final context = validator.validate(data(), now: now);
    const engine = VisionProgressEngine();
    final withoutWearable = engine.evaluate(VisionProgressInput(now: now));
    final withContext = engine.evaluate(
      VisionProgressInput(now: now, wearableContext: context),
    );

    expect(withContext.overallProgress, withoutWearable.overallProgress);
    expect(withContext.confidence, withoutWearable.confidence);
    expect(
      withContext.signals
          .singleWhere(
            (signal) => signal.type == VisionProgressSignalType.wearable,
          )
          .available,
      isFalse,
    );
  });
}
