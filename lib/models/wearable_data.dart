enum WearablePermissionStatus {
  authorized,
  partiallyAuthorized,
  denied,
  unavailable,
  unsupportedPlatform,
}

enum WearableMetric {
  steps,
  activeEnergy,
  heartRate,
  restingHeartRate,
  workouts,
  workoutDuration,
  distance,
  sleepDuration,
  bodyWeight,
}

enum WearableValidationStatus {
  valid,
  missing,
  stale,
  implausible,
  unavailable,
}

class ValidatedWearableMetric<T> {
  final T? rawValue;
  final T? value;
  final DateTime? sourceDate;
  final WearableValidationStatus status;

  const ValidatedWearableMetric({
    required this.rawValue,
    required this.value,
    required this.sourceDate,
    required this.status,
  });

  bool get isSentToProgressEngine =>
      status == WearableValidationStatus.valid && value != null;

  bool get isEligibleForPersistence =>
      status == WearableValidationStatus.valid && value != null;
}

class WearablePermissionResult {
  final WearablePermissionStatus status;
  final String? message;

  const WearablePermissionResult(this.status, {this.message});
}

class WearableWorkout {
  final String activityType;
  final DateTime start;
  final DateTime end;
  final Duration duration;
  final double? distanceMeters;
  final double? activeEnergyKilocalories;
  final String sourceName;

  const WearableWorkout({
    required this.activityType,
    required this.start,
    required this.end,
    required this.duration,
    required this.sourceName,
    this.distanceMeters,
    this.activeEnergyKilocalories,
  });
}

class WearableData {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final WearablePermissionStatus permissionStatus;
  final int? steps;
  final double? activeEnergyKilocalories;
  final double? averageHeartRateBpm;
  final double? restingHeartRateBpm;
  final double? distanceMeters;
  final Duration? sleepDuration;
  final double? bodyWeightKilograms;
  final List<WearableWorkout> workouts;
  final Set<String> unavailableMetrics;
  final Map<WearableMetric, DateTime> sourceDates;

  const WearableData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.permissionStatus,
    required this.workouts,
    required this.unavailableMetrics,
    this.sourceDates = const {},
    this.steps,
    this.activeEnergyKilocalories,
    this.averageHeartRateBpm,
    this.restingHeartRateBpm,
    this.distanceMeters,
    this.sleepDuration,
    this.bodyWeightKilograms,
  });
}

class ValidatedWearableData {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final WearablePermissionStatus permissionStatus;
  final Set<String> unavailableMetrics;
  final ValidatedWearableMetric<int> steps;
  final ValidatedWearableMetric<double> activeEnergyKilocalories;
  final ValidatedWearableMetric<double> averageHeartRateBpm;
  final ValidatedWearableMetric<double> restingHeartRateBpm;
  final ValidatedWearableMetric<List<WearableWorkout>> workouts;
  final ValidatedWearableMetric<Duration> workoutDuration;
  final ValidatedWearableMetric<double> distanceMeters;
  final ValidatedWearableMetric<Duration> sleepDuration;
  final ValidatedWearableMetric<double> bodyWeightKilograms;

  const ValidatedWearableData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.permissionStatus,
    required this.unavailableMetrics,
    required this.steps,
    required this.activeEnergyKilocalories,
    required this.averageHeartRateBpm,
    required this.restingHeartRateBpm,
    required this.workouts,
    required this.workoutDuration,
    required this.distanceMeters,
    required this.sleepDuration,
    required this.bodyWeightKilograms,
  });

  int get validMetricCount => [
    steps,
    activeEnergyKilocalories,
    averageHeartRateBpm,
    restingHeartRateBpm,
    workouts,
    workoutDuration,
    distanceMeters,
    sleepDuration,
    bodyWeightKilograms,
  ].where((metric) => metric.isSentToProgressEngine).length;
}
