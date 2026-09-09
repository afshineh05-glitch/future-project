import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:health/health.dart';

class HealthPermissionsService {
  final Health _health;
  bool _configured = false;

  HealthPermissionsService(this._health);

  static const readTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.WEIGHT,
  ];

  static final readAccess = List<HealthDataAccess>.unmodifiable(
    List.filled(readTypes.length, HealthDataAccess.READ),
  );

  Future<void> configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<WearablePermissionResult> status() async {
    if (kIsWeb || !Platform.isIOS) {
      return const WearablePermissionResult(
        WearablePermissionStatus.unsupportedPlatform,
        message: 'Apple Health is available on iOS only.',
      );
    }
    try {
      await configure();
      final granted = await _health.hasPermissions(
        readTypes,
        permissions: readAccess,
      );
      // HealthKit intentionally does not disclose individual read decisions.
      return WearablePermissionResult(
        granted == false
            ? WearablePermissionStatus.denied
            : WearablePermissionStatus.partiallyAuthorized,
        message: granted == null
            ? 'HealthKit keeps read authorization private; request access or read available data.'
            : null,
      );
    } on MissingPluginException {
      return const WearablePermissionResult(
        WearablePermissionStatus.unavailable,
        message: 'Apple Health is unavailable on this device.',
      );
    } on PlatformException catch (error) {
      return WearablePermissionResult(
        WearablePermissionStatus.unavailable,
        message: error.message ?? 'Apple Health is unavailable.',
      );
    }
  }

  Future<WearablePermissionResult> request() async {
    if (kIsWeb || !Platform.isIOS) {
      return const WearablePermissionResult(
        WearablePermissionStatus.unsupportedPlatform,
        message: 'Apple Health is available on iOS only.',
      );
    }
    try {
      await configure();
      final accepted = await _health.requestAuthorization(
        readTypes,
        permissions: readAccess,
      );
      return WearablePermissionResult(
        accepted
            ? WearablePermissionStatus.authorized
            : WearablePermissionStatus.denied,
        message: accepted
            ? 'HealthKit does not reveal which individual read types were declined.'
            : 'Apple Health access was not granted.',
      );
    } on MissingPluginException {
      return const WearablePermissionResult(
        WearablePermissionStatus.unavailable,
        message: 'Apple Health is unavailable on this device.',
      );
    } on PlatformException catch (error) {
      return WearablePermissionResult(
        WearablePermissionStatus.unavailable,
        message: error.message ?? 'Apple Health is unavailable.',
      );
    }
  }
}
