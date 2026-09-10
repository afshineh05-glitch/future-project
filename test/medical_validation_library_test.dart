import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/medical_validation.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/services/health/wearable_validation_service.dart';
import 'package:future_project/services/validation/medical_validation_library.dart';

void main() {
  const library = MedicalValidationLibrary();

  test('accepts ordinary normalized body and wearable values', () {
    expect(library.validateAgeYears(35).isValid, isTrue);
    expect(library.validateHeightCentimeters(175).isValid, isTrue);
    expect(library.validateWeightKilograms(80).isValid, isTrue);
    expect(library.validateSteps(12000).isValid, isTrue);
    expect(library.validateHeartRateBpm(72).isValid, isTrue);
    expect(
      library.validateSleepDuration(const Duration(hours: 8)).isValid,
      isTrue,
    );
  });

  test('returns typed missing results without converting them to zero', () {
    final result = library.validateWeightKilograms(null);

    expect(result.status, MedicalValidationStatus.missing);
    expect(result.reasonCode, MedicalValidationReasonCode.missingValue);
    expect(result.rawValue, isNull);
    expect(result.validatedValue, isNull);
  });

  test('rejects negative and impossible values with stable reason codes', () {
    final negative = library.validateSteps(-1);
    final impossible = library.validateHeartRateBpm(500);

    expect(negative.status, MedicalValidationStatus.implausible);
    expect(negative.reasonCode, MedicalValidationReasonCode.negativeValue);
    expect(
      impossible.reasonCode,
      MedicalValidationReasonCode.abovePlausibleRange,
    );
  });

  test('accepts broad plausible extremes and exact boundaries', () {
    expect(library.validateAgeYears(120).isValid, isTrue);
    expect(library.validateWeightKilograms(350).isValid, isTrue);
    expect(library.validateWeightKilograms(351).isValid, isFalse);
    expect(library.validateHeightCentimeters(40).isValid, isTrue);
    expect(library.validateHeightCentimeters(275).isValid, isTrue);
    expect(library.validateSteps(100000).isValid, isTrue);
    expect(library.validateSteps(100001).isValid, isFalse);
    expect(
      library.validateWorkoutDuration(const Duration(hours: 24)).isValid,
      isTrue,
    );
    expect(
      library
          .validateWorkoutDuration(const Duration(hours: 24, seconds: 1))
          .isValid,
      isFalse,
    );
  });

  test('supports all initial body circumference domains', () {
    for (final metric in const {
      MedicalMetric.waistCentimeters,
      MedicalMetric.chestCentimeters,
      MedicalMetric.hipsCentimeters,
      MedicalMetric.armCentimeters,
      MedicalMetric.thighCentimeters,
      MedicalMetric.neckCentimeters,
    }) {
      expect(
        library.validateBodyCircumferenceCentimeters(metric, 50).isValid,
        isTrue,
      );
    }
    final unsupported = library.validateBodyCircumferenceCentimeters(
      MedicalMetric.steps,
      50,
    );
    expect(unsupported.status, MedicalValidationStatus.unsupported);
    expect(
      unsupported.reasonCode,
      MedicalValidationReasonCode.unsupportedMetric,
    );
  });

  test('wearable validation delegates plausibility to medical library', () {
    final now = DateTime(2026, 9, 9, 12);
    const wearableValidator = WearableValidationService(
      medicalValidation: _RejectStepsLibrary(),
    );
    final result = wearableValidator.validate(
      WearableData(
        rangeStart: DateTime(2026, 9, 9),
        rangeEnd: now,
        permissionStatus: WearablePermissionStatus.authorized,
        steps: 1000,
        workouts: const [],
        unavailableMetrics: const {},
        sourceDates: {WearableMetric.steps: now},
      ),
      now: now,
    );

    expect(result.steps.status, WearableValidationStatus.implausible);
    expect(result.steps.value, isNull);
  });
}

class _RejectStepsLibrary extends MedicalValidationLibrary {
  const _RejectStepsLibrary();

  @override
  MedicalValidationResult<int> validateSteps(int? value) =>
      MedicalValidationResult(
        metric: MedicalMetric.steps,
        rawValue: value,
        validatedValue: null,
        status: MedicalValidationStatus.implausible,
        reasonCode: MedicalValidationReasonCode.abovePlausibleRange,
      );
}
