import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/services/health/health_permissions_service.dart';
import 'package:future_project/services/health/wearable_service.dart';
import 'package:health/health.dart';

class AppleHealthService implements WearableService {
  final Health _health;
  late final HealthPermissionsService _permissions;

  AppleHealthService({Health? health}) : _health = health ?? Health() {
    _permissions = HealthPermissionsService(_health);
  }

  @override
  Future<WearablePermissionResult> permissionStatus() => _permissions.status();

  @override
  Future<WearablePermissionResult> requestReadPermissions() =>
      _permissions.request();

  @override
  Future<WearableData> readToday() async {
    if (kIsWeb || !Platform.isIOS) {
      throw const WearableException('Apple Health is supported on iOS only.');
    }
    await _permissions.configure();

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final points = <HealthDataPoint>[];
    final unavailable = <String>{};
    var successfulReads = 0;

    for (final type in HealthPermissionsService.readTypes) {
      final start = _sleepTypes.contains(type)
          ? midnight.subtract(const Duration(hours: 12))
          : midnight;
      try {
        final values = await _health.getHealthDataFromTypes(
          types: [type],
          startTime: start,
          endTime: now,
        );
        points.addAll(values);
        successfulReads++;
      } on PlatformException {
        unavailable.add(type.name);
      }
    }

    if (successfulReads == 0) {
      throw const WearableException(
        'No Apple Health data types could be read. Check Health permissions and unlock the device.',
      );
    }

    final data = _health.removeDuplicates(points);
    final status = unavailable.isEmpty
        ? WearablePermissionStatus.authorized
        : WearablePermissionStatus.partiallyAuthorized;
    final workouts =
        data
            .where((point) => point.type == HealthDataType.WORKOUT)
            .map(_workoutFromPoint)
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));

    return WearableData(
      rangeStart: midnight,
      rangeEnd: now,
      permissionStatus: status,
      steps: _sum(data, HealthDataType.STEPS)?.round(),
      activeEnergyKilocalories: _sum(data, HealthDataType.ACTIVE_ENERGY_BURNED),
      averageHeartRateBpm: _average(data, HealthDataType.HEART_RATE),
      restingHeartRateBpm: _latest(data, HealthDataType.RESTING_HEART_RATE),
      distanceMeters: _sum(data, HealthDataType.DISTANCE_WALKING_RUNNING),
      sleepDuration: _sleepDuration(data, midnight),
      bodyWeightKilograms: _latest(data, HealthDataType.WEIGHT),
      workouts: workouts,
      unavailableMetrics: unavailable,
    );
  }

  static const _sleepTypes = <HealthDataType>{
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  };

  double? _sum(List<HealthDataPoint> points, HealthDataType type) {
    final values = _numeric(points, type);
    return values.isEmpty ? null : values.reduce((a, b) => a + b);
  }

  double? _average(List<HealthDataPoint> points, HealthDataType type) {
    final values = _numeric(points, type);
    return values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
  }

  double? _latest(List<HealthDataPoint> points, HealthDataType type) {
    final matching = points.where((point) => point.type == type).toList()
      ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
    if (matching.isEmpty) return null;
    return _numericValue(matching.first);
  }

  List<double> _numeric(List<HealthDataPoint> points, HealthDataType type) =>
      points
          .where((point) => point.type == type)
          .map(_numericValue)
          .whereType<double>()
          .toList();

  double? _numericValue(HealthDataPoint point) {
    final value = point.value;
    return value is NumericHealthValue ? value.numericValue.toDouble() : null;
  }

  Duration? _sleepDuration(List<HealthDataPoint> points, DateTime midnight) {
    final sleep = points.where(
      (point) =>
          _sleepTypes.contains(point.type) && point.dateTo.isAfter(midnight),
    );
    if (sleep.isEmpty) return null;
    return sleep.fold<Duration>(
      Duration.zero,
      (total, point) =>
          total +
          point.dateTo.difference(
            point.dateFrom.isBefore(midnight) ? midnight : point.dateFrom,
          ),
    );
  }

  WearableWorkout _workoutFromPoint(HealthDataPoint point) {
    final value = point.value;
    final workout = value is WorkoutHealthValue ? value : null;
    return WearableWorkout(
      activityType: workout?.workoutActivityType.name ?? 'OTHER',
      start: point.dateFrom,
      end: point.dateTo,
      duration: point.dateTo.difference(point.dateFrom),
      distanceMeters: workout?.totalDistance?.toDouble(),
      activeEnergyKilocalories: workout?.totalEnergyBurned?.toDouble(),
      sourceName: point.sourceName,
    );
  }
}

class WearableException implements Exception {
  final String message;

  const WearableException(this.message);

  @override
  String toString() => message;
}
