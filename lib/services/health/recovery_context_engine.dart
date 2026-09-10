import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/services/validation/medical_validation_library.dart';

class RecoveryContextInput {
  final List<WearableDailyRecord> wearableHistory;
  final List<DateTime> completedWorkoutDates;
  final DateTime now;

  const RecoveryContextInput({
    required this.wearableHistory,
    this.completedWorkoutDates = const [],
    required this.now,
  });
}

class RecoveryContextEngine {
  static const minimumPriorDays = 5;
  static const baselineWindow = Duration(days: 14);
  static const workoutWindow = Duration(days: 7);

  final MedicalValidationLibrary _validation;

  const RecoveryContextEngine({
    MedicalValidationLibrary validation = const MedicalValidationLibrary(),
  }) : _validation = validation;

  RecoveryContext evaluate(RecoveryContextInput input) {
    final history = [...input.wearableHistory]
      ..sort((a, b) => b.localDate.compareTo(a.localDate));
    final latest = history.firstOrNull;
    final localNow = input.now.toLocal();
    final priorCutoff = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    ).subtract(baselineWindow);
    final prior = latest == null
        ? const <WearableDailyRecord>[]
        : history
              .skip(1)
              .where((record) => !record.localDate.isBefore(priorCutoff))
              .toList();
    final sleep = _sleep(latest, prior);
    final restingHeartRate = _restingHeartRate(latest, prior);
    final activity = _activity(latest, prior);
    final workouts = _workouts(input.completedWorkoutDates, input.now);
    final components = [sleep, restingHeartRate, activity];
    final comparable = components
        .where((item) => item.state != RecoveryContextState.insufficientData)
        .toList();
    final available = components
        .where((item) => item.latestValue != null)
        .length;
    final overallEvidence = <RecoveryEvidenceCode>[];
    final cautionCount = comparable
        .where((item) => item.state == RecoveryContextState.caution)
        .length;
    final favorableCount = comparable
        .where((item) => item.state == RecoveryContextState.favorable)
        .length;
    final overall = switch ((comparable.length, cautionCount)) {
      (0, _) => RecoveryContextState.insufficientData,
      (_, >= 2) => RecoveryContextState.caution,
      (1, 1) => RecoveryContextState.insufficientData,
      (_, 1) => RecoveryContextState.normal,
      _ when comparable.length >= 2 && favorableCount > 0 =>
        RecoveryContextState.favorable,
      _ => RecoveryContextState.normal,
    };
    if (comparable.isEmpty || (comparable.length == 1 && cautionCount == 1)) {
      overallEvidence.add(RecoveryEvidenceCode.insufficientHistory);
    }
    if (cautionCount == 1 && comparable.length > 1) {
      overallEvidence.add(RecoveryEvidenceCode.conflictingSignals);
    }
    for (final component in comparable) {
      overallEvidence.addAll(component.evidence);
    }

