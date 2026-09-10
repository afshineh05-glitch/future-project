import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/medical_validation.dart';
import 'package:future_project/services/validation/medical_validation_library.dart';

/// Central conservative sanity and freshness rules for normalized health data.
/// These checks reject impossible/contextually unusable values; they do not
/// diagnose health conditions or establish clinical accuracy.
class WearableValidationService {
  static const defaultFreshness = Duration(hours: 36);
  final MedicalValidationLibrary _medicalValidation;

  const WearableValidationService({
    MedicalValidationLibrary medicalValidation =
        const MedicalValidationLibrary(),
  }) : _medicalValidation = medicalValidation;

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
        plausibility: _medicalValidation.validateSteps,
        now: checkedAt,
      ),
      activeEnergyKilocalories: _metric(
        data: data,
        metric: WearableMetric.activeEnergy,
        raw: data.activeEnergyKilocalories,
        unavailableTypes: const {'ACTIVE_ENERGY_BURNED'},
        plausibility: _medicalValidation.validateActiveEnergyKilocalories,
        now: checkedAt,
      ),
      averageHeartRateBpm: _metric(
        data: data,
        metric: WearableMetric.heartRate,
        raw: data.averageHeartRateBpm,
        unavailableTypes: const {'HEART_RATE'},
        plausibility: _medicalValidation.validateHeartRateBpm,
        now: checkedAt,
      ),
      restingHeartRateBpm: _metric(
        data: data,
        metric: WearableMetric.restingHeartRate,
        raw: data.restingHeartRateBpm,
        unavailableTypes: const {'RESTING_HEART_RATE'},
        plausibility: (value) =>
            _medicalValidation.validateHeartRateBpm(value, resting: true),
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
        plausibility: _medicalValidation.validateDistanceMeters,
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
        plausibility: _medicalValidation.validateSleepDuration,
        now: checkedAt,
      ),
      bodyWeightKilograms: _metric(
        data: data,
        metric: WearableMetric.bodyWeight,
        raw: data.bodyWeightKilograms,
        unavailableTypes: const {'WEIGHT'},
        plausibility: _medicalValidation.validateWeightKilograms,
        now: checkedAt,
      ),
    );
  }

  ValidatedWearableMetric<T> _metric<T>({
    required WearableData data,
    required WearableMetric metric,
    required T? raw,
    required Set<String> unavailableTypes,
    required MedicalValidationResult<T> Function(T?) plausibility,
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
        : !plausibility(raw).isValid
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

  bool _isPlausibleWorkout(WearableWorkout workout) =>
      _medicalValidation.validateWorkoutDuration(workout.duration).isValid &&
      !workout.end.isBefore(workout.start) &&
      (workout.distanceMeters == null ||
          _medicalValidation
              .validateNonNegativeFinite(
                MedicalMetric.distanceMeters,
                workout.distanceMeters,
              )
              .isValid) &&
      (workout.activeEnergyKilocalories == null ||
          _medicalValidation
              .validateNonNegativeFinite(
                MedicalMetric.activeEnergyKilocalories,
                workout.activeEnergyKilocalories,
              )
              .isValid);
}
