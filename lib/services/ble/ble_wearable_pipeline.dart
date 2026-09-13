import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/services/ble/ble_wearable_adapter.dart';
import 'package:future_project/services/health/wearable_sync_service.dart';
import 'package:future_project/services/health/wearable_validation_service.dart';

class BleWearablePipeline {
  final WearableValidationService _validation;
  final WearableSyncService _sync;

  BleWearablePipeline({
    WearableValidationService validation = const WearableValidationService(),
    WearableSyncService? sync,
  }) : _validation = validation,
       _sync = sync ?? WearableSyncService();

  Future<ValidatedWearableData?> readValidated(
    BleWearableAdapter adapter, {
    DateTime? now,
  }) async {
    final raw = await adapter.readAndNormalize(now: now);
    if (raw == null) return null;
    return _validation.validate(raw, now: now);
  }

  Future<WearableSyncResult?> sync(
    BleWearableAdapter adapter, {
    DateTime? now,
  }) async {
    final validated = await readValidated(adapter, now: now);
    if (validated == null || validated.validMetricCount == 0) return null;
    return _sync.sync(validated);
  }

  Future<WearableSyncResult?> syncNormalized(
    WearableData raw, {
    DateTime? now,
  }) async {
    final validated = _validation.validate(raw, now: now);
    if (validated.validMetricCount == 0) return null;
    return _sync.sync(validated);
  }

  Future<ValidatedWearableData?> processNormalized(
    WearableData raw, {
    DateTime? now,
  }) async {
    final validated = _validation.validate(raw, now: now);
    if (validated.validMetricCount == 0) return null;
    await _sync.sync(validated);
    return validated;
  }
}
