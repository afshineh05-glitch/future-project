import 'package:future_project/models/wearable_data.dart';

/// Central conservative sanity and freshness rules for normalized health data.
/// These checks reject impossible/contextually unusable values; they do not
/// diagnose health conditions or establish clinical accuracy.
class WearableValidationService {
  static const minimumBodyWeightKg = 30.0;
  static const maximumBodyWeightKg = 350.0;
  static const defaultFreshness = Duration(hours: 36);

  const WearableValidationService();

  static bool isPlausibleBodyWeightKg(double value) =>
      value.isFinite &&
      value >= minimumBodyWeightKg &&
      value <= maximumBodyWeightKg;

  ValidatedWearableData validate(WearableData data, {DateTime? now}) {
    final checkedAt = now ?? DateTime.now();
    final validWorkouts = data.workouts.where(_isPlausibleWorkout).toList();
    final rawWorkoutDuration = data.workouts.fold(
      Duration.zero,
      (total, workout) => total + workout.duration,
    );
    final validWorkoutDuration = validWorkouts.fold(
      Duration.zero,
      (total, workout) => total + workout.duration,
    );
    final workoutsStatus = _collectionStatus(
      data: data,
      metric: WearableMetric.workouts,
      unavailableTypes: const {'WORKOUT'},
      isMissing: data.workouts.isEmpty,
      isPlausible: validWorkouts.length == data.workouts.length,
      now: checkedAt,
    );
    final durationStatus = _collectionStatus(
      data: data,
      metric: WearableMetric.workoutDuration,
      unavailableTypes: const {'WORKOUT'},
      isMissing: data.workouts.isEmpty,
      isPlausible: validWorkouts.length == data.workouts.length,
      now: checkedAt,
    );

    return ValidatedWearableData(
      rangeStart: data.rangeStart,
      rangeEnd: data.rangeEnd,
      permissionStatus: data.permissionStatus,
      unavailableMetrics: data.unavailableMetrics,
      steps: _metric(
        data: data,
        metric: WearableMetric.steps,
        raw: data.steps,
        unavailableTypes: const {'STEPS'},
        plausible: (value) => value >= 0 && value <= 100000,
        now: checkedAt,
      ),
      activeEnergyKilocalories: _metric(
        data: data,
        metric: WearableMetric.activeEnergy,
        raw: data.activeEnergyKilocalories,
        unavailableTypes: const {'ACTIVE_ENERGY_BURNED'},
        plausible: (value) => value.isFinite && value >= 0 && value <= 20000,
        now: checkedAt,
      ),
      averageHeartRateBpm: _metric(
        data: data,
        metric: WearableMetric.heartRate,
        raw: data.averageHeartRateBpm,
        unavailableTypes: const {'HEART_RATE'},
        plausible: _isPlausibleHeartRate,
        now: checkedAt,
      ),
      restingHeartRateBpm: _metric(
        data: data,
        metric: WearableMetric.restingHeartRate,
        raw: data.restingHeartRateBpm,
        unavailableTypes: const {'RESTING_HEART_RATE'},
        plausible: _isPlausibleHeartRate,
        now: checkedAt,
      ),
      workouts: ValidatedWearableMetric(
        rawValue: List.unmodifiable(data.workouts),
        value: workoutsStatus == WearableValidationStatus.valid
            ? List.unmodifiable(validWorkouts)
            : null,
        sourceDate: data.sourceDates[WearableMetric.workouts],
        status: workoutsStatus,
      ),
      workoutDuration: ValidatedWearableMetric(
        rawValue: data.workouts.isEmpty ? null : rawWorkoutDuration,
        value: durationStatus == WearableValidationStatus.valid
            ? validWorkoutDuration
            : null,
        sourceDate: data.sourceDates[WearableMetric.workoutDuration],
        status: durationStatus,
      ),
      distanceMeters: _metric(
        data: data,
        metric: WearableMetric.distance,
        raw: data.distanceMeters,
        unavailableTypes: const {'DISTANCE_WALKING_RUNNING'},
        plausible: (value) => value.isFinite && value >= 0 && value <= 200000,
        now: checkedAt,
      ),
      sleepDuration: _metric(
        data: data,
        metric: WearableMetric.sleepDuration,
        raw: data.sleepDuration,
        unavailableTypes: const {
          'SLEEP_ASLEEP',
          'SLEEP_LIGHT',
          'SLEEP_DEEP',
          'SLEEP_REM',
        },
        unavailableWhenAny: false,
        plausible: (value) =>
            !value.isNegative && value <= const Duration(hours: 24),
        now: checkedAt,
      ),
      bodyWeightKilograms: _metric(
        data: data,
        metric: WearableMetric.bodyWeight,
        raw: data.bodyWeightKilograms,
        unavailableTypes: const {'WEIGHT'},
        plausible: isPlausibleBodyWeightKg,
        now: checkedAt,
      ),
    );
  }

  ValidatedWearableMetric<T> _metric<T>({
    required WearableData data,
    required WearableMetric metric,
    required T? raw,
    required Set<String> unavailableTypes,
    required bool Function(T) plausible,
    required DateTime now,
    bool unavailableWhenAny = true,
  }) {
    final unavailable = unavailableWhenAny
        ? unavailableTypes.any(data.unavailableMetrics.contains)
        : unavailableTypes.every(data.unavailableMetrics.contains);
    final sourceDate = data.sourceDates[metric];
    final status = unavailable
        ? WearableValidationStatus.unavailable
        : raw == null
        ? WearableValidationStatus.missing
        : !plausible(raw)
        ? WearableValidationStatus.implausible
        : _isStale(sourceDate, now)
        ? WearableValidationStatus.stale
        : WearableValidationStatus.valid;
    return ValidatedWearableMetric(
      rawValue: raw,
      value: status == WearableValidationStatus.valid ? raw : null,
      sourceDate: sourceDate,
      status: status,
    );
  }

  WearableValidationStatus _collectionStatus({
    required WearableData data,
    required WearableMetric metric,
    required Set<String> unavailableTypes,
    required bool isMissing,
    required bool isPlausible,
    required DateTime now,
  }) {
    if (unavailableTypes.any(data.unavailableMetrics.contains)) {
      return WearableValidationStatus.unavailable;
    }
    if (isMissing) return WearableValidationStatus.missing;
    if (!isPlausible) return WearableValidationStatus.implausible;
    return _isStale(data.sourceDates[metric], now)
        ? WearableValidationStatus.stale
        : WearableValidationStatus.valid;
  }

  bool _isStale(DateTime? sourceDate, DateTime now) =>
      sourceDate == null ||
      sourceDate.isAfter(now.add(const Duration(minutes: 5))) ||
      now.difference(sourceDate) > defaultFreshness;

  bool _isPlausibleHeartRate(double value) =>
      value.isFinite && value >= 20 && value <= 300;

  bool _isPlausibleWorkout(WearableWorkout workout) =>
      !workout.duration.isNegative &&
      workout.duration <= const Duration(hours: 24) &&
      !workout.end.isBefore(workout.start) &&
      (workout.distanceMeters == null ||
          (workout.distanceMeters!.isFinite && workout.distanceMeters! >= 0)) &&
      (workout.activeEnergyKilocalories == null ||
          (workout.activeEnergyKilocalories!.isFinite &&
              workout.activeEnergyKilocalories! >= 0));
}
