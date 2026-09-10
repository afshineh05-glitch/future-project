enum MedicalMetric {
  ageYears,
  heightCentimeters,
  weightKilograms,
  waistCentimeters,
  chestCentimeters,
  hipsCentimeters,
  armCentimeters,
  thighCentimeters,
  neckCentimeters,
  heartRateBpm,
  restingHeartRateBpm,
  steps,
  activeEnergyKilocalories,
  distanceMeters,
  sleepDuration,
  workoutDuration,
}

enum MedicalValidationStatus { valid, missing, implausible, unsupported }

enum MedicalValidationReasonCode {
  missingValue('missing_value'),
  belowPlausibleRange('below_plausible_range'),
  abovePlausibleRange('above_plausible_range'),
  negativeValue('negative_value'),
  invalidDuration('invalid_duration'),
  nonFiniteValue('non_finite_value'),
  unsupportedMetric('unsupported_metric');

  final String code;

  const MedicalValidationReasonCode(this.code);
}

class MedicalValidationResult<T> {
  final MedicalMetric metric;
  final T? rawValue;
  final T? validatedValue;
  final MedicalValidationStatus status;
  final MedicalValidationReasonCode? reasonCode;

  const MedicalValidationResult({
    required this.metric,
    required this.rawValue,
    required this.validatedValue,
    required this.status,
    this.reasonCode,
  });

  bool get isValid => status == MedicalValidationStatus.valid;
}
