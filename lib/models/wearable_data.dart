enum WearablePermissionStatus {
  authorized,
  partiallyAuthorized,
  denied,
  unavailable,
  unsupportedPlatform,
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

  const WearableData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.permissionStatus,
    required this.workouts,
    required this.unavailableMetrics,
    this.steps,
    this.activeEnergyKilocalories,
    this.averageHeartRateBpm,
    this.restingHeartRateBpm,
    this.distanceMeters,
    this.sleepDuration,
    this.bodyWeightKilograms,
  });
}
