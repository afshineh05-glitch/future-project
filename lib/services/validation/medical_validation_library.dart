import 'package:future_project/models/medical_validation.dart';

/// Central plausibility checks for normalized physiological and activity data.
///
/// These intentionally broad limits identify clearly unreliable data. They do
/// not define health, diagnose conditions, or replace product/form policy.
class MedicalValidationLibrary {
  const MedicalValidationLibrary();

  MedicalValidationResult<int> validateAgeYears(int? value) =>
      _integer(MedicalMetric.ageYears, value, minimum: 0, maximum: 130);

  MedicalValidationResult<double> validateHeightCentimeters(double? value) =>
      _number(
        MedicalMetric.heightCentimeters,
        value,
        minimum: 40,
        maximum: 275,
      );

  MedicalValidationResult<double> validateWeightKilograms(double? value) =>
      _number(MedicalMetric.weightKilograms, value, minimum: 30, maximum: 350);

  MedicalValidationResult<double> validateBodyCircumferenceCentimeters(
    MedicalMetric metric,
    double? value,
  ) {
    if (!_bodyCircumferenceMetrics.contains(metric)) {
      return MedicalValidationResult(
        metric: metric,
        rawValue: value,
        validatedValue: null,
        status: MedicalValidationStatus.unsupported,
        reasonCode: MedicalValidationReasonCode.unsupportedMetric,
      );
    }
    return _number(metric, value, minimum: 1, maximum: 300);
  }

  MedicalValidationResult<double> validateHeartRateBpm(
    double? value, {
    bool resting = false,
  }) => _number(
    resting ? MedicalMetric.restingHeartRateBpm : MedicalMetric.heartRateBpm,
    value,
    minimum: 20,
    maximum: 300,
  );

  MedicalValidationResult<int> validateSteps(int? value) =>
      _integer(MedicalMetric.steps, value, minimum: 0, maximum: 100000);

  MedicalValidationResult<double> validateActiveEnergyKilocalories(
    double? value,
  ) => _number(
    MedicalMetric.activeEnergyKilocalories,
    value,
    minimum: 0,
    maximum: 20000,
  );

  MedicalValidationResult<double> validateDistanceMeters(double? value) =>
      _number(MedicalMetric.distanceMeters, value, minimum: 0, maximum: 200000);

  MedicalValidationResult<Duration> validateSleepDuration(Duration? value) =>
      _duration(
        MedicalMetric.sleepDuration,
        value,
        maximum: const Duration(hours: 24),
      );

  MedicalValidationResult<Duration> validateWorkoutDuration(Duration? value) =>
      _duration(
        MedicalMetric.workoutDuration,
        value,
        maximum: const Duration(hours: 24),
      );

  MedicalValidationResult<double> validateNonNegativeFinite(
    MedicalMetric metric,
    double? value,
  ) => _number(metric, value, minimum: 0);

  MedicalValidationResult<double> _number(
    MedicalMetric metric,
    double? value, {
    required double minimum,
    double? maximum,
  }) {
    if (value == null) return _missing(metric);
    if (!value.isFinite) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.nonFiniteValue,
      );
    }
    if (value < 0) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.negativeValue,
      );
    }
    if (value < minimum) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.belowPlausibleRange,
      );
    }
    if (maximum != null && value > maximum) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.abovePlausibleRange,
      );
    }
    return _valid(metric, value);
  }

  MedicalValidationResult<int> _integer(
    MedicalMetric metric,
    int? value, {
    required int minimum,
    required int maximum,
  }) {
    if (value == null) return _missing(metric);
    if (value < 0) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.negativeValue,
      );
    }
    if (value < minimum) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.belowPlausibleRange,
      );
    }
    if (value > maximum) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.abovePlausibleRange,
      );
    }
    return _valid(metric, value);
  }

  MedicalValidationResult<Duration> _duration(
    MedicalMetric metric,
    Duration? value, {
    required Duration maximum,
  }) {
    if (value == null) return _missing(metric);
    if (value.isNegative) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.invalidDuration,
      );
    }
    if (value > maximum) {
      return _implausible(
        metric,
        value,
        MedicalValidationReasonCode.abovePlausibleRange,
      );
    }
    return _valid(metric, value);
  }

  MedicalValidationResult<T> _missing<T>(MedicalMetric metric) =>
      MedicalValidationResult(
        metric: metric,
        rawValue: null,
        validatedValue: null,
        status: MedicalValidationStatus.missing,
        reasonCode: MedicalValidationReasonCode.missingValue,
      );

  MedicalValidationResult<T> _valid<T>(MedicalMetric metric, T value) =>
      MedicalValidationResult(
        metric: metric,
        rawValue: value,
        validatedValue: value,
        status: MedicalValidationStatus.valid,
      );

  MedicalValidationResult<T> _implausible<T>(
    MedicalMetric metric,
    T value,
    MedicalValidationReasonCode reason,
  ) => MedicalValidationResult(
    metric: metric,
    rawValue: value,
    validatedValue: null,
    status: MedicalValidationStatus.implausible,
    reasonCode: reason,
  );

  static const _bodyCircumferenceMetrics = {
    MedicalMetric.waistCentimeters,
    MedicalMetric.chestCentimeters,
    MedicalMetric.hipsCentimeters,
    MedicalMetric.armCentimeters,
    MedicalMetric.thighCentimeters,
    MedicalMetric.neckCentimeters,
  };
}