    return RecoveryContext(
      overallState: overall,
      sleepContext: sleep,
      restingHeartRateContext: restingHeartRate,
      recentActivityContext: activity,
      recentWorkoutContext: workouts,
      dataCoverage: RecoveryDataCoverage(
        wearableDays: history.length,
        comparableComponents: comparable.length,
        availableComponents: available,
      ),
      evidence: List.unmodifiable(overallEvidence.toSet()),
      generatedAt: input.now,
    );
  }

  RecoveryMetricContext _sleep(
    WearableDailyRecord? latest,
    List<WearableDailyRecord> prior,
  ) => _relativeContext(
    latestValue: _validSleep(latest?.sleepMinutes),
    priorValues: prior.map((item) => _validSleep(item.sleepMinutes)).nonNulls,
    unit: 'minutes',
    cautionWhen: (value, baseline) => value < baseline * 0.80,
    favorableWhen: (value, baseline) => value > baseline * 1.10,
    cautionCode: RecoveryEvidenceCode.sleepBelowPersonalBaseline,
    normalCode: RecoveryEvidenceCode.sleepNearPersonalBaseline,
    favorableCode: RecoveryEvidenceCode.sleepAbovePersonalBaseline,
  );

  RecoveryMetricContext _restingHeartRate(
    WearableDailyRecord? latest,
    List<WearableDailyRecord> prior,
  ) => _relativeContext(
    latestValue: _validRestingHeartRate(latest?.restingHeartRateBpm),
    priorValues: prior
        .map((item) => _validRestingHeartRate(item.restingHeartRateBpm))
        .nonNulls,
    unit: 'bpm',
    cautionWhen: (value, baseline) =>
        value >= baseline * 1.10 && value - baseline >= 5,
    cautionCode: RecoveryEvidenceCode.restingHeartRateElevatedFromBaseline,
    normalCode: RecoveryEvidenceCode.restingHeartRateNearBaseline,
  );

  RecoveryMetricContext _activity(
    WearableDailyRecord? latest,
    List<WearableDailyRecord> prior,
  ) {
    double? Function(WearableDailyRecord) selector;
    String unit;
    if (_validActiveEnergy(latest?.activeEnergyKilocalories) != null) {
      selector = (record) =>
          _validActiveEnergy(record.activeEnergyKilocalories);
      unit = 'kcal';
    } else if (_validDistance(latest?.distanceMeters) != null) {
      selector = (record) => _validDistance(record.distanceMeters);
      unit = 'meters';
    } else {
      selector = (record) => _validSteps(record.steps);
      unit = 'steps';
    }
    return _relativeContext(
      latestValue: latest == null ? null : selector(latest),
      priorValues: prior.map(selector).nonNulls,
      unit: unit,
      cautionWhen: (value, baseline) => value > baseline * 1.50,
      cautionCode: RecoveryEvidenceCode.recentActivityAboveBaseline,
      normalCode: RecoveryEvidenceCode.recentActivityNearBaseline,
    );
  }

  RecoveryMetricContext _relativeContext({
    required double? latestValue,
    required Iterable<double> priorValues,
    required String unit,
    required bool Function(double value, double baseline) cautionWhen,
    required RecoveryEvidenceCode cautionCode,
    required RecoveryEvidenceCode normalCode,
    bool Function(double value, double baseline)? favorableWhen,
    RecoveryEvidenceCode? favorableCode,
  }) {
    final values = priorValues.toList();
    if (latestValue == null) {
      return const RecoveryMetricContext(
        state: RecoveryContextState.insufficientData,
        baselineDays: 0,
        evidence: [RecoveryEvidenceCode.latestValueMissing],
      );
    }
    if (values.length < minimumPriorDays) {
      return RecoveryMetricContext(
        state: RecoveryContextState.insufficientData,
        latestValue: latestValue,
        baselineDays: values.length,
        unit: unit,
        evidence: const [RecoveryEvidenceCode.insufficientHistory],
      );
    }
    final baseline = values.reduce((a, b) => a + b) / values.length;
    if (cautionWhen(latestValue, baseline)) {
      return RecoveryMetricContext(
        state: RecoveryContextState.caution,
        latestValue: latestValue,
        personalBaseline: baseline,
        baselineDays: values.length,
        unit: unit,
        evidence: [cautionCode],
      );
    }
    if (favorableWhen?.call(latestValue, baseline) == true) {
      return RecoveryMetricContext(
        state: RecoveryContextState.favorable,
        latestValue: latestValue,
        personalBaseline: baseline,
        baselineDays: values.length,
        unit: unit,
        evidence: [favorableCode!],
      );
    }
    return RecoveryMetricContext(
      state: RecoveryContextState.normal,
      latestValue: latestValue,
      personalBaseline: baseline,
      baselineDays: values.length,
      unit: unit,
      evidence: [normalCode],
    );
  }

  RecoveryWorkoutContext _workouts(List<DateTime> completed, DateTime now) {
    final cutoff = now.subtract(workoutWindow);
    final count = completed.where((date) => !date.isBefore(cutoff)).length;
    return RecoveryWorkoutContext(
      state: count == 0
          ? RecoveryContextState.insufficientData
          : RecoveryContextState.normal,
      completedSessionsLast7Days: count,
      evidence: [
        count == 0
            ? RecoveryEvidenceCode.insufficientWorkoutHistory
            : RecoveryEvidenceCode.recentWorkoutHistoryAvailable,
      ],
    );
  }

  double? _validSleep(int? minutes) {
    if (minutes == null) return null;
    final duration = Duration(minutes: minutes);
    return _validation.validateSleepDuration(duration).isValid
        ? minutes.toDouble()
        : null;
  }

  double? _validRestingHeartRate(double? value) =>
      _validation.validateHeartRateBpm(value, resting: true).isValid
      ? value
      : null;

  double? _validActiveEnergy(double? value) =>
      _validation.validateActiveEnergyKilocalories(value).isValid
      ? value
      : null;

  double? _validDistance(double? value) =>
      _validation.validateDistanceMeters(value).isValid ? value : null;

  double? _validSteps(int? value) =>
      _validation.validateSteps(value).isValid ? value?.toDouble() : null;
}
